# SPDX-License-Identifier: Apache-2.0
#
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# This script generates SV registers and uvm classes from RDL files

import argparse
import logging
import os

from peakrdl_cheader.exporter import CHeaderExporter
from peakrdl_html import HTMLExporter
from peakrdl_markdown import MarkdownExporter
from peakrdl_regblock import RegblockExporter
from peakrdl_regblock.cpuif.passthrough import PassthroughCpuif
from peakrdl_regblock.udps import ALL_UDPS
from peakrdl_uvm import UVMExporter
from rdl_exporter import CocotbExporter
from rdl_post_process import scrub_line_by_line
from systemrdl import RDLCompiler


def setup_logger(level=logging.INFO, filename="log.log"):
    logging.basicConfig(
        level=level, handlers=[logging.FileHandler(filename), logging.StreamHandler()]
    )


def get_template_path(repo_root, name):
    return os.path.join(repo_root, "tools/templates/rdl/" + name)


def get_file_path(input_file, suffix):
    return os.path.splitext(os.path.basename(input_file))[0] + suffix


def main():
    setup_logger(level=logging.INFO, filename="reg_gen.log")
    parser = argparse.ArgumentParser(description="Reg gen")
    parser.add_argument(
        "--style-hier",
        action="store_true",
        help="Style: hierarchical or lexical",
        default=True,
    )
    parser.add_argument(
        "--input-file", default="./src/rdl/registers.rdl", help="input SystemRDL file"
    )
    parser.add_argument("--output-dir", default="./src/csr/script/", help="output directory")
    parser.add_argument("-P", action="append", help="SystemRDL parameters", metavar="key=value")
    args = parser.parse_args()

    # Parse Parameters
    parameters = {}
    for p in args.P:
        # Expect: string=number
        try:
            p_split = p.split("=")
            text = p_split[0]
            number = int(p_split[-1])
            parameters[text] = number
        except Exception:
            raise ValueError(
                f"SystemRDL Parameters should be a space separated list. Expected: -P param_1=1 -P param2=2. Got: {p}"
            )

    repo_root = os.environ.get("CALIPTRA_ROOT")
    if repo_root is None:
        raise ValueError("Caliptra root is not defined as environment variable. Aborting.")

    # Compile
    rdlc = RDLCompiler()
    for udp in ALL_UDPS:
        rdlc.register_udp(udp)

    rdlc.compile_file(args.input_file)
    root = rdlc.elaborate(parameters=parameters)

    # Export SystemVerilog implementation
    exporter = RegblockExporter()
    exporter.export(
        root,
        args.output_dir,
        cpuif_cls=PassthroughCpuif,
        retime_read_response=False,
        reuse_hwif_typedefs=not args.style_hier,
    )
    logging.info(f"Created: SystemVerilog files in {args.output_dir}")

    # Export UVM register model
    template_path_uvm = get_template_path(repo_root, "uvm")
    file_path_uvm = get_file_path(args.input_file, "_uvm.sv")
    output_file = os.path.join(args.output_dir, file_path_uvm)
    exporter = UVMExporter(user_template_dir=template_path_uvm)
    exporter.export(
        root,
        output_file,
        reuse_class_definitions=not args.style_hier,
    )
    logging.info(f"Created: UVM file {output_file}")

    # The below lines are used to generate a baseline/starting point for the include files "<reg_name>_covergroups.svh" and "<reg_name>_sample.svh"
    # The generated files need to be hand-edited to provide the desired functionality.
    uvm_collateral = {"cov": "_covergroups.svh", "smp": "_sample.svh"}
    for collateral_type in uvm_collateral.keys():
        file_path = get_file_path(args.input_file, uvm_collateral[collateral_type])
        template_path = get_template_path(repo_root, collateral_type)
        output_file = os.path.join(args.output_dir, file_path)
        exporter = UVMExporter(user_template_dir=template_path)
        exporter.export(
            root,
            output_file,
            reuse_class_definitions=not args.style_hier,
        )
        logging.info(f"Created: {collateral_type} file {output_file}")

    # Generate the C header
    exporter = CHeaderExporter()
    i3c_root_dir = os.environ.get("I3C_ROOT_DIR")
    try:
        os.mkdir(os.path.join(i3c_root_dir, "sw"))
    except FileExistsError:
        pass
    output_file = os.path.join(i3c_root_dir, "sw", "I3CCSR.h")
    exporter.export(root, path=output_file, reuse_typedefs=not args.style_hier)
    logging.info(f"Created: c-header file {output_file}")

    # Export documentation in HTML
    exporter = HTMLExporter()
    output_file = os.path.join("src/rdl/docs/html/")
    exporter.export(root, output_file)
    logging.info(f"Created: HTML files in {output_file}")

    # Export Markdown documentation
    exporter = MarkdownExporter()
    output_file = os.path.join("src/rdl/docs/README.md")
    exporter.export(root, output_file, rename="I3CCSR")
    logging.info(f"Created: Markdown file {output_file}")

    # Fix SystemVerilog files
    for file in os.listdir(args.output_dir):
        if os.path.isfile(os.path.join(args.output_dir, file)):
            scrub_line_by_line(os.path.join(args.output_dir, file))

    # Export Cocotb dictionary
    exporter = CocotbExporter()
    output_file = os.path.join("verification/common/reg_map.py")
    exporter.export(root, path=output_file)
    logging.info(f"Created: Python dictionary file {output_file}")


if __name__ == "__main__":
    main()

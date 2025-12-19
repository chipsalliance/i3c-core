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
from pathlib import Path

from peakrdl_cheader.exporter import CHeaderExporter
from peakrdl_cocotb.exporter import CocotbExporter
from peakrdl_html import HTMLExporter
from peakrdl_markdown import MarkdownExporter
from peakrdl_regblock import RegblockExporter
from peakrdl_regblock.cpuif.passthrough import PassthroughCpuif
from peakrdl_regblock.udps import ALL_UDPS
from peakrdl_uvm import UVMExporter
from rdl_post_process import postprocess_sv
from systemrdl import RDLCompiler

REGISTERS_PREFIX = "I3CCSR"


def setup_logger(level=logging.INFO, filename="log.log"):
    logging.basicConfig(
        level=level, handlers=[logging.FileHandler(filename), logging.StreamHandler()]
    )


def main():
    setup_logger(level=logging.INFO, filename="reg_gen.log")

    repo_root = Path(os.environ.get("CALIPTRA_ROOT"))
    if not repo_root.exists():
        raise ValueError("Caliptra root is not defined as environment variable. Aborting.")

    def get_template_path(name):
        return repo_root / "tools" / "templates" / "rdl" / name

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
    parser.add_argument(
        "--ral-template", default=get_template_path("uvm"), help="Template for generating UVM RAL"
    )
    parser.add_argument(
        "--cov-template",
        default=get_template_path("cov"),
        help="Template for generating RAL coverage groups",
    )
    parser.add_argument(
        "--smp-template",
        default=get_template_path("smp"),
        help="Template for implementing sample functions for RAL coverage",
    )
    args = parser.parse_args()

    # Parse Parameters
    parameters = {}
    for p in args.P or []:
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
    output_dir = Path(args.output_dir)

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
        str(output_dir),
        cpuif_cls=PassthroughCpuif,
        retime_read_response=False,
        reuse_hwif_typedefs=not args.style_hier,
    )
    logging.info(f"Created: SystemVerilog files in {output_dir}")

    # Export UVM register model
    file_path_uvm = REGISTERS_PREFIX + "_uvm.sv"
    output_file = output_dir / file_path_uvm
    exporter = UVMExporter(user_template_dir=args.ral_template)
    exporter.export(
        root,
        str(output_file),
        reuse_class_definitions=not args.style_hier,
    )
    logging.info(f"Created: UVM file {output_file}")

    # The below lines are used to generate a baseline/starting point for the include files "<reg_name>_covergroups.svh" and "<reg_name>_sample.svh"
    # The generated files need to be hand-edited to provide the desired functionality.
    def export_uvm_collateral(template_path, collateral_suffix):
        file_path = REGISTERS_PREFIX + collateral_suffix
        print(f"reg_gen: UVM collateral template path: {template_path}")
        output_file = output_dir / file_path
        exporter = UVMExporter(user_template_dir=template_path)
        exporter.export(
            root,
            str(output_file),
            reuse_class_definitions=not args.style_hier,
        )
        logging.info(f"Created file {output_file}")

    export_uvm_collateral(args.cov_template, "_covergroups.svh")
    export_uvm_collateral(args.smp_template, "_sample.svh")

    # Generate the C header
    exporter = CHeaderExporter()
    i3c_root_dir = Path(os.environ.get("I3C_ROOT_DIR"))
    try:
        (i3c_root_dir / "sw").mkdir()
    except FileExistsError:
        pass
    output_file = i3c_root_dir / "sw" / (REGISTERS_PREFIX + ".h")
    exporter.export(root, path=str(output_file), reuse_typedefs=not args.style_hier)
    logging.info(f"Created: c-header file {output_file}")

    # Export documentation in HTML
    exporter = HTMLExporter()
    output_file = i3c_root_dir / "src" / "rdl" / "docs" / "html"
    exporter.export(root, str(output_file))
    logging.info(f"Created: HTML files in {output_file}")

    # Export Markdown documentation
    exporter = MarkdownExporter()
    output_file = i3c_root_dir / "src" / "rdl" / "docs" / "README.md"
    exporter.export(root, str(output_file), rename=REGISTERS_PREFIX)
    logging.info(f"Created: Markdown file {output_file}")

    # Fix SystemVerilog files
    postprocess_sv(output_dir / (REGISTERS_PREFIX + ".sv"))
    postprocess_sv(output_dir / (REGISTERS_PREFIX + "_pkg.sv"))

    # Export Cocotb dictionary
    exporter = CocotbExporter()
    output_file = i3c_root_dir / "verification" / "cocotb" / "common" / "reg_map.py"
    exporter.export(root, path=str(output_file))
    logging.info(f"Created: Python dictionary file {output_file}")


if __name__ == "__main__":
    main()

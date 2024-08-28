# SPDX-License-Identifier: Apache-2.0
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

import argparse
import json
from typing import Any

from peakrdl.plugins.exporter import ExporterSubcommandPlugin
from systemrdl import RDLListener, RDLWalker
from systemrdl.node import AddrmapNode, MemNode, Node


class CocotbScanner(RDLListener):
    def __init__(self):
        self.mem_done = False
        self.reg_map = {}

    def exit_Mem(self, node):
        self.mem_done = False

    def enter_Addrmap(self, node):
        # save reference to addrmap top for relative path
        self.top_node = node
        register_name = node.get_path("_", "_{index:d}")
        # print the base address of each address map
        self.reg_map.update({f"{register_name.upper()}_BASE_ADDR": node.absolute_address})

    def enter_Regfile(self, node):
        self.regfile_offset = node.address_offset
        regfile_name = node.get_path("_", "_{index:d}")
        self.reg_map.update({f"{regfile_name.upper()}_START": node.absolute_address})

    def exit_Regfile(self, node):
        self.regfile_offset = 0

    def enter_Reg(self, node):
        if isinstance(node.parent, MemNode) and self.mem_done:
            return
        # getting and printing the absolute address and path for reach register
        register_name = node.get_path("_", "_{index:d}")
        if isinstance(node.parent, MemNode):
            register_name = node.parent.parent.inst_name + "_" + node.inst_name
        self.reg_map.update({f"{register_name.upper()}": node.absolute_address})
        # getting and printing the relative address and path for each register (relative to the addr map it belongs to)
        register_name = node.get_rel_path(self.top_node.parent, "^", "_", "_{index:d}")
        if isinstance(node.parent, MemNode):
            return
        self.reg_map.update({f"{register_name.upper()}": node.address_offset + self.regfile_offset})

    def exit_Reg(self, node):
        if isinstance(node.parent, MemNode):
            self.mem_done = True

    def enter_Field(self, node):
        field_name = node.get_rel_path(self.top_node.parent, "^", "_", "_{index:d}")
        if isinstance(node.parent.parent, MemNode):
            if self.mem_done:
                return
            field_name = (
                node.parent.parent.parent.inst_name
                + "_"
                + node.parent.inst_name
                + "_"
                + node.inst_name
            )
            field_mask = hex(((2 << node.high) - 1) & ~((1 << node.low) - 1))
            # For software always assume 32-bit mask and trim LSBs
            while len(field_mask) > 10:
                field_mask = field_mask[: len(field_mask) - 8]
            self.reg_map.update({f"{field_name.upper()}_LOW": node.low})
            self.reg_map.update({f"{field_name.upper()}_MASK": int(field_mask, 16)})
        elif node.width == 1:
            field_mask = 1 << node.low
            self.reg_map.update({f"{field_name.upper()}_LOW": node.low})
            self.reg_map.update({f"{field_name.upper()}_MASK": field_mask})
        elif node.low != 0 or node.high != 31:
            field_mask = ((2 << node.high) - 1) & ~((1 << node.low) - 1)
            self.reg_map.update({f"{field_name.upper()}_LOW": node.low})
            self.reg_map.update({f"{field_name.upper()}_MASK": field_mask})


class CocotbExporter:
    def export(self, node: Node, path: str, **kwargs: Any) -> None:
        walker = RDLWalker(unroll=True)
        scanner = CocotbScanner()
        walker.walk(node, scanner)

        with open(path, "w") as f:
            f.write("reg_map = ")
            f.write(json.dumps(scanner.reg_map, indent=4))
            f.write("\n")


# TODO: Test whether the Exporter works correctly
class Exporter(ExporterSubcommandPlugin):
    short_desc = "Export the register model to Python dictionary"

    def do_export(self, top_node: "AddrmapNode", options: "argparse.Namespace") -> None:
        exporter = CocotbExporter()
        exporter.export(top_node, path=options.output)

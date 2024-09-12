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

from systemrdl import RDLListener
from systemrdl.node import MemNode, RegfileNode


class CocotbScanner(RDLListener):
    def __init__(self, include_addrmap_name):
        self.include_addrmap_name = include_addrmap_name
        self.reg_map = {}

    def enter_Addrmap(self, node):
        # save reference to addrmap top for relative path
        self.top_node = node
        # print the base address of each address map
        self.reg_map.update({"base_addr": node.absolute_address})

    def enter_Regfile(self, node):
        self.regfile_offset = (
            self.regfile_offset + node.address_offset
            if isinstance(node.parent, RegfileNode)
            else node.address_offset
        )
        node.regfile_name = (
            node.get_path("_", "_{index:d}").upper()
            if self.include_addrmap_name
            else node.get_rel_path(node.parent, "^", "_", "_{index:d}").upper()
        )
        node.processed_dict = {"start_addr": node.absolute_address}

    def exit_Regfile(self, node):
        self.regfile_offset = (
            node.parent.address_offset if isinstance(node.parent, RegfileNode) else 0
        )
        if isinstance(node.parent, RegfileNode):
            node.parent.processed_dict.update({node.regfile_name: node.processed_dict})
        else:
            self.reg_map.update({node.regfile_name: node.processed_dict})

    def enter_Mem(self, node):
        self.mem_offset = node.address_offset
        self.mem_name = (
            node.get_path("_", "_{index:d}").upper()
            if self.include_addrmap_name
            else node.get_rel_path(node.parent, "^", "_", "_{index:d}").upper()
        )
        node.processed_dict = {"start_addr": node.absolute_address}

    def exit_Mem(self, node):
        self.mem_offset = (
            node.parent.raw_address_offset if isinstance(node.parent, RegfileNode) else 0
        )
        self.reg_map.update({self.mem_name: node.processed_dict})

    def enter_Reg(self, node):
        # getting and printing the absolute address and path for reach register
        self.reg_name = node.inst_name.upper()
        node.parent.processed_dict.update({self.reg_name: dict()})
        self.reg = node.parent.processed_dict[self.reg_name]
        self.reg.update({"base_addr": node.raw_absolute_address})
        # getting and printing the relative address and path for each register (relative to the addr map it belongs to)
        if isinstance(node.parent, MemNode):
            self.reg.update({"offset": node.raw_address_offset + self.mem_offset})
        else:
            self.reg.update({"offset": node.address_offset + self.regfile_offset})

    def enter_Field(self, node):
        self.reg.update({node.inst_name: dict()})
        field = self.reg[node.inst_name]
        # Assume default mask to cover whole 32-bit register
        field_mask = 0xFFFFFFFF
        if isinstance(node.parent.parent, MemNode):
            field_mask = hex(((2 << node.high) - 1) & ~((1 << node.low) - 1))
            # For software always assume 32-bit mask and trim LSBs
            while len(field_mask) > 10:
                field_mask = field_mask[: len(field_mask) - 8]
            field_mask = int(field_mask, 16)
        elif node.width == 1:
            field_mask = 1 << node.low
        elif node.low != 0 or node.high != 31:
            field_mask = ((2 << node.high) - 1) & ~((1 << node.low) - 1)

        field.update({"low": node.low})
        field.update({"mask": field_mask})

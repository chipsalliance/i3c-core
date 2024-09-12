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

import json
from typing import Any

from systemrdl import RDLWalker
from systemrdl.node import Node

from .cocotb_scanner import CocotbScanner


class CocotbExporter:
    def export(self, node: Node, path: str, **kwargs: Any) -> None:
        """
        Parameters
        ----------
        include_addrmap_name: bool
            Include address map name in register files names.
        """
        # Extract args
        self.include_addrmap_name = kwargs.pop("include_addrmap_name", False)

        # Check for stray kwargs
        if kwargs:
            raise TypeError(f"got an unexpected keyword argument '{list(kwargs.keys())[0]}'")

        # Process input for export
        walker = RDLWalker(unroll=True)
        scanner = CocotbScanner(include_addrmap_name=self.include_addrmap_name)
        walker.walk(node, scanner)

        # Write output
        with open(path, "w") as f:
            f.write("from munch import Munch\n\n")
            f.write("reg_map = Munch.fromDict(")
            f.write(json.dumps(scanner.reg_map, indent=4))
            f.write(")\n")

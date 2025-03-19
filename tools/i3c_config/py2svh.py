# SPDX-License-Identifier: Apache-2.0

import os

from common import I3CCoreConfig, I3CGenericConfig
from jinja2 import Environment, FileSystemLoader


# Traverse I3CCoreConfig and pass it to the SVH configuration template
class DefinesSVH:
    """
    'I3CCoreConfig' to svh adapter.
    Traverses 'I3CCoreConfig' and applies its member to jinja template,
    adjusting the types if necessary.
    """

    _defines = {}  # List of parameters to be defined in the defines.svh
    _just_level = 10  # left justification level for the parameter definitions

    def __init__(self, cfg: I3CGenericConfig):
        self._defines = I3CCoreConfig(cfg)._defines
        self._just_level = max([len(n) for n in self._defines])

    def save_to_file(self, file: os.path = "i3c_defines.svh"):
        template_path = os.path.join(os.path.dirname(__file__), "templates/")
        env = Environment(loader=FileSystemLoader(template_path))
        template = env.get_template("defines.txt")

        file_content = template.render(
            generator_tool_name="py2svh.py",
            cfg_guard="I3C_CONFIG",
            defines=self._defines,
            just_level=self._just_level,
        )
        with open(file, mode="w", encoding="utf-8") as out:
            out.write(file_content)


def cfg2svh(config: I3CGenericConfig, file: os.path = "i3c_defines.svh") -> None:
    DefinesSVH(config).save_to_file(file)

# SPDX-License-Identifier: Apache-2.0

import os
import re
from dataclasses import dataclass

import yaml
from i3c_core_config import _DEFAULT_OUT_DEFINES_FILE

_TEST_CONFIG_FILE_PATH = os.path.join(os.path.dirname(__file__), "test_configs.yaml")


@dataclass
class Tool:
    opts_arg: str
    parameter_pattern: str
    define_pattern: str

    def combine_to_output_pattern(self):
        # The escaped or of `parameter_pattern` and `define_pattern`
        return r"^({0}\s*|{1}\s*)+$".format(self.parameter_pattern, self.define_pattern)

    def is_valid_opts(self, opts):
        allowed_expr = self.combine_to_output_pattern()
        return re.match(allowed_expr, opts)


class Opts:
    # Shared patterns
    snake_case = r"[a-z]+[a-z0-9]*(_[a-z0-9]+)*"
    UPPER_SNAKE_CASE = r"[A-Z]+[A-Z0-9]*(_[A-Z0-9]+)*"
    PascalCase = r"(DisableInputFF|[A-Z][a-z]+(?:[A-Z][a-z]+)*)"

    def __pvalue(name):
        return "".join([re.escape("-pvalue+"), name, r"=[0-9]+"])

    def __define(name):
        return "".join([re.escape("+define+"), name, r"=[a-zA-Z]+"])

    VCS = Tool("vcs_opts", __pvalue(PascalCase), __define(PascalCase))
    QuestaSim = Tool("questa_sim_opts", r"-g/[a-zA-Z]+=[0-9]+", r"")
    QuestaCompile = Tool("questa_compile_opts", r"", __define(PascalCase))
    RegGen = Tool("reg_gen_opts", r"-P\s[a-z]+(_[a-z]+)*=[0-9]+", r"")
    VerilatorSim = Tool(
        "verilator_opts",
        __pvalue(UPPER_SNAKE_CASE),
        __define(UPPER_SNAKE_CASE),
    )

    # Check if the success message is displayed
    svh_msg = "".join([r"(S|s)ucc.*", _DEFAULT_OUT_DEFINES_FILE, r".*"])
    SVHFile = Tool("svh_file", r"", svh_msg)


class Configs:
    valid_configs = []
    edge_configs = []
    invalid_configs = []
    with open(_TEST_CONFIG_FILE_PATH) as config_file:
        yml = yaml.load(config_file, Loader=yaml.SafeLoader)
        for cfg in yml:
            if "invalid" in cfg:
                invalid_configs.append(cfg)
            elif "edge" in cfg:
                edge_configs.append(cfg)
            else:
                valid_configs.append(cfg)

# SPDX-License-Identifier: Apache-2.0
# Command-line options logic imported from ibex_config script:
# https://github.com/lowRISC/ibex/blob/f8b6d468c336a0a96f6e774a70420fb370a68699/util/ibex_config.py

import argparse
import json
import os

import yaml
from jsonschema import ValidationError, validate
from py2svh import cfg2svh

from common import ConfigException, I3CCoreConfig, I3CGenericConfig, RegGenConfig

_DEFAULT_CONFIG_FILE = "i3c_core_configs.yaml"
_DEFAULT_OUT_DEFINES_FILE = "i3c_defines.svh"
_DEFAULT_I3C_CONFIG_NAME = "default"


def parse_and_validate_config(name: str, filename: str) -> I3CGenericConfig:
    schema_path = os.path.join(os.path.dirname(__file__), "i3c_core_config.schema.json")
    with open(filename) as config_file, open(schema_path, "r") as s:
        try:
            yml = yaml.load(config_file, Loader=yaml.SafeLoader)
        except yaml.YAMLError as err:
            raise ConfigException(f"Could not decode yaml: {err}")

        if name not in yml:
            raise ConfigException(f"{name} configuration not found in the {filename}.")

        schema = json.load(s)

        try:
            validate(yml[name], schema)
        except ValidationError as err:
            raise ConfigException(
                f"{filename!r}: Invalid I3C core configuration: {err.message}"
            ) from None

        return I3CGenericConfig(**yml[name])


class BaseOpts:
    def __init__(self, name, description) -> None:
        self.name = name
        self.description = description

    def setup_args(self, subparser: argparse._SubParsersAction):
        self.argparser = subparser.add_parser(self.name, help=(f"Produce {self.description}"))
        self.argparser.set_defaults(output_fn=self.output)

    def output(self, config: I3CGenericConfig):
        raise NotImplementedError


class CmdLineOpts(BaseOpts):
    def __init__(self, name, description, _set_param_func, _set_define_func, _hier_sep) -> None:
        super().__init__(name, description)
        self._set_param_func = _set_param_func
        self._set_define_func = _set_define_func
        self._hier_sep = _hier_sep

    def setup_args(self, subparser: argparse._SubParsersAction):
        super().setup_args(subparser)

        self.argparser.add_argument(
            "--ins-hier-path",
            help=("Hierarchical path to the instance to set " "configuration parameters on"),
            default="",
        )

    def output(self, config: I3CGenericConfig, args):
        hier_path = args.ins_hier_path + self._hier_sep if args.ins_hier_path else ""
        sim_opts = []

        for name, value in config.items():
            if isinstance(value, str):
                sim_opts += self._set_define_func(name, value)
            else:
                assert type(value) in [bool, int]
                # Explicitly convert booleans to 0/1:
                val_as_int = int(value)
                full_param = hier_path + name
                sim_opts += self._set_param_func(full_param, str(val_as_int))
        return " ".join(sim_opts)


class VCSOpts(CmdLineOpts):
    def __init__(self) -> None:
        super().__init__(
            "vcs_opts",
            "VCS compile command line options",
            lambda p, v: ["-pvalue+" + p + "=" + v],
            lambda d, v: ["+define+" + d + "=" + v],
            ".",
        )


class QuestaSimOpts(CmdLineOpts):
    def __init__(self) -> None:
        super().__init__(
            "questa_sim_opts",
            "Questa simulation command line options",
            lambda p, v: ["-g/" + p + "=" + v],
            lambda *_: [],
            "/",
        )


class QuestaCompileOpts(CmdLineOpts):
    def __init__(self) -> None:
        super().__init__(
            "questa_compile_opts",
            "Questa compile options",
            lambda *_: [],
            lambda d, v: ["+define+" + d + "=" + v],
            "/",
        )


class RegGenOpts(CmdLineOpts):
    """
    Produces argument line based on the given I3CGenericConfig to be passed
    to the PeakRDL Regblock register generation.
    """

    def __init__(self) -> None:
        super().__init__(
            "reg_gen_opts",
            "Peakrdl regblock generator options",
            lambda p, v: ["-P " + p + "=" + v],
            lambda *_: [],
            ".",
        )

    def output(self, config: I3CGenericConfig, args):
        return super().output(RegGenConfig(config), args)


class VerilatorSimOpts(CmdLineOpts):
    def __init__(self) -> None:
        super().__init__(
            "verilator_opts",
            "Verilator simulation options",
            lambda p, v: ["-pvalue+" + p + "=" + v],
            lambda d, v: ["+define+" + d + "=" + v],
            ".",
        )

    def output(self, config: I3CGenericConfig, args):
        return super().output(I3CCoreConfig(config), args)


class SVHFile(BaseOpts):
    def __init__(self) -> None:
        super().__init__("svh_file", "I3C Core parameter definitions in a System Verilog file")

    def setup_args(self, subparser: argparse._SubParsersAction):
        super().setup_args(subparser)
        self.argparser.add_argument(
            "--output-file",
            help=("Path to the output System Verilog file"),
            default=_DEFAULT_OUT_DEFINES_FILE,
        )

    def output(self, config: I3CGenericConfig, args) -> None:
        cfg2svh(config, args.output_file)
        return f"Successfully saved configuration to {args.output_file}."


def main():
    supported_targets = [
        SVHFile(),
        RegGenOpts(),
        QuestaSimOpts(),
        QuestaCompileOpts(),
        VCSOpts(),
        VerilatorSimOpts(),
    ]

    argparser = argparse.ArgumentParser(
        description=(
            "Outputs I3C core configuration parameters in specified format "
            "and the provided YAML configuration."
        )
    )

    argparser.add_argument(
        "config_name",
        help="Name of the I3C Core configuration",
        default=_DEFAULT_I3C_CONFIG_NAME,
    )

    argparser.add_argument(
        "config_filename",
        help="Name of the file containing `config_name` configuration",
        default=_DEFAULT_CONFIG_FILE,
    )

    arg_subparser = argparser.add_subparsers(
        help="Option format to be provided",
        dest="output_fn",
        metavar="opt_fmt",
    )

    for target in supported_targets:
        target.setup_args(arg_subparser)

    args = argparser.parse_args()

    if args.output_fn is None:
        raise ValueError("No target specified to output options for.")

    cfg = parse_and_validate_config(args.config_name, args.config_filename)

    print(args.output_fn(cfg, args))


if __name__ == "__main__":
    main()

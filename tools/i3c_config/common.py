# SPDX-License-Identifier: Apache-2.0
import re
from math import log2


class ConfigException(Exception):
    pass


# General I3C configuration
# Contains parameters defined in the YAML configuration file
# and is utilized to separate subset of configurations for
# used tooling
# The the properties defined in the i3c_core_config.schema.json
class I3CGenericConfig:
    def __init__(self, dict_cfg: dict, schema: dict):
        self.__dict__ = dict_cfg

        # Go over schema-defined fields
        for n in schema:
            # If the value for the parameter was passed in the YAML configuration
            if n in dict_cfg:
                value = dict_cfg[n]
            # Otherwise, if schema specifies such, take the default value
            elif "default" in schema[n]:
                value = schema[n]["default"]
            # Otherwise, not applicable
            else:
                continue
            setattr(self, n, value)

        assert any(
            [dict_cfg["ControllerSupport"], dict_cfg["TargetSupport"]]
        ), "I3C requires at least one of [ControllerSupport, TargetSupport] option to function"

    def items(self):
        return self.__dict__.items()


# Configuration parameters necessary to generate registers from SystemRDL
class RegGenConfig:
    _params = {}

    def __init__(self, cfg: I3CGenericConfig):
        # Convert supplied FIFO depths to I3C CSR representations
        self._params["cmd_fifo_size"] = cfg.CmdFifoDepth  # Size in entries
        self._params["resp_fifo_size"] = cfg.RespFifoDepth  # Size in entries

        # Size of the TX / RX fifos is encoded in the CSRs as 2^(N+1)
        # where N is value in the size CSR
        self._params["tx_fifo_size"] = int(log2(cfg.TxFifoDepth) - 1)
        self._params["rx_fifo_size"] = int(log2(cfg.RxFifoDepth) - 1)

        # Size in entries, or 8*N if `cfg.IbiFifoExtSize`
        self._params["ibi_fifo_size"] = cfg.IbiFifoDepth
        self._params["ext_ibi_size"] = int(cfg.IbiFifoExtSize)

        self._params["dat_depth"] = cfg.DatDepth - 1
        self._params["dct_depth"] = cfg.DctDepth - 1

    def items(self):
        return self._params.items()


# RTL configuration parameters, to be included with I3C top module
class I3CCoreConfig:
    _defines = {}  # List of parameters to be defined in I3C configuration file

    def __init__(self, cfg: I3CGenericConfig) -> None:
        bus = cfg.FrontendBusInterface

        # Parse to SVH format
        for name, value in cfg.items():
            # Map BusInterface -> I3C_USE_[AXI|AHB]
            if "BusInterface" in name:
                self._defines[f"I3C_USE_{bus}"] = 1
                continue

            # Map "DisableInputFF"
            if name == "DisableInputFF":
                if bool(value):
                    self._defines["DISABLE_INPUT_FF"] = 1
                continue

            # For those parameters that map directly, change the name format:
            # PascalCase -> UPPER_SNAKE_CASE
            new_name = self._format_name(name).replace("FRONTEND_BUS", bus)

            # Resolve the parameter type
            value = self._py_to_sv_type(value, name)
            # Skips boolean parameters that are set to 'False'
            if value is not None:
                self._defines[new_name] = value

    # Change camel case name format to upper snake case
    def _format_name(self, name: str) -> str:
        return re.sub(r"(?<!^)(?=[A-Z])", "_", name).upper()

    def _py_to_sv_type(self, element: any, name: str) -> int | str:
        match element:
            case bool():
                return 1 if element else None
            case str():  # Ensure the resulting definition contains ""
                return f'"{element}"'
            case list():  # Run recursively on each element & return a string
                return "{" + ", ".join([self._py_to_sv_type(e) for e in element]) + "}"
            case int():  # TODO: Maybe could also handle widths?
                return element
            case _:  # Should've been reported when validating against schema
                raise Exception(
                    f"Encountered an unsupported type {type(element)} for {name}"
                    "while converting the configuration"
                )

    def items(self):
        return self._defines.items()

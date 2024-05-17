# SPDX-License-Identifier: Apache-2.0
import re
from dataclasses import asdict, dataclass
from math import log2


class ConfigException(Exception):
    pass


# Source-of-truth general I3C configuration
# Contains parameters defined in the YAML configuration file
# and is utilized to separate subset of configurations for
# used tooling
@dataclass
class I3CGenericConfig:
    CmdFifoDepth: int
    RxFifoDepth: int
    TxFifoDepth: int
    RespFifoDepth: int
    IbiFifoDepth: int
    IbiFifoExtSize: bool
    FrontendBusInterface: str
    FrontendBusAddrWidth: int
    FrontendBusDataWidth: int

    def items(self):
        return asdict(self).items()


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

    def items(self):
        return self._params.items()


# RTL configuration parameters, to be included with I3C top module
class I3CCoreConfig:
    _defines = {}  # List of parameters to be defined in I3C configuration file

    def __init__(self, cfg: I3CGenericConfig) -> None:
        # Parse to SVH format
        for name, value in asdict(cfg).items():
            # Skip frontend parametrization; performed later
            if "Frontend" in name:
                continue
            # For those parameters that map directly, change the name format:
            # PascalCase -> UPPER_SNAKE_CASE
            new_name = self._format_name(name)
            # Resolve the parameter type (i.e. booleans)
            self._defines[new_name] = self._py_to_sv_type(value, name)

        # Set frontend bus parameters in accordance to chosen protocol
        # The core expects `I3C_USE_AHB` or `I3C_USE_AXI` and the widths to
        # be set accordingly
        bus = cfg.FrontendBusInterface
        self._defines[f"I3C_USE_{bus}"] = 1
        self._defines[f"{bus}_ADDR_WIDTH"] = cfg.FrontendBusAddrWidth
        self._defines[f"{bus}_DATA_WIDTH"] = cfg.FrontendBusDataWidth

    # Change camel case name format to upper snake case
    def _format_name(self, name: str) -> str:
        return re.sub(r"(?<!^)(?=[A-Z])", "_", name).upper()

    def _py_to_sv_type(self, element: any, name: str) -> int | str:
        match element:
            case bool():  # Bool is not supported, use 0 or 1
                return int(element)
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

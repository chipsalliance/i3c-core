from typing import TYPE_CHECKING

from peakrdl.config import schema
from peakrdl.plugins.exporter import ExporterSubcommandPlugin

from .exporter import CocotbExporter

if TYPE_CHECKING:
    import argparse

    from systemrdl.node import AddrmapNode


class Exporter(ExporterSubcommandPlugin):
    short_desc = "Export the register model to class-like accessible Python dictionary"

    cfg_schema = {
        "include_addrmap_name": schema.Boolean(),
    }

    def add_exporter_arguments(self, arg_group: "argparse.ArgumentParser") -> None:
        arg_group.add_argument(
            "--include-addrmap-name",
            action="store_true",
            default=False,
            help="""
            Generate names of register files without including address map name.
            """,
        )

    def do_export(self, top_node: "AddrmapNode", options: "argparse.Namespace") -> None:
        exporter = CocotbExporter()
        exporter.export(
            top_node,
            path=options.output,
            include_addrmap_name=options.include_addrmap_name,
        )

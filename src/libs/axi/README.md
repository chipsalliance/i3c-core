# TODO

Remove this `axi` module in place of upstream [Caliptra's axi module](../../../third_party/caliptra-rtl/src/axi/) when the Caliptra's [testbench](../../../third_party/caliptra-rtl/src/integration/tb/caliptra_top_tb.sv) utilizes `AXI` interface.

Follow https://github.com/chipsalliance/caliptra-rtl/tree/cwhitehead-msft-gen2-axi-modules for axi module-related changes.

Upon removing this module, sources in `axi_adapter` verification [Makefile](../../../verification/block/axi_adapter/Makefile) will also need to be updated.
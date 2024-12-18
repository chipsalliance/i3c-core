CALIPTRA_SOURCES = \
	$(CALIPTRA_ROOT)/src/caliptra_prim/rtl/caliptra_prim_pkg.sv \
	$(CALIPTRA_ROOT)/src/caliptra_prim/rtl/caliptra_prim_util_pkg.sv \
	$(CALIPTRA_ROOT)/src/caliptra_prim/rtl/caliptra_prim_assert.sv \
	$(CALIPTRA_ROOT)/src/caliptra_prim_generic/rtl/caliptra_prim_generic_flop.sv \
	$(CALIPTRA_ROOT)/src/caliptra_prim/rtl/caliptra_prim_flop.sv \
	$(CALIPTRA_ROOT)/src/caliptra_prim/rtl/caliptra_prim_flop_2sync.sv

VERILOG_SOURCES += $(CALIPTRA_SOURCES)

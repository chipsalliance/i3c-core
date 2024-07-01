# Register generation

SystemRDL description of registers is kept in [src/rdl/](../../src/rdl/) directory. Top level [registers.rdl](../../src/rdl/registers.rdl) file is an argument to the [reg_gen.py](reg_gen.py) script, which:
* reads and elaborates SystemRDL files
* produces SystemVerilog, C header, Markdown and HTML collateral

Script [rdl_post_process.py](rdl_post_process.py) is used to add keyword `packed` to structs that should be of this type.

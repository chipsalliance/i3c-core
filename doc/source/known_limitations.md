# Known limitations

## Release v1p1

* I3C 1.1.1 Basic specification Errata 16 and 17 are not supported - the core will accept `SETDASA` and `SETAASA` CCCs even if dynamic address is set
* `SETAASA` sets only dynamic address for the main device (recovery device dynamic address is not set)
* Inferred latch on the `resp_desc` signal in `flow_active.sv`. This piece of code is not used in the Caliptra configuration

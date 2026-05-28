# Known limitations

## Release v1p1

* I3C 1.1.1 Basic specification Errata 16 and 17 are not supported - the core will accept `SETDASA` and `SETAASA` CCCs even if dynamic address is set
* `SETAASA` sets only dynamic address for the main device (recovery device dynamic address is not set)
* Inferred latch on the `resp_desc` signal in `flow_active.sv`. This piece of code is not used in the Caliptra configuration

## Release v1p5

* **Unanticipated Private Reads**: When the Controller initiates a Private Read but no TX descriptor is available, the Target NACKs the transaction. There is currently no status flag or interrupt to notify firmware that this occurred. Firmware cannot distinguish between "no read was attempted" and "a read was attempted but NACKed due to empty TX queue."

* **MRL/MWL not enforced in hardware**: The `SETMRL` and `SETMWL` CCCs update the `STBY_CR_MRL` / `STBY_CR_MWL` registers, but these values are not enforced by the hardware. The design does not limit the number of bytes in a Private Read or Private Write transfer. Firmware is responsible for respecting these limits.

* **CCC register updates without firmware notification**: `SETMRL`, `SETMWL`, `ENEC`, `DISEC`, `RSTACT`, `SETAASA`, `SETDASA`, `SETNEWDA`, and `RSTDAA` CCCs update internal registers without generating an interrupt. Firmware must poll the affected registers to detect changes.

* **PIOControl registers must not be accessed by firmware**: The PIOControl register block is unverified. Accessing these registers may hang the AXI bus.

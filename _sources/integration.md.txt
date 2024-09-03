# Integration with Caliptra Subsystem

The I3C Controller is meant to be used as part of the Caliptra Subsystem.

:::{figure-md} integration
![](img/integration.png)

Integration of the I3C Core with Caliptra Subsystem in standard use case
:::

## Caliptra Subsystem

The Caliptra Subsystem is based on the Caliptra RTL but has trimmed functionalities and an embedded I3C Core.
It consists of:
* VeeR EL2 with DMA engine
* SPI
* I3C
* HMAC
* UART
* SOC IFC
* SHA256 & SHA512
* ROM

All listed components are connected to AHB Lite bus that is controlled by VeeR EL2 serving the role of a manager.
:::{figure-md} caliptra_ss
![](img/caliptra_ss.png)

Caliptra Subsystem block diagram
:::

### Clock

The I3C core will be using the gated clock `clk_cg`, provided by the Caliptra-SS core.

### Reset

The PON reset of the I3C core will be provided by the Caliptra-SS core.

The I3C core is responsive after PON release, so it does not provide a handshake (e.g. `BOOT_DONE`, `RST_DONE`, etc.)

### Peripheral connection interface

The I3C Core can be connected as a subordinate on either AHB or AXI bus to enable both VeeR-EL2 configurations.
The AHB/AXI interface is connected to an adapter, which enables access to the Control and Status Registers.
SystemVerilog CSR description is generated with [PeakRDL](https://github.com/SystemRDL/PeakRDL) and uses the ["Internal CPUIF Protocol"](https://peakrdl-regblock.readthedocs.io/en/latest/cpuif/internal_protocol.html).

## Controller Interface test

In test [smoke_test_i3c.c](https://github.com/chipsalliance/caliptra-ss/tree/dev-antmicro/src/mcu/test_suites/smoke_test_i3c), the I3C Core is connected via AHB bus to the Caliptra SubSystem.
Communication with internal registers of I3C Core is executed by using `lsu_write_32()` and `lsu_read_32()` functions from [riscv_hw_if.h](https://github.com/chipsalliance/caliptra-rtl/blob/a50f6d212c93827d9303b6b734152302c0ccd7cd/src/integration/test_suites/libs/riscv_hw_if/riscv_hw_if.h) Caliptra header.
Software is executed on the simulated [VeeR-EL2 core](https://github.com/chipsalliance/Cores-VeeR-EL2).
The software test executes read/write operations on different configurations of registers to check whether RTL generated from RDL configuration behaves properly from the software point of view.


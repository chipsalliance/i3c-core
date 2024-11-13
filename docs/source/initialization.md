# Boot and Initialization

## Boot

After Power-On Reset, the core should be configured to prevent it from interacting with the I3C bus in any way.

This implementation supports 3 modes at boot:
* Active Controller Mode
* Secondary Controller Mode (Target)
* Disabled Mode

We propose the following boot sequence:
* Power-On Reset
* Device is in Disabled Mode (reset values defined at synthesis time)
* System Manager initializes itself and enables clock for the I3C Core
* System Manager initializes relevant registers of the I3C Core
* System Manager enables the desired mode of operation: Active or Secondary Controller Mode
* The device is ready for normal operation

## Primary Controller Initialization

The following section details the initialization process on the software driver side, in compliance with the [I3C HCI Specification](introduction.md#spec-i3c-hci):
* "6.1.1 Host Controller Initialization" in the PIO mode
* "6.17.1.1 Secondary Controller Initialization"

The following process is described under the assumption that the controller has undergone software- or hardware-issued reset prior to the initialization, so that all the registers and internal FSMs are in the default state.

To initialize the controller, the software is expected to perform the following steps:

1. Verify the value of the [HCI_VERSION](https://github.com/chipsalliance/i3c-core-rdl/blob/main/src/csr/documentation.md#hci_version-register) register at the `I3CBase` address.
The controller is compliant with MIPI HCI v1.2 and therefore the `HCI_VERSION` should read `0x120`
1. Evaluate DAT & DCT table offsets:
    *  The [DAT_SECTION_OFFSET](https://github.com/chipsalliance/i3c-core-rdl/blob/main/src/csr/documentation.md#dat_section_offset-register) register defined at `I3CBase + 0x30`
    *  The [DCT_SECTION_OFFSET](https://github.com/chipsalliance/i3c-core-rdl/blob/main/src/csr/documentation.md#dct_section_offset-register) register defined at `I3CBase + 0x34`
    *  Both `DAT_SECTION_OFFSET` and `DCT_SECTION_OFFSET` contain the corresponding table offset, number of entries & table size
    *  HCI spec permits to require the driver to allocate the DAT & DCT table, in which case the `TABLE_OFFSET` would read 0. This specific controller implementation allocates both DAT and DCT tables in the registers
1. Evaluate `PIO_SECTION_OFFSET`:
    * Read [PIO_SECTION_OFFSET](https://github.com/chipsalliance/i3c-core-rdl/blob/main/src/csr/documentation.md#pio_section_offset-register) at `I3CBase  + 0x3c`, the `section_offset` field points to the [PIOControl register file](https://github.com/chipsalliance/i3c-core-rdl/blob/main/src/csr/documentation.md#piocontrol-register-file) that contains command, transfer, response and IBI ports as well as PIO control registers
    * This specific controller implements the PIO mode capability. If it's not supported, `SECTION_OFFSET` will read 0
1. Evaluate `RING_HEADERS_SECTION_OFFSET`, the `SECTION_OFFSET` should read `0x0` as this controller doesn't support the DMA mode
1. Evaluate the `HC_CAPABILITIES` register at `I3CBase + 0xC`:
    * It stores controller capabilities such as scatter-gather, scheduled commands, combo transfers, IBI data abort, command size
1. Extended capabilities evaluation via [EXT_CAPS_SECTION_OFFSET](https://github.com/chipsalliance/i3c-core-rdl/blob/main/src/csr/documentation.md#ext_caps_section_offset-register) at `I3CBase + 0x40`
    * Evaluate the linked list of Extended Capability structures, until the end of the linked list (i.e., an instance of the `EXTCAP_HEADER` register with the `0x00` value in the `CAP_ID` field)
    * `EXT_OFFSET` will read `0x0` if the extended capabilities are not supported
1. Setup the threshold for the HCI queues (in the internal/private software data structures):
    * The command, data buffer and IBI status queue sizes can be obtained through the `QUEUE_SIZE` register at `PIO_OFFSET + 0x18`
    * The response queue size is defined at `ALT_QUEUE_SIZE` at `PIO_OFFSET + 0x1C` when the size of the command queue is not equal to the size of the response queue (which is the case for this host controller)
    * both are contained within [PIOControl register file](https://github.com/chipsalliance/i3c-core-rdl/blob/main/src/csr/documentation.md#piocontrol-register-file)
1. Enable the host controller:
     * Ensure the `MODE_SELECTOR` field in the [HC_CONTROL](https://github.com/chipsalliance/i3c-core-rdl/blob/main/src/csr/documentation.md#hc_control-register) register is set to `0x1` (PIO mode)
     * Set the `BUS_ENABLE` field in the [HC_CONTROL](https://github.com/chipsalliance/i3c-core-rdl/blob/main/src/csr/documentation.md#hc_control-register) register
1. Enable controller interrupts:
      * Set fields for the status interrupts to be enabled in the [INTR_STATUS_ENABLE](https://github.com/chipsalliance/i3c-core-rdl/blob/main/src/csr/documentation.md#intr_status_enable-register) register at `I3CBase + 0x24`; the following status interrupts can be set:
        * Scheduled command missed tick
        * Controller command sequence stall / timeout
        * Controller canceled transaction sequence
        * Controller internal error
      * Upon writing `1'b1`, the interrupt will be reported in [STATUS_REGISTER](https://github.com/chipsalliance/i3c-core-rdl/blob/main/src/csr/documentation.md#intr_status-register)
      * Setting the fields in the [INTR_SIGNAL_ENABLE](https://github.com/chipsalliance/i3c-core-rdl/blob/main/src/csr/documentation.md#intr_signal_enable-register) register at `I3CBase + 0x28` will result in not only reporting the interrupt in the [STATUS_REGISTER](https://github.com/chipsalliance/i3c-core-rdl/blob/main/src/csr/documentation.md#intr_status-register) register but will also deliver an interrupt condition to the host (interrupt trigger)
1.  Enable and start PIO queues:
    * Enable PIO interrupts via [PIO_INTR_STATUS_ENABLE](https://github.com/chipsalliance/i3c-core-rdl/blob/main/src/csr/documentation.md#pio_intr_status_enable-register) at `PIO_OFFSET + 0x20` and [PIO_INTR_SIGNAL_ENABLE](https://github.com/chipsalliance/i3c-core-rdl/blob/main/src/csr/documentation.md#pio_intr_signal_enable-register) at `PIO_OFFSET + 0x20`; enabling fields in the status register will cause the interrupts to be reported via the [PIO_INTR_STATUS](https://github.com/chipsalliance/i3c-core-rdl/blob/main/src/csr/documentation.md#pio_intr_status-register) register, additionally enabling interrupts in `PIO_INTR_SIGNAL_ENABLE` will cause an event for the host controller
    * Enable queues by setting the `ENABLE` field in the [PIO_CONTROL](https://github.com/chipsalliance/i3c-core-rdl/blob/main/src/csr/documentation.md#pio_control-register) register
    * Start PIO queues by setting the `RS` field in the [PIO_CONTROL](https://github.com/chipsalliance/i3c-core-rdl/blob/main/src/csr/documentation.md#pio_control-register) register

The host control will expose its register map and will await the driver to set the `BUS_ENABLE` bit in the [HC_CONTROL](https://github.com/chipsalliance/i3c-core-rdl/blob/main/src/csr/documentation.md#hc_control-register) register.
After that, the controller will evaluate the capabilities limited by the software and initialize internal queues & resources accordingly.

## Secondary Controller Initialization

The Secondary Controller Initialization process requires additional steps (in addition to the previous steps):

1. Evaluate the Standby Controller Mode Extended Capability structure (see Section 7.7.11):
   * Determine whether an I3C Target Transaction Interface to software is supported.
       * If this interface is supported, then discover its capabilities and configure the interface appropriately (i.e., by using its vendor-specified Extended Capability structure). Then, enable the interface using the `TARGET_XACT_ENABLE` field in the `STBY_CR_CONTROL` register (Section 7.7.11.1).
   * Determine which methods of Dynamic Address Assignment are implemented and supported by reading the `STBY_CR_CAPABILITIES` register (Section 7.7.11.3)
   * Determine which other CCCs need to be supported and configured, either as registers in the Standby Controller Mode Extended Capability structure, or as registers in any instances of other vendor-specific Extended Capability structures that might be defined to provide control for such CCC handling.
1. Set the BCR bits and the DCR value in the `STBY_CR_DEVICE_CHAR` register (Section 7.7.11.5).
1. Optionally, set the PID value in the `STBY_CR_DEVICE_CHAR` and `STBY_CR_DEVICE_PID_LO` registers (Section 7.7.11.5 and Section 7.7.11.6) if required for the Dynamic Address Assignment with the ENTDAA procedure, or if it is known that the GETPID CCC will be used by an Active Controller.
1. Configure registers to set up autonomous responses for CCCs, for those CCCs that are defined for such handling in this specification (see Section 6.17.3.1).
1. Enable Secondary Controller Interrupts:
   * In the `STBY_CR_INTR_SIGNAL_ENABLE` register (Section 7.7.11.8), set the mask of enabled interrupts.

```{note}
The specification states that the order of these operations has to be adjusted based on the initial desired operation, as well as supported handoff procedures.
```

## Minimal configuration

Configure timing registers:
```
I3C_EC.SOCMGMTIF.T_R_REG = 0x2
I3C_EC.SOCMGMTIF.T_HD_DAT_REG = 0xA
I3C_EC.SOCMGMTIF.T_SU_DAT_REG =  0xA
```

Configure the static address to a desired value and set valid bit:
```
I3C_EC.STDBYCTRLMODE.STBY_CR_DEVICE_ADDR.STATIC_ADDR = <value>
I3C_EC.STDBYCTRLMODE.STBY_CR_DEVICE_ADDR.STATIC_ADDR_VALID = 0x1
```

Enable Standby Configuration:
```
I3C_EC.STDBYCTRLMODE.STBY_CR_CONTROL.STBY_CR_ENABLE_INIT = 0x2
```

Enable Target Transaction Interface:
```
I3C_EC.STDBYCTRLMODE.STBY_CR_CONTROL.TARGET_XACT_ENABLE = 0x1
```

Enable PHY:
```
I3CBASE.HC_CONTROL.BUS_ENABLE = 0x1
```

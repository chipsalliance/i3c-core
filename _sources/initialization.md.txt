# Boot and Initialization

## Boot

After Power-On Reset, the core should be configured to prevent it from interacting with the i3c bus in any way.

This implementation supports 3 modes at boot:
* Active Controller Mode
* Secondary Controller Mode (Target)
* Disabled

We propose the following boot sequence:
* Power-On Reset
* Device is in Disabled Mode (reset values defined at synthesis time)
* System Manager initializes itself and enables clock for the I3C Core
* System Manager initializes relevant registers of the I3C Core
* System Manager enables desired mode of operation: Active or Secondary Controller Mode
* The device is ready for normal operation

Initialization process is described in more detail in the Initialization Chapter of this documentation.

## Primary Controller Initialization

The following section details the initialization process on the software driver side, in compliance with [I3C HCI Specification](introduction.md#spec-i3c-hci):
* "6.1.1 Host Controller Initialization" in the PIO mode
* "6.17.1.1 Secondary Controller Initialization"

The following process is described under the assumption the controller has undergone software- or hardware-issued reset prior to the initialization, so that all the registers and internal FSMs are in a default state.

To initialize the controller the software is expected to perform the following steps:

1. Verify the value of the [HCI_VERSION](https://github.com/chipsalliance/i3c-core-rdl/blob/main/src/csr/documentation.md#hci_version-register) register at the `I3CBase` address.
The controller is compliant with MIPI HCI v1.2 and therefore the `HCI_VERSION` should read `0x120`
1. Evaluate DAT & DCT table offsets:
    *  The [DAT_SECTION_OFFSET](https://github.com/chipsalliance/i3c-core-rdl/blob/main/src/csr/documentation.md#dat_section_offset-register) defined at `I3CBase + 0x30`
    *  The [DCT_SECTION_OFFSET](https://github.com/chipsalliance/i3c-core-rdl/blob/main/src/csr/documentation.md#dct_section_offset-register) defined at `I3CBase + 0x34`
    *  Both `DAT_SECTION_OFFSET` and `DCT_SECTION_OFFSET` contains the corresponding table offset, number of entries & table size
    *  HCI spec permits to require the driver to allocate the DAT & DCT table, in which case, the `TABLE_OFFSET` would read 0. This specific controller implementation allocates both DAT and DCT tables in the registers
2. Evaluate `PIO_SECTION_OFFSET`:
    * Read [PIO_SECTION_OFFSET](https://github.com/chipsalliance/i3c-core-rdl/blob/main/src/csr/documentation.md#pio_section_offset-register) at `I3CBase  + 0x3c`, the `section_offset` field points to the [PIOControl register file](https://github.com/chipsalliance/i3c-core-rdl/blob/main/src/csr/documentation.md#piocontrol-register-file) that contains command, transfer, response and IBI ports as well as PIO control registers
    * This specific controller implements the PIO mode capability. If it's not supported, the `SECTION_OFFSET` will read 0
3. Evaluate RING_HEADERS_SECTION_OFFSET, the `SECTION_OFFSET` should read `0x0` as this controller doesn't support the DMA mode
4. Evaluate HC_CAPABILITIES register at `I3CBase + 0xC`:
    * Stores controller capabilities such as scatter-gather, scheduled commands, combo transfers, IBI data abort, command size
5. Extended capabilities evaluation via [EXT_CAPS_SECTION_OFFSET](https://github.com/chipsalliance/i3c-core-rdl/blob/main/src/csr/documentation.md#ext_caps_section_offset-register) at `I3CBase + 0x40`
    * Evaluate the linked list of Extended Capability structures, until the end of the linked list (i.e., an instance of register `EXTCAP_HEADER` with field `CAP_ID` having the value `0x00`)
    * `EXT_OFFSET` will read `0x0` if the extended capabilities are not supported
6. Setup the threshold for the HCI queues (in the internal/private software data structures):
    * The command, data buffer and IBI status queue sizes can be obtained through `QUEUE_SIZE` register at `PIO_OFFSET + 0x18`
    * The response queue size is defined at `ALT_QUEUE_SIZE` at `PIO_OFFSET + 0x1C` when the size of the command queue is not equal to the size of response queue (which is the case for this host controller)
    * both are contained within [PIOControl register file](https://github.com/chipsalliance/i3c-core-rdl/blob/main/src/csr/documentation.md#piocontrol-register-file)
7. Enable the host controller:
     * Ensure the `MODE_SELECTOR` field in [HC_CONTROL](https://github.com/chipsalliance/i3c-core-rdl/blob/main/src/csr/documentation.md#hc_control-register) register is set to `0x1` (PIO mode)
     * Set the field `BUS_ENABLE` in the [HC_CONTROL](https://github.com/chipsalliance/i3c-core-rdl/blob/main/src/csr/documentation.md#hc_control-register) register
8. Enable controller interrupts:
      * Set fields for the status interrupts to be enabled in [INTR_STATUS_ENABLE](https://github.com/chipsalliance/i3c-core-rdl/blob/main/src/csr/documentation.md#intr_status_enable-register) register at `I3CBase + 0x24`, following status interrupts can be set:
        * Scheduled command missed tick
        * Controller command sequence stall / timeout
        * Controller canceled transaction sequence
        * Controller internal error
      * Upon writing `1'b1`, the interrupt will be reported in [STATUS_REGISTER](https://github.com/chipsalliance/i3c-core-rdl/blob/main/src/csr/documentation.md#intr_status-register)
      * Setting fields in [INTR_SIGNAL_ENABLE](https://github.com/chipsalliance/i3c-core-rdl/blob/main/src/csr/documentation.md#intr_signal_enable-register) register at `I3CBase + 0x28` will result in not only reporting the interrupt in the [STATUS_REGISTER](https://github.com/chipsalliance/i3c-core-rdl/blob/main/src/csr/documentation.md#intr_status-register) but will also deliver an interrupt condition to the host (interrupt trigger)
9.  Enable and start PIO queues:
    * Enable PIO interrupts via [PIO_INTR_STATUS_ENABLE](https://github.com/chipsalliance/i3c-core-rdl/blob/main/src/csr/documentation.md#pio_intr_status_enable-register) at `PIO_OFFSET + 0x20` and [PIO_INTR_SIGNAL_ENABLE](https://github.com/chipsalliance/i3c-core-rdl/blob/main/src/csr/documentation.md#pio_intr_signal_enable-register) at `PIO_OFFSET + 0x20`; enabling fields in status register will cause the interrupts to be reported via [PIO_INTR_STATUS](https://github.com/chipsalliance/i3c-core-rdl/blob/main/src/csr/documentation.md#pio_intr_status-register) register, additionally enabling interrupts in `PIO_INTR_SIGNAL_ENABLE` will cause an event for the host controller
    * Enable queues by setting `ENABLE` field in [PIO_CONTROL](https://github.com/chipsalliance/i3c-core-rdl/blob/main/src/csr/documentation.md#pio_control-register) register
    * Start PIO queues by setting `RS` field in [PIO_CONTROL](https://github.com/chipsalliance/i3c-core-rdl/blob/main/src/csr/documentation.md#pio_control-register)

The host control will expose its register map and will await the driver to set the `BUS_ENABLE` bit in [HC_CONTROL](https://github.com/chipsalliance/i3c-core-rdl/blob/main/src/csr/documentation.md#hc_control-register) register.
After which the controller will evaluate the capabilities limited by the software and initialize internal queues & resources accordingly.

## Secondary Controller Initialization

The Secondary Controller Initialization process requires additional steps (in addition to previous steps):

1. Evaluate the Standby Controller Mode Extended Capability structure (see Section 7.7.11):
   * Determine whether an I3C Target Transaction Interface to software is supported.
       * If this interface is supported, then discover its capabilities and configure the interface appropriately (i.e., by using its vendor-specified Extended Capability structure). Then, enable the interface using field TARGET_XACT_ENABLE in register STBY_CR_CONTROL (Section 7.7.11.1).
   * Determine which methods of Dynamic Address Assignment are implemented and supported, by reading register STBY_CR_CAPABILITIES (Section 7.7.11.3)
   * Determine which other CCCs need to be supported and configured, either as registers in the Standby Controller Mode Extended Capability structure, or as registers in any instances of other vendor-specific Extended Capability structures that might be defined to provide control for such CCC handling.
1. Set the BCR bits and the DCR value in register STBY_CR_DEVICE_CHAR (Section 7.7.11.5).
1. Optionally, set the PID value in registers STBY_CR_DEVICE_CHAR and STBY_CR_DEVICE_PID_LO (Section 7.7.11.5 and Section 7.7.11.6) if required for the Dynamic Address Assignment with ENTDAA procedure, or if it is known that the GETPID CCC will be used by an Active Controller.
1. Configure registers to set up autonomous responses for CCCs, for those CCCs that are defined for such handling in this specification (see Section 6.17.3.1).
1. Enable Secondary Controller Interrupts:
   * In register STBY_CR_INTR_SIGNAL_ENABLE (Section 7.7.11.8), set the mask of enabled interrupts.

```{note}
The specification states that order of these operations has to be adjusted based on the initial desired operation, as well as supported handoff procedures.
```

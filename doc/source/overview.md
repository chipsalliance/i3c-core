# I3C core overview

This chapter provides a high level overview of the I3C target functionalities implemented in the core.

## Configuration

Production RTL is configured through ordinary SystemVerilog parameters on `i3c_wrapper`, which passes them to the core and its submodules. These are elaboration-time settings, not runtime controls. Production RTL neither includes `i3c_defines.svh` nor imports a generated testbench configuration package.

The integrating system owns the interface configuration and supplies parameter overrides as needed. I3C's configuration must not be used as a global source of interface widths for unrelated IPs.

### RTL parameters

The public `i3c_wrapper` configuration defaults are:

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `UseAxi` | `bit` | `1` | Select AXI when set, or AHB when clear. Both bus port sets remain present. |
| `AxiAddrWidth` | `int unsigned` | `12` | AXI address width in bits. |
| `AxiDataWidth` | `int unsigned` | `32` | AXI data width in bits. |
| `AxiUserWidth` | `int unsigned` | `32` | AXI USER width in bits, including privileged-ID entries. |
| `AxiIdWidth` | `int unsigned` | `8` | AXI transaction ID width in bits. |
| `AhbAddrWidth` | `int unsigned` | `18` | AHB address width in bits. |
| `AhbDataWidth` | `int unsigned` | `64` | AHB data width in bits. |
| `EnableIdFiltering` | `bit` | `1` | Include the AXI USER filtering logic; see {doc}`axi_id_filtering`. |
| `NumPrivIds` | `int unsigned` | `4` | Number of privileged-ID entries. Must be positive when filtering is enabled. |
| `CmdFifoDepth` | `int unsigned` | `64` | HCI command and TTI TX descriptor queue depth in entries. |
| `RespFifoDepth` | `int unsigned` | `64` | HCI response and TTI RX descriptor queue depth in entries. |
| `RxFifoDepth` | `int unsigned` | `64` | HCI and TTI RX data queue depth in entries. |
| `TxFifoDepth` | `int unsigned` | `64` | HCI and TTI TX data queue depth in entries. |
| `IbiFifoDepth` | `int unsigned` | `64` | Base HCI and TTI IBI queue depth in entries. |
| `IbiFifoExtSize` | `bit` | `0` | Multiply the base IBI queue depth by eight when set. |
| `DatDepth` | `int unsigned` | `128` | Device Address Table depth in entries. |
| `DctDepth` | `int unsigned` | `128` | Device Characteristic Table depth in entries. |
| `DisableLoopback` | `bit` | `0` | When set, prevent `REC_INTF_CFG.REC_INTF_BYPASS` from enabling the AXI recovery bypass path. |

The defaults match the `axi_bypass` YAML profile. The `axi` profile additionally sets `DisableLoopback` to true. Selecting a YAML profile does not change production RTL defaults; its values take effect only when passed as parameter overrides.

The AXI interface instances must have address, data, USER, and ID widths matching `AxiAddrWidth`, `AxiDataWidth`, `AxiUserWidth`, and `AxiIdWidth`. The CSR address/data widths default to the constants in `I3CCSR_pkg`; parameter overrides must remain consistent with the generated register block.


## System Bus

The I3C core can connect to system buses via dedicated adapters:

* AXI4
* AHB - The AHB-Lite implementation is based on the AMBA 3 AHB-Lite Protocol Specification (IHI0033A)

`UseAxi=1` selects the AXI adapter and `UseAxi=0` selects the AHB adapter. Both the AXI modports (`s_axi_w_if`, `s_axi_r_if`) and the discrete AHB ports are always present on `i3c_wrapper`, as are the ID-filtering inputs.

For AXI integration, tie the unused AHB inputs to known inactive values. For AHB integration, connect an `axi_if` instance to the unused AXI ports and tie its request inputs inactive, with the remaining inputs at known values. The core drives the unused bus outputs to zero. Tie unused filtering inputs to known values as well.

## Virtual target

The I3C core implements the Secure Firmware Recovery protocol according to the Open Compute "Secure Firmware Recovery" specification rev. 1.1-rc5.
For this purpose, the I3C core exposes a "virtual" target with its own static and dynamic bus addresses.
The virtual target implementation shares most of its logic with the "main" one while retaining a distinct data path.
Certain CCC commands like `SETAASA` and `SETDASA` are implemented separately for the "main" and "virtual" targets.

## Register descriptions

Register descriptions are specified in the [RDL format](https://github.com/chipsalliance/i3c-core/tree/main/src/rdl) for I3C core CSRs:

* I3C Capability and Operational Registers (I3CBase)
* Programmable I/O (PIOControl)
* Extended Capabilities (I3C_EC)
* Device Address Table (DAT)
* Device Characteristic Table (DCT)

The RDL files generate the relevant SystemVerilog which can be found in the [src/csr/](https://github.com/chipsalliance/i3c-core/tree/main/src/csr) directory.
The auto-generated descriptions are included in the [Register descriptions](registers.md) chapter.

## Target Interface Queues

There are also target interface queues via Target Transaction Interface (TTI):

* RX - read descriptor & data queues
* TX - write descriptor & data queues
* IBI - IBI combined descriptor + data queue

## Target recovery interface

Several functionalities related to the recovery interface have been implemented for Caliptra:

* Recovery mode enable control via a CSR field
* Hardware recovery packet handling (private read/write)
* Hardware PEC checksum calculation and checking
* Access to Recovery CSRs from the I3C side
* Status signaling via output pins:

  * `recovery_payload_available_o`
  * `recovery_image_activated_o`

## Address Behavior

### Dynamic and Static Address Priority

Per the I3C specification, once a Target has been assigned a Dynamic Address (via ENTDAA,
SETDASA, SETAASA, or SETNEWDA), it shall stop responding to its Static Address. The
core implements this as follows:

- If `DYNAMIC_ADDR_VALID = 1`, the Target matches only on `DYNAMIC_ADDR`
- If `DYNAMIC_ADDR_VALID = 0` and `STATIC_ADDR_VALID = 1`, the Target matches on `STATIC_ADDR`

This rule applies independently to both the main target and the virtual target.

### IBI Address

When sending In-Band Interrupts, the Target uses a separate IBI address derived from the
main (non-virtual) target's address with dynamic-over-static priority:

- If the Dynamic Address is valid, the IBI address is the Dynamic Address.
- Otherwise, the IBI address falls back to the Static Address.

This is implemented in `configuration.sv`:

    assign target_ibi_addr_o = target_dyn_addr_valid_o ? target_dyn_addr_o : target_sta_addr_o;
    assign target_ibi_addr_valid_o = target_sta_addr_valid_o || target_dyn_addr_valid_o;

IBI transmission is gated on `target_ibi_addr_valid`. If neither address is valid,
`target_ibi_addr_valid` is deasserted and any pending IBI requests are effectively masked
(the `ibi_pending` signal in `i3c_target_fsm.sv` requires `target_ibi_addr_valid_i`).

### Virtual Target Addressing

The virtual target (used for recovery) has its own independent address pair
(`VIRT_STATIC_ADDR`, `VIRT_DYNAMIC_ADDR`) with the same dynamic-over-static priority rule.
Both the main and virtual target addresses are checked in parallel on every incoming
transaction. When the virtual target address matches, the `virtual_device_sel` signal
routes the data path to the recovery handler, and TTI queue interrupts are gated.

## Private reads and writes

* The core handles I3C private reads and writes

  * This functionality passes Avery test suite tests
  * Private writes push data to the TTI RX Queue, accessible from the AXI bus, allowing the CPU to read the data

    * The number of received bytes is written into the TTI RX descriptor Queue
    * The software is supposed to first read the descriptor data, and then the number of bytes defined by the descriptor for the TTI RX Queue

  * Private reads send data on I3C lines from TTI TX Queue

    * The software has to write the TTI TX Queue prior to a I3C private read transaction
    * The TTI TX descriptor is used similarly to set the max number of bytes to be sent in the next private read transaction

## In-Band Interrupts (IBI)

The core is capable of raising In-Band Interrupts.
IBIs are controlled using descriptors written to a dedicated IBI queue by software.
Optional IBI data immediately follows the descriptor in the same queue.

The core watches the IBI queue for a descriptor write.
Once a descriptor is written, the core peeks it and waits until the defined count of data words is written to the queue.
Finally, the core outputs the Mandatory Data Byte (MDB) and the data as 8-bit words.

## I3C Common Command Codes (CCC)

The I3C core supports all CCCs required by the I3C Basic spec.
See {doc}`ccc` for the full list of supported CCCs, CCCs that update registers
without firmware notification, and CCC error handling.

## Other features

* Target Reset Pattern is detected and causes assertion of output pins, based on the action selected with RSTACT:

  * `peripheral_reset_o`
  * `escalated_reset_o`

* The core correctly detects HDR-Exit Pattern
* Optional 60 us HDR error recovery timer for TE0/TE1 error recovery (see {doc}`error_handling`)
* Target error detection (TE0-TE5) with interrupt reporting and saturating counters (see {doc}`error_handling`)

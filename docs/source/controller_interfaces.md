# Controller Interfaces

This chapter provides a description of the interfaces, which can be accessed over the AMBA bus.

All interfaces are implemented by sets of Control and Status Registers.
The I3C Core implements:
* the Host Controller Interface
* the Vendor-Specific Extended Capabilities Interface
   * Controller Config
   * Standby Controller Mode
   * Secure Firmware Recovery
   * Target Transaction Interface
   * SoC Management Interface

## Control and Status Registers

CSRs are implemented from the [SystemRDL description](https://github.com/chipsalliance/i3c-core/tree/main/src/rdl) using the [generated SV files](https://github.com/chipsalliance/i3c-core/tree/main/src/csr).
All CSRs are 32-bit wide.

## System Bus

The I3C Core provides options to use either AXI or AHB as the system bus.

### AXI communication

The AXI adapter provides an AXI frontend to integrate the I3C controller with the designated system.
The implementation is derived from Caliptra's implementation of the AXI subordinate, which is being developed on [this branch](https://github.com/chipsalliance/caliptra-rtl/tree/cwhitehead-msft-gen2-axi-modules).

### AHB communication

[The AHB adapter](https://github.com/chipsalliance/caliptra-rtl/blob/9c815c335a92901b27458271a885b2128e51e687/src/libs/rtl/ahb_to_reg_adapter.sv#L24) provides an AHB frontend to integrate the I3C controller with the designated system.
The AHB-Lite implementation is based on the AMBA 3 AHB-Lite Protocol Specification IHI0033A.

As of now, only the non-sequential transfer mode is supported.

The AHB-Lite interface is compliant with the Caliptra system and parameterizable. See [configuring the I3C Core] for more details.

If any of the parameters `haddress` or `hwdata` exceed 32-bits, then only the lowest 32-bits of the channel will be accounted for.

## Host Controller Interface (HCI)

The HCI defines the CSR layout and how the host should interact with them to trigger desired I3C functions.
The I3C core uses the PIO mode, meaning that all interaction between the core and the host happens through CSRs (as opposed to the DMA mode where there's a separate path for the core to access memory).

:::{figure-md} hci
![](img/hci.png)

Block diagram of the Controller Interface
:::

CI defines several CSR regions:
 * Controller Capabilities and Operation registers
 * PIO access registers
 * DAT table
 * DCT table
 * Linked list of Extended Capabilities

The Device Address Table (DAT) stores per-device entries containing their addresses.
When issuing a transaction, a command contains an index to this table.

The Device Characteristic Table (DCT) is read-only (for software) and gets populated by the controller core during I3C bus initialization.

The PIO CSR region contains registers used to access Command, Read, Write and Response Queue.
See section "7.5 PIO Mode Registers (PIO_BASE +)" of the HCI specification.

### Queues

CI queues facilitate communication between software-issued requests and the I3C controller logic.
Each request is issued through appropriate ports of the PIO Control register file.
The data is then collected from those ports and enqueued on appropriate queues.
The CI then issues enqueued commands to the I3C controller logic and fetches transaction responses (if present).

The queues are divided according to their purpose:
 * Command queue
    * 64-bit wide
    * Enqueues to-be-issued command descriptors
 * RX - Read queue
    * 32-bit wide
    * Enqueues data to be read by the host controller
 * TX - Write queue
    * 32-bit wide
    * Enqueues data written by the host controller
 * Response queue
    * 32-bit wide
    * Enqueues response descriptors of previously issued and completed commands

Both command and response descriptors are addressed with the index to the DAT table entry (as opposed to being directly-addressed).

Command descriptors are fixed to 64-bit (2-DWORD).
Response descriptors are fixed to 32-bit (1-DWORD).

For details, see the [Controller Interface Queues](ci_queues.md#controller-interface-queues) section.

### DAT & DCT

To increase flexibility of the design, both DAT and DCT tables are instantiated as memories external from the I3C Core.
Access paths to these memories are routed through the Controller Interface module directly to the underlying DAT/DCT access logic.
Such an approach ensures a very convenient way of replacing memory models for specific target architecture.

:::{figure-md} dat_dct
![](img/dat_dct.png)

Block diagram of DAT and DCT connections
:::

#### Device Address Table (DAT)

The Controller should perform initial I3C Bus enumeration after initialization.
During this process, the software driver should assign a static address for each device that is prior known on the bus.
Additionally, for every Dynamic Addressing capable Device, a dynamic address will be set for each valid DAT entry, as part of the Dynamic Address Assignment process.
Once the DAT is set up, devices can be assigned dynamic addresses in the following ways:
* **SETDASA** (direct) and **SETAASA** (broadcast) to assign a dynamic address based on a static address,
* **ENTDAA** to enter dynamic address assignment procedure.

After bus initialization, the DAT is not affected by physically removing the device from the bus and can be updated by sending the **SETNEWDA** (set new dynamic address) CCC or the **SETGRPA** (set group address) CCC.

Dynamically addressed I3C targets with their DAT entries can be reset by sending the **RSTDAA** command on the bus.
Assigned groups of addresses can be cleared by sending **RSTGRPA**.

In case the I3C Controller enters standby mode by passing the active controller role to another device, there is no requirement (on hardware) to keep the DAT table up-to-date.
However, when the I3C Controller transitions back to the Active Controller role, it should receive the **DEFTGTS** CCC that provides states of all targets present on the bus.
The software driver should then update the DAT table.

Since the DAT memory is writable from software, it must support single 32-bit word masked access so that the software can write data without overwriting the whole table entry.

#### Device Characteristic Table (DCT)

During dynamic address assignment, each target device on the bus must report its BCR, DCR and PID, which are then saved in the Device Characteristic Table.
The only I3C command that modifies the content of the DCT is **ENTDAA**.
From the software point of view, DCT memory is read only and should never be written to.

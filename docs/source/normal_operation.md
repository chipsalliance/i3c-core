# Normal operation

The following section details the software driver side of the normal operation: issuing the [data transfers](#data-transfers), [IBI interrupts](#in-band-interrupts-ibi-handling), [interrupts](#interrupts) handling and [address assignment](#address-assignment) procedure.

## Data transfers

I3C HCI specification allows two data transfer modes: DMA and PIO. In DMA mode the driver populates DMA descriptors to the core via its registers and instructs it to execute a transfer. In PIO mode certain registers are used to access FIFO queues and the driver needs to actively read/write data from/to them.

Our implementation supports PIO mode only.

According to "6.8.1 Transfers in PIO mode" and "6.12.1 PIO Mode" sections of the HCI spec the driver issues transfers to the core in the following manner:

 - If data is to be transmitted to a device the driver writes it to the Tx data queue by writing to the [XFER_DATA_PORT](https://github.com/chipsalliance/i3c-core-rdl/blob/main/src/csr/documentation.md#xfer_data_port-register) register. Some commands allow to provide data as immediate payload - for those no data needs to be written to the Tx queue.
 - The driver writes a command descriptor to the command queue port by writing the [COMMAND_PORT](https://github.com/chipsalliance/i3c-core-rdl/blob/main/src/csr/documentation.md#command_port-register) register.
 - The controller executes the transfer. To indicate transfer completion the core may report an interrupt.
 - Once the transfer is complete the driver reads command status from the response queue and received data (if any) from the Rx data queue.

Collecting responses and received data:

 - A response is provided by the controller to the driver in the following cases:
   - When a transfer is successful and `wroc` field is set in a corresponding command descriptor.
   - When a read transfer is successful (denoted by `rnw` field).
   - When a transfer generates an error (e.g. a short read request with `short_read_err` field set).
 - Driver can fetch the response descriptor by issuing a read from the [RESPONSE_PORT](https://github.com/chipsalliance/i3c-core-rdl/blob/main/src/csr/documentation.md#response_port-register) register.
   - A reached response threshold is indicated with [RESP_READY_STAT](https://github.com/chipsalliance/i3c-core-rdl/blob/main/src/csr/documentation.md#resp_ready-field) by the controller when the [RESP_READY_STAT_EN](https://github.com/chipsalliance/i3c-core-rdl/blob/main/src/csr/documentation.md#resp_ready_en-field) is set.
   A threshold interrupt is raised in accordance to [RESP_BUF_THLD](https://github.com/chipsalliance/i3c-core-rdl/blob/main/src/csr/documentation.md#resp_buf-field).
   - In case of a read request when no response is available, the controller shall raise an error on the frontend bus interface (AHB / AXI).
   - Upon a successful read from the `RESPONSE_PORT` driver is to decode the response in accordance to [response descriptor](#response-descriptor) definition and verify the `tid`.
   The `tid` should match the `tid` of a previously enqueued command.
 - Received transfer data can be obtained by the driver via a read from [XFER_DATA_PORT](https://github.com/chipsalliance/i3c-core-rdl/blob/main/src/csr/documentation.md#xfer_data_port-register) register.
   - A reached received data threshold is indicated by the controller with [TX_THLD_STAT](https://github.com/chipsalliance/i3c-core-rdl/blob/main/src/csr/documentation.md#rx_threshold-field) interrupt if [RX_THLD_STAT_EN](https://github.com/chipsalliance/i3c-core-rdl/blob/main/src/csr/documentation.md#rx_threshold_en-field) is set.
   The RX threshold can be set via [RX_BUF_THLD](https://github.com/chipsalliance/i3c-core-rdl/blob/main/src/csr/documentation.md#rx_buf-field).
   - In case of a read when no RX data is available, the controller shall raise an error on the frontend bus interface (AHB / AXI).

Note that the `XFER_DATA_PORT` register is dual purpose - when writing data is passed to the Tx queue, when reading data is fetched from the Rx queue.

Section "8.4 Command Descriptor" describes in detail the format of commands for the core. Section "8.5 Response Descriptor" describes the structure of a response from the core.

### Command Descriptors

#### Immediate transfer
```{list-table} *Immediate transfer descriptor*
:header-rows: 1
:widths: 10 22 68

- * Range
  * Name
  * Description
- * [63:56]
  * data_byte4
  * 4th byte of the data for the transfer
- * [55:48]
  * data_byte3
  * 3rd byte of the data for the transfer
- * [47:40]
  * data_byte2
  * 2nd byte of the data for the transfer
- * [39:32]
  * def_or_data_byte1
  * Defining byte or a 1st byte of the data for the transfer
- * [31]
  * toc
  * Terminate on completion

    `1'b0`: Restart after the end of the transfer

    `1'b1`: Stop at the end of the transfer
- * [30]
  * wroc
  * If set send response on completion of the successful transfer
- * [29]
  * rnw
  * Direction;
    Must be set to `0'b0` - immediate transfers are write only
- * [28:26]
  * mode
  * Mode and speed of the transfer

    `3'b000`: SDR0 - Standard SDR speed (up to 12.5 MHZ)

    `3'b001` - `3'b100`: SDR1 - SDR4 - Reduced data rates

    `3'b101`: HDR TSx - HDR ternary mode

    `3'b110`: HDR DDR - HDR double data rate mode

    `3'b111`: Reserved
- * [25:23]
  * dtt
  * Type and Byte count
    Number of valid data bytes
- * [22:21]
  * __rsvd22_21
  * Reserved
- * [20:16]
  * dev_index
  * Device index indicating DAT table index for the target device
- * [15]
  * cp
  * Command present
    Indicates validity of the `cmd` field
- * [14:7]
  * cmd
  * CCC / HDR command code value
- * [6:3]
  * tid
  * Transaction ID
- * [2:0]
  * cmd_attr
  * Command Attribute
    Must be `3'b001`
```
#### Regular transfer
```{list-table} *Regular transfer descriptor*
:header-rows: 1
:widths: 10 20 70

- * Range
  * Name
  * Description
- * [63:48]
  * data_length
  * Transfer's data length
- * [47:40]
  * __rsvd47_40
  * Reserved
- * [39:32]
  * def_byte
  * Defining byte
- * [31]
  * toc
  * Terminate on completion

    `1'b0`: Restart after the end of the transfer

    `1'b1`: Stop at the end of the transfer
- * [30]
  * wroc
  * If set send response on completion of the successful transfer
- * [29]
  * rnw
  * Direction;

    `1'b0`: Write transfer

    `1'b1`: Read transfer
- * [28:26]
  * mode
  * Mode and speed of the transfer

    `3'b000`: SDR0 - Standard SDR speed (up to 12.5 MHZ)

    `3'b001` - `3'b100`: SDR1 - SDR4 - Reduced data rates

    `3'b101`: HDR TSx - HDR ternary mode

    `3'b110`: HDR DDR - HDR double data rate mode

    `3'b111`: Reserved
- * [25]
  * dbp
  * Defining Byte for CCC present
    If `1'b1` the `def_byte` contains defining byte
- * [24]
  * short_read_err
  * If `1'b0` short reads are allowed
    Otherwise, short reads are treated as an error
- * [23:21]
  * __rsvd23_21
  * Reserved
- * [20:16]
  * dev_index
  * Device index indicating DAT table index for the target device
- * [15]
  * cp
  * Command present
    Indicates validity of the `cmd` field
- * [14:7]
  * cmd
  * CCC / HDR command code value
- * [6:3]
  * tid
  * Transaction ID
- * [2:0]
  * cmd_attr
  * Command Attribute
    Must be `3'b000`
```

### Response descriptor

```{list-table} *Response descriptor*
:header-rows: 1
:widths: 10 20 70

- * Range
  * Name
  * Description
- * [31:28]
  * err_status
  * Error status
    * `4'b0000`: Success
    * `4'b0001`: CRC
    * `4'b0010`: Parity
    * `4'b0011`: Frame
    * `4'b0100`: Address Header
    * `4'b0101`: Address was NACK'ed or Dynamic Address Assignment was NACK'ed
    * `4'b0110`: Received overflow or transfer underflow
    * `4'b0111`: Target returned fewer bytes than requested in `DATA_LENGTH` field of a transfer command where short read was not permitted
    * `4'b1000`: Terminated by controller due to internal error or Abort operation
    * `4'b1001`: Transfer terminated by due to bus action:
      * for I2C transfers: `I2C_WR_DATA_NACK`
      * for I3C transfers: `BUS_ABORTED`
    * `4'b1010`: Command not supported by the Controller implementation
    * `4'b1011`: Reserved
    * `4'b1100` - `4'b1111`: Transfer Type Specific Errors
- * [27:24]
  * tid
  * Transaction ID; should match the tid of the previously enqueued command
- * [23:16]
  * __rsvd23_16
  *   Reserved
- * [15:0]
  * data_length
  *
    * Received data in case of write transfers
    * Remaining data in case of read transfers
    * Remaining device count in case of address assignment procedure
```
## In-band interrupts (IBI) handling

IBI are interrupts reported by I3C devices via in-band signaling on the bus. Sections "6.9.1 IBI Handling in PIO Mode":

 - When the controller receives IBI from a target device is stores it in the IBI queue. Once the queue occupancy exceeds the threshold set by `IBI_STATUS_THLD_STAT` of the [QUEUE_THLD_CTRL](https://github.com/chipsalliance/i3c-core-rdl/blob/main/src/csr/documentation.md#queue_thld_ctrl-register) register an interrupt is triggered.
 - IBI descriptors can then be read from IBI data queue via the [IBI_PORT](https://github.com/chipsalliance/i3c-core-rdl/blob/main/src/csr/documentation.md#ibi_port-register) register.

IBI status descriptor structure is described in "8.6 IBI Status Descriptor" chapter of the spec.

## Interrupts

Events related to transfers trigger certain interrupts in the core that are signaled to the host. Individual interrupt signals can be enabled or disabled via the [PIO_INTR_SIGNAL_ENABLE](https://github.com/chipsalliance/i3c-core-rdl/blob/main/src/csr/documentation.md#pio_intr_signal_enable-register) register.

Interrupts status can be read from the [PIO_INTR_STATUS](https://github.com/chipsalliance/i3c-core-rdl/blob/main/src/csr/documentation.md#pio_intr_status_enable-register) register.

Interrupts related to Tx and Rx data queues namely `TX_THLD_SIGNAL_EN` and `RX_THLD_SIGNAL_EN` are triggered when queue occupancy raises above / falls below a certain threshold. These thresholds are controlled by fields of the [DATA_BUFFER_THLD_CTRL](https://github.com/chipsalliance/i3c-core-rdl/blob/main/src/csr/documentation.md#data_buffer_thld_ctrl-register) register:
  - `RX_BUF_THLD` for the receive queue,
  - `TX_BUF_THLD` for the transmit queue.

For command, response and IBI queues the register [QUEUE_THLD_CTRL](https://github.com/chipsalliance/i3c-core-rdl/blob/main/src/csr/documentation.md#queue_thld_ctrl-register) defines thresholds for interrupt triggering:
  - `IBI_STATUS_THLD` for IBI status queue,
  - `IBI_DATA_THLD` for IBI data queue,
  - `RESP_BUF_THLD` and `CMD_EMPTY_BUF_THLD` for command response queue.


There's also the [PIO_INTR_FORCE](https://github.com/chipsalliance/i3c-core-rdl/blob/main/src/csr/documentation.md#pio_intr_force-register) that allows to force trigger certain interrupts for debugging purposes.

## Address Assignment

### Device Management

#### Device Attach, Enumeration, and Initialization

The Controller assigns a dynamic address for each device on the I3C Bus. For devices with static addresses, dynamic address is equal to the static address. Each device must have its entry in the Device Address Table (DAT) before initiating dynamic address assignment. Each DAT entry must contain field value in either [STATIC_ADDRESS](https://github.com/chipsalliance/i3c-core-rdl/blob/main/src/csr/documentation.md#static_addr-field) (if it is known) or a [DYNAMIC_ADDRESS](https://github.com/chipsalliance/i3c-core-rdl/blob/main/src/csr/documentation.md#dynamic_adr-field).
Once the DAT table is set up, the software driver should follow at least one of the following scenarios (while preserving order):
1. Send `SETDASA` CCC to assign static address for a chosen device  or send `SETAASA` CCC to assign static address for all devices with known static address.
2. Send `ENTDAA` CCC to initiate procedure of dynamic address assignment for all devices configured in DAT.

After finished `ENTDAA` process, the Device Characteristic Table (DCT) will be updated with values read from devices configured on the I3C Bus.

Initial bus enumeration process should be performed in the following order:
1. Check sizes of DAT and DCT by reading [DAT_SECTION_OFFSET](https://github.com/chipsalliance/i3c-core-rdl/blob/main/src/csr/documentation.md#dat_section_offset-register) and [DCT_SECTION_OFFSET](https://github.com/chipsalliance/i3c-core-rdl/blob/main/src/csr/documentation.md#dct_section_offset-register).
2. Set up DAT entries for devices with static address and send `SETDASA`/`SETAASA` CCC.
3. Set up DAT entries for devices with dynamic address and send `ENTDAA` CCC.
4. If any I3C device needs to change dynamic address, send `SETNEWDA` CCC to assign new address and ensure there is no error on the bus.

In case of incorrect results of the Dynamic Addressing procedure, the software can either send `SETNEWDA` CCC to misconfigured devices or send `RSTDAA` CCC to reset all dynamic addresses and then repeat the Dynamic Addressing procedure.

Hot-Join request from I3C Target Devices should be handled automatically by the Host Controller. The driver should detect the Hot-Join IBI and populate a new entry in the DAT table.

The driver should always refer to a device entry in the DAT table to schedule a transfer, the Controller will use appropriate address (either static or dynamic) that matches such entry. For I2C devices, the static address will always be used.

#### Device Detach, Reset, and Power Management

Upon a device detach event, the DAT entry shall not be altered. The assigned address is reserved, the software can re-use it by executing an address assignment command targeting the specific DAT entry.

If the detached device re-attaches to the bus, it will use the same DAT entry as before if it was not overwritten.

Once the new device joins the bus, it should wait for the Controller to assign a dynamic address.

Since there can be an offline capable device, it might not respond to directed commands immediately and the driver should allow devices to take time to respond, with retries and/or longer timeout.

#### Device Context

The context of a device on the bus is realized through the DAT and the DCT tables. The DCT table is transient and can be significantly smaller than the DAT, since it is only used during the address assignment procedure (`ENTDAA`). The software should copy contents of a DCT entry to the internal driver context, on a per-device basis.

The software can disable Controller Role Request (CRR) and In-Band Interrupt (IBI) for each device in their respective DAT entries. If either CRR or IBI should be re-enable, the driver should modify the [CRR_REJECT](https://github.com/chipsalliance/i3c-core-rdl/blob/main/src/csr/documentation.md#crr_reject-field)/[IBI_REJECT](https://github.com/chipsalliance/i3c-core-rdl/blob/main/src/csr/documentation.md#ibi_reject-field) field in DAT and send a `ENEC` CCC to such device.

If IBIs are disable using target IBI credit mechanism, when the target's credit counter is zero, then the Host Controller shall automatically re-enable IBIs for that Target using the `ENEC` CCC, after the software writes to that Target’s register `TARGET_CREDIT_N`.

### Device Addressing

#### Dynamic Address Assignment with ENTDAA

Each I3C target device that supports the ENTDAA procedure and that has not been assigned static addresses should have assigned dynamic address during Dynamic Address Assignment procedure based on the DAT table entry. For each DAT entry, software shall:
* Set the [DEVICE](https://github.com/chipsalliance/i3c-core-rdl/blob/main/src/csr/documentation.md#dev-field) field to indicate the Device’s type
* Set the [DYNAMIC_ADDRESS](https://github.com/chipsalliance/i3c-core-rdl/blob/main/src/csr/documentation.md#dynamic_adr-field) field to indicate the Device’s preferred Dynamic Address

After DAT configuration, software shall:
1. Enqueue one or more Command Descriptors of Address Assignment Command type for the `ENTDAA` CCC, using the steps listed in Section 8.4.1.1
2. Wait for a response and ensure that the response descriptor indicates a successful result
3. For each successful response: read the [PID](https://github.com/chipsalliance/i3c-core-rdl/blob/main/src/csr/documentation.md#pid_hi-field), [BCR](https://github.com/chipsalliance/i3c-core-rdl/blob/main/src/csr/documentation.md#bcr-field) and [DCR](https://github.com/chipsalliance/i3c-core-rdl/blob/main/src/csr/documentation.md#dcr-field) values from the appropriate fields of the indicated entries in the DCT for the assigned Dynamic Address(es) as part of the `ENTDAA` process:
    A. Note that these values are transient, so software must read them and save them internally before performing subsequent Address Assignment commands with the `ENTDAA` CCC
    B. Each DCT entry for a successful assignment with the `ENTDAA` modal flow shall have the same value in field [DYNAMIC_ADDRESS](https://github.com/chipsalliance/i3c-core-rdl/blob/main/src/csr/documentation.md#dynamic_addr-field-1) as the corresponding DAT entry [DYNAMIC_ADDRESS](https://github.com/chipsalliance/i3c-core-rdl/blob/main/src/csr/documentation.md#dynamic_adr-field) that was used for the I3C Device to which this address was assigned

If the address assignment command completes with **NACK**, it means one of following:
* There are no I3C devices available to participate
* Not all devices were assigned an address, this is indicated by `DATA_LENGTH` value in the response descriptor lower than `DEV_COUNT` value in the command descriptor
* There were no addresses assigned to any devices (no I3C devices responded), this is indicated by `DATA_LENGTH` value in the response descriptor equal to `DEV_COUNT` value in the command descriptor

#### Using Static Addresses

For each I3C target device with known address and each I2C target device, software shall write this address to [STATIC_ADDRESS](https://github.com/chipsalliance/i3c-core-rdl/blob/main/src/csr/documentation.md#static_addr-field) field  of respective DAT table entry. For each such DAT entry, software shall:
* Set the [DEVICE](https://github.com/chipsalliance/i3c-core-rdl/blob/main/src/csr/documentation.md#dev-field) field to indicate the Device’s type
* Set the [DYNAMIC_ADDRESS](https://github.com/chipsalliance/i3c-core-rdl/blob/main/src/csr/documentation.md#dynamic_adr-field) field to indicate the Device’s preferred Dynamic Address

After DAT configuration, software shall:
1. For I3C devices configured with `SETDASA` CCC:
   A. Enqueue one or more command descriptors of address assignment command type for the `SETDASA` CCC, using the steps listed in Section 8.4.1.2
   B. Wait for a response and ensure that the response descriptor indicates a successful result
2. For those I3C Devices which will be configured with the `SETAASA` CCC:
   A. Enqueue one command descriptor of immediate data transfer command type for the `SETAASA` Broadcast CCC, as a standard CCC (i.e., not an address assignment command)
   B. Wait for a response and ensure that the response descriptor indicates a successful result

If the address assignment command for `SETDASA` completes with **NACK**, it means that the configured device is not present, or was not ready, or did not detect the `SETDASA` CCC on the bus.

If the address assignment command for `SETAASA` completes with **NACK**, there is no method to determine the status of any individual I3C target device that was asked to assign its own static address as dynamic address.

#### Grouped Addressing

The I3C Controller supports grouping multiple I3C target devices to manage multiple devices at a single address. Since group addresses share the same address space as valid I3C dynamic addresses, software must avoid assigning conflicting addresses (i.e., dynamic and group address having the same value).

Possible operations for group management:
* The Controller may assign the I3C target device to a group address by sending a direct `SETGRPA` CCC addressed to a dynamic address
* The Controller may assign the I3C target device to a group address by sending a direct `RSTGRPA` CCC addressed to either dynamic address or the group address
* The Controller may disband all groups by sending a broadcast `RSTGRPA` CCC

Each group address must have a dedicated DAT entry which can be accessed from the Controller for write-type transfers. Software shall not perform read operations on group addresses.

## Linux Kernel

* [Linux driver for I3C Controller Mode](https://github.com/torvalds/linux/tree/master/drivers/i3c/master)
* [Pending patch for adding I3C target mode support in Linux Kernel](https://patchwork.kernel.org/project/linux-i3c/list/?series=851338)

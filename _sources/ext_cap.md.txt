# Specification for I3C Vendor-Specific Extended Capabilities

This chapter is the normative specification of the Vendor-Specific Extended Capabilities for the I3C Controller as per section 7.7.13 of the [I3C HCI Specification](introduction.md#spec-i3c-hci).

## Security

The original HCI specification defines Extended Capabilities as a list of linked lists, which can be discovered from software through a series of CSR reads.
This mechanism is unacceptable for the Recovery Mode as memory offsets must be known at synthesis time.
Implementation based on this specification shall provide a list of known memory offsets for each of the Extended Capabilities.

:::{note}
In order to increase security of the solution, the offsets are provided, so software may choose to skip the discovery mechanism. This specification is compliant with the original specification, so the mechanism of discovery can still be used, if needed.
:::

## Extended Capabilities

### Standby Controller Mode (ID=0x12)

The Standby Controller Mode follows the [I3C HCI Specification](introduction.md#spec-i3c-hci):
* Chapter 6 Theory of Operation
    * Section 6.17 Standby Controller Mode
* Chapter 7 Register Interface
    * Section 7.7.11 Standby Controller Mode

## Vendor-specific Extended Capabilities

This specification provides definitions and descriptions of the following Capabilities:

* Controller Config
* Standby Controller Mode
* Secure Firmware Recovery Interface
* Target Transaction Interface
* SoC Management Interface

:::{list-table} Extended capabilities registers
:name: tab-capabilities-registers
:widths: 60 20 20

* - **Extended Capability**
  - **ID**
  - **Memory Offset**
* - Controller Config
  - 0x02
  - Implementer
* - Standby Controller Mode
  - 0x12
  - Implementer
* - Secure Firmware Recovery Interface
  - 0xC0
  - Implementer
* - SoC Management Interface
  - 0xC1
  - Implementer
* - Target Transaction Interface
  - 0xC4
  - Implementer
:::

### Controller Config (ID=0x02)

The Controller Config Capability follows section 7.7.3 of the [I3C HCI Specification](introduction.md#spec-i3c-hci).

### <a name="secure_firmware_recovery_interface"/>Secure Firmware Recovery Interface (ID=0xC0)

This section is based on the Open Compute Project Secure Firmware Recovery, Version 1.0 and I3C Target Recovery Specification

The `EXTCAP_HEADER` is located at memory offset `SEC_FW_RECOVERY_OFFSET`.
The registers are aligned to DWORD size (4 bytes), unless specified otherwise.

:::{list-table} Secure Firmware Recovery Interface
:name: tab-secure-firmware-recovery-interface
:widths: 40 60

* - **Register Name**
  - **Role**
* - EXTCAP_HEADER
  - Information about the Extended Capability
* - PROT_CAP_0
  - Device Capabilities Information
* - PROT_CAP_1
  - Device Capabilities Information
* - PROT_CAP_2
  - Device Capabilities Information
* - PROT_CAP_3
  - Device Capabilities Information
* - DEVICE_ID_0
  - Device identity information
* - DEVICE_ID_1
  - Device identity information
* - DEVICE_ID_2
  - Device identity information
* - DEVICE_ID_3
  - Device identity information
* - DEVICE_ID_4
  - Device identity information
* - DEVICE_ID_5
  - Device identity information
* - DEVICE_ID_6
  - Device identity information
* - DEVICE_STATUS_0
  - Device status information
* - DEVICE_STATUS_1
  - Device status information
* - DEVICE_RESET
  - Device reset and control
* - RECOVERY_CTRL
  - Recovery control and image activation
* - RECOVERY_STATUS
  - Recovery status information
* - HW_STATUS
  - Hardware status including temperature
* - INDIRECT_FIFO_CTRL_0
  - Indirect memory window control
* - INDIRECT_FIFO_CTRL_1
  - Indirect memory window control
* - INDIRECT_FIFO_STATUS_0
  - Indirect memory window status
* - INDIRECT_FIFO_STATUS_1
  - Indirect memory window status
* - INDIRECT_FIFO_STATUS_2
  - Indirect memory window status
* - INDIRECT_FIFO_STATUS_3
  - Indirect memory window status
* - INDIRECT_FIFO_STATUS_4
  - Indirect memory window status
* - INDIRECT_FIFO_STATUS_5
  - Indirect memory window status
* - INDIRECT_FIFO_DATA
  - Indirect memory window for pushing recovery image
:::


### SoC Management Interface (ID=0xC1)

The SoC Management Interface is provided to enable additional configuration capabilities to the system integrator, e.g. programmability of PHY Devices.

Features may include programmability of:

* High Keeper strength and enable
* Push-pull driver strength
    * Slew rate control
* Open-drain driver strength
    * Slew rate control
* Calibration of the on-chip resistor

The `SOC_MGMT_EXTCAP_HEADER` is located at memory offset `SOC_MGMT_SECTION_OFFSET`.
The registers are aligned to DWORD size (4 bytes), unless specified otherwise.

:::{list-table} SoC Management Interface
:name: tab-soc-management-interface
:widths: 50 50

* - **Register Name**
  - **Role**
* - SOC_MGMT_EXTCAP_HEADER
  - Information about the Extended Capability
* - SOC_MGMT_CONTROL
  - TBD
* - SOC_MGMT_STATUS
  - TBD
* - SOC_MGMT_RSVD_0
  - TBD
* - SOC_MGMT_RSVD_1
  - TBD
* - SOC_MGMT_RSVD_2
  - TBD
* - SOC_MGMT_RSVD_3
  - TBD
* - SOC_MGMT_FEATURE_0
  - TBD
* - SOC_MGMT_FEATURE_1
  - TBD
* - SOC_MGMT_FEATURE_2
  - TBD
* - SOC_MGMT_FEATURE_3
  - TBD
* - …
  - TBD
* - SOC_MGMT_FEATURE_15
  - TBD
:::

Details of the operation are implementation specific.
It is permissible to implement all registers as generic RW registers.

### Target Transaction Interface (ID=0xC4)

The Target Transaction Interface (TTI) provides additional registers and queues to enable data flow for Devices configured in the Target Mode.
This specfication is meant for Standby Controllers, which are capable of operating in Target Mode, therefore implementations are required to advertise the TTI by setting the `Target_XACT_SUPPORT` field of the `STBY_CR_CAPABILITIES`.

:::{note}
The term "TX" is used to denote instances in which the software performs a write to respond to an I3C Bus Read transaction.
:::

:::{note}
The term "RX" is used to denote instances in which the software performs a read to respond to an I3C Bus Write transaction
:::

#### Motivation and design choices (informative)

* Width of the interface
    * This TTI will be integrated in an SoC with 64b AXI as the System Bus
    * CSRs in the I3C HCI specifciation are 32b wide, so it makes sense to use the same width
    * Each System Bus read could potentially hold 2 CSRs
        * [Recommended] Do not use the upper half of the word
        * [Optimized] Read 2 CSRs (this specification does not define how to handle region boundaries and resulting errors)
    * TTI Queues will also be 32b wide for the same reason
* Communication scenarios with I3C Devices
    * When valid I3C frame appears and bit RnW is set to Read, then Device has a timing constraint on providing valid data
        * Typically, this is not a problem for simple sensors, which can prepopulate data
        * Problem for a SoC
            * Unknown response latency over System Bus
            * Unknown ISR processing latency
        * I2C solves this issue by using Clock Stretching by Target
            * Prohibited by I3C Basic Specification
        * I3C allows Controller to stretch Clock (Section 5.1.2.5, I3C Basic)
            * Does not alleviate Target side timing issues
    * There are 2 designs, which are considered here to increase robustness
        * Write-first approach: Before each Read from this Device, a Write is issued to inform Target to prepare the payload
            * Timing issue may still appear, but the timing budget is larger by a factor of (transfer length / bit length)
        * Write-first Expect-IBI: Reads are only performed based on an IBI with Pending Read Notification (Section 5.1.6.2.2, I3C Basic).
          Reads occur only when the Target Device has valid data, completely solves the timing issue, assuming that data length does not exceed buffer length.

#### Boot

The Target Device boots with bus operation disabled as per description of field `STBY_CR_ENABLE_INT` in the register `STBY_CR_CONTROL` (section 7.7.11.1)

#### Initialization

Software is responsible for setting bit `TARGET_XACT_ENABLE` in the `STBY_CR_CONTROL` register.

#### Operation

TTI is used to handle generic Read-Type and Write-Type transactions sent by the Active Controller on the I3C bus.
In this mode, software is responsible for servicing TX and RX queues based on the interrupt signals.

There are 5 queues to communicate between the bus and the register interface:

* TX Descriptor queue, which holds information about the write transfer
* TX Data queue to buffer data, which is written from the Target Device to the bus
* RX Descriptor queue, which holds information about the read transfer
* RX Data queue to buffer data, which is read from the bus by the Target Device
* IBI queue to buffer data, which will be written to the Bus as an In-Band Interrupt

##### Bus Read Transaction

After the Bus Read Transaction is acknowledged by the Target Device, it performs a write to the Interrupt Register to inform software of a pending read transaction.
Software writes the response data to the TX queue and the TX descriptor to the TTI TX Descriptor queue.

:::{note}
Writing a large chunk of data into the TX queue and then writing the TX Descriptor can be too slow.
It is permissible to write 32b data to the TX queue, then writing the TX descriptor, then filling the queue with the rest of the data.
:::

:::{note}
If 2 consecutive long writes (252B) to the TX buffer occur, then:

* The Target Device should raise an interrupt
* The Target Device should generate status error that write to the buffer failed
* How do you clean up the data that was written? Mechanism can break in unknown state
    * Current state of FIFO is only accessible via Debug EC
* Issuing soft reset can break the pending transaction
    * Software should be notified when pending transaction is done
:::

##### Bus Write Transaction

The Bus Write Transaction is acknowledged by the Device if the transaction address matches the Device address and the R/W bit is set to `1`.
The Target Device writes incoming bytes to the TTI RX Data Queue.
After the transaction ends, a TTI RX Descriptor is generated and pushed to the TTI RX Descriptor Queue for the software access.

If an Active Controller writes more data to the Target Device than it is capable to handle (even with triggering interrupts on threshold), the generated TTI RX Descriptor should indicate an error status and the Target Device should not ACK data on the bus.
The Active Controller can attempt mitigating such situation by reading Target queue size from `TTI_QUEUE_SIZE` register before sending big chunk of data.

##### In-Band Interrupts

The Controller expects to receive an IBI Status Descriptor which is then followed by consecutive DWORDs of IBI Data.
The IBI Status Descriptor should be compliant with section "8.6 IBI Status Descriptor" of the MIPI I3C HCI specification v1.2.
If the IBI requires more data to be sent than allowed in a single chunk, it should be split into multiple IBI transfers with `LAST_STATUS` IBI Descriptor field set to `0` unless it is the last one.

#### Register Interface

The `TTI_EXTCAP_HEADER` is located at memory offset `TTI_SECTION_OFFSET`.
The registers are aligned to DWORD size (4 bytes), unless specified otherwise.

:::{list-table} TTI Register Interface
:name: tab-tti-register-interface
:widths: 50 50

* - Register Name
  - Role
* - TTI_EXTCAP_HEADER
  - Information about the Extended Capability
* - TTI_CONTROL
  - Software control, mode, operation
* - TTI_STATUS
  - Report status
* - TTI_INTERRUPT_STATUS
  - Status of outstanding TTI interrupts
* - TTI_INTERRUPT_ENABLE
  - Control register for outstanding TTI interrupts
* - TTI_INTERRUPT_FORCE
  - Force trigger of outstanding TTI interrupts for debugging purposes
* - TTI_RX_DESC_QUEUE_PORT
  - Access port to TTI RX Descriptor Queue
* - TTI_RX_DATA_PORT
  - Access port to TTI RX Data Queue
* - TTI_TX_DESC_QUEUE_PORT
  - Access port to TTI TX Descriptor Queue
* - TTI_TX_DATA_PORT
  - Access port to TTI TX Data Queue
* - TTI_QUEUE_SIZE
  - Information about TTI RX Descriptor, TTI RX Data, TTI TX Descriptor, TTI TX Data queue sizes
* - TTI_QUEUE_THLD_CONTROL
  - Control register for trigger threshold level of TTI Queues interrupts
:::

##### TTI_CONTROL Register

:::{list-table} *TTI_CONTROL Register*
:name: tab-tti-control-register
:widths: 10 30 13 9 38
* - **Size [bits]**
  - **Field Name**
  - **Memory Access**
  - **Reset Value**
  - **Description**
* - TBD
  - TBD
  - TBD
  - TBD
  - TBD
:::

##### TTI_STATUS Register

:::{list-table} *TTI_STATUS Register*
:name: tab-tti-status-register
:widths: 10 30 13 9 38
* - **Size [bits]**
  - **Field Name**
  - **Memory Access**
  - **Reset Value**
  - **Description**
* - TBD
  - TBD
  - TBD
  - TBD
  - TBD
:::

##### TTI_RESET_CONTROL Register

:::{list-table} *TTI_RESET_CONTROL Register*
:name: tab-tti-reset-control-register
:widths: 10 30 13 9 38
* - **Size [bits]**
  - **Field Name**
  - **Memory Access**
  - **Reset Value**
  - **Description**
* - 1 [5]
  - IBI_QUEUE_RST
  - R/W
  - 0x0
  - TTI IBI Queue Buffer Software Reset
* - 1 [4]
  - RX_DATA_RST
  - R/W
  - 0x0
  - TTI RX Data Queue Buffer Software Reset
* - 1 [3]
  - TX_DATA_RST
  - R/W
  - 0x0
  - TTI TX Data Queue Buffer Software Reset
* - 1 [2]
  - RX_DESC_RST
  - R/W
  - 0x0
  - TTI RX Descriptor Queue Buffer Software Reset
* - 1 [1]
  - TX_DESC_RST
  - R/W
  - 0x0
  - TTI TX Descriptor Queue Buffer Software Reset
* - 1 [0]
  - SOFT_RST
  - R/W
  - 0x0
  - Target Core Software Reset
:::

##### TTI_INTERRUPT_STATUS Register

The status fields are either R/W1C (write 1 to clear), or else are cleared based on queue operations.

:::{list-table} *TTI_INTERRUPT_STATUS Register*
:name: tab-tti-interrupt-status-register
:widths: 10 30 13 9 38
* - **Size [bits]**
  - **Field Name**
  - **Memory Access**
  - **Reset Value**
  - **Description**
* - 1 [31]
  - TRANSFER_ERR_STAT
  - R/W1C
  - 0x0
  - Bus error occurred
* - 1 [25]
  - TRANSFER_ABORT_STAT
  - R/W1C
  - 0x0
  - Bus aborted transaction
* - 1 [12]
  - IBI_THLD_STAT
  - R
  - 0x0
  - TTI IBI Buffer Threshold Status, the Target Controller shall set this bit to 1 when the number of available entries in the TTI IBI Queue is >= the value defined in `TTI_IBI_THLD`
* - 1 [11]
  - RX_DESC_THLD_STAT
  - R
  - 0x0
  - TTI RX Descriptor Buffer Threshold Status, the Target Controller shall set this bit to 1 when the number of available entries in the TTI RX Descriptor Queue is >= the value defined in `TTI_RX_DESC_THLD`
* - 1 [10]
  - TX_DESC_THLD_STAT
  - R
  - 0x0
  - TTI TX Descriptor Buffer Threshold Status, the Target Controller shall set this bit to 1 when the number of available entries in the TTI TX Descriptor Queue is >= the value defined in `TTI_TX_DESC_THLD`
* - 1 [9]
  - RX_DATA_THLD_STAT
  - R
  - 0x0
  - TTI RX Data Buffer Threshold Status, the Target Controller shall set this bit to 1 when the number of entries in the TTI RX Data Queue is >= the value defined in `TTI_RX_DATA_THLD`
* - 1 [8]
  - TX_DATA_THLD_STAT
  - R
  - 0x0
  - TTI TX Data Buffer Threshold Status, the Target Controller shall set this bit to 1 when the number of available entries in the TTI TX Data Queue is >= the value defined in `TTI_TX_DATA_THLD`
* - 1 [3]
  - TX_DESC_TIMEOUT
  - R/W1C
  - 0x0
  - Pending Write was NACK’ed, because the `TX_DESC_STAT` event was not handled in time
* - 1 [2]
  - RX_DESC_TIMEOUT
  - R/W1C
  - 0x0
  - Pending Read was NACK’ed, because the `RX_DESC_STAT` event was not handled in time
* - 1 [1]
  - TX_DESC_STAT
  - R/W1C
  - 0x0
  - There is a pending Write Transaction on the I3C Bus. Software should write data to the TX Descriptor Queue and the TX Data Queue
* - 1 [0]
  - RX_DESC_STAT
  - R/W1C
  - 0x0
  - There is a pending Read Transaction. Software should read data from the RX Descriptor Queue and the RX Data Queue
:::

##### TTI_INTERRUPT_ENABLE Register

:::{list-table} *TTI_INTERRUPT_ENABLE Register*
:name: tab-tti-interrupt-enable-register
:widths: 10 30 13 9 38
* - **Size [bits]**
  - **Field Name**
  - **Memory Access**
  - **Reset Value**
  - **Description**
* - 1 [4]
  - IBI_THLD_STAT_EN
  - R/W
  - 0x0
  - Enables the corresponding interrupt bit `TTI_IBI_THLD_STAT`
* - 1 [3]
  - RX_DESC_THLD_STAT_EN
  - R/W
  - 0x0
  - Enables the corresponding interrupt bit `TTI_RX_DESC_THLD_STAT`
* - 1 [2]
  - TX_DESC_THLD_STAT_EN
  - R/W
  - 0x0
  - Enables the corresponding interrupt bit `TTI_TX_DESC_THLD_STAT`
* - 1 [1]
  - RX_DATA_THLD_STAT_EN
  - R/W
  - 0x0
  - Enables the corresponding interrupt bit `TTI_RX_DATA_THLD_STAT`
* - 1 [0]
  - TX_DATA_THLD_STAT_EN
  - R/W
  - 0x0
  - Enables the corresponding interrupt bit `TTI_TX_DATA_THLD_STAT`
:::

##### TTI_INTERRUPT_FORCE Register

:::{list-table} *TTI_INTERRUPT_FORCE Register*
:name: tab-tti-interrupt-force-register
:widths: 10 30 13 9 38
* - **Size [bits]**
  - **Field Name**
  - **Memory Access**
  - **Reset Value**
  - **Description**
* - 1 [4]
  - IBI_THLD_FORCE
  - R/W
  - 0x0
  - Forces the corresponding interrupt bit `TTI_IBI_THLD_STAT` to be set to `1`
* - 1 [3]
  - RX_DESC_THLD_FORCE
  - R/W
  - 0x0
  - Forces the corresponding interrupt bit `TTI_RX_DESC_THLD_STAT` to be set to `1`
* - 1 [2]
  - TX_DESC_THLD_FORCE
  - R/W
  - 0x0
  - Forces the corresponding interrupt bit `TTI_TX_DESC_THLD_STAT` to be set to `1`
* - 1 [1]
  - RX_DATA_THLD_FORCE
  - R/W
  - 0x0
  - Forces the corresponding interrupt bit `TTI_RX_DATA_THLD_STAT` to be set to `1`
* - 1 [0]
  - TX_DATA_THLD_FORCE
  - R/W
  - 0x0
  - Forces the corresponding interrupt bit `TTI_TX_DATA_THLD_STAT` to be set to `1`
:::

##### TTI_RX_DESC_QUEUE_PORT Register

:::{list-table} *TTI_RX_DESC_QUEUE_PORT Register*
:name: tab-tti-rx-descriptor-queue-port-register
:widths: 10 30 13 9 38
* - **Size [bits]**
  - **Field Name**
  - **Memory Access**
  - **Reset Value**
  - **Description**
* - 32 [31:0]
  - RX_DESC
  - R
  - 0x0
  - RX Descriptor
:::

##### TTI_RX_DATA_PORT Register

:::{list-table} *TTI_RX_DATA_PORT Register*
:name: tab-tti-rx-data-port-register
:widths: 10 30 13 9 38
* - **Size [bits]**
  - **Field Name**
  - **Memory Access**
  - **Reset Value**
  - **Description**
* - 32 [31:0]
  - RX_DATA
  - R
  - 0x0
  - Data Read from the TTI RX Data Buffer
:::

##### TTI_TX_DESC_QUEUE_PORT Register

:::{list-table} *TTI_TX_DESC_QUEUE_PORT Register*
:name: tab-tti-tx-descriptor-queue-port-register
:widths: 10 30 13 9 38
* - **Size [bits]**
  - **Field Name**
  - **Memory Access**
  - **Reset Value**
  - **Description**
* - 32 [31:0]
  - TX_DESC
  - W
  - 0x0
  - TX Descriptor
:::

##### TTI_TX_DATA_PORT Register

:::{list-table} *TTI_TX_DATA_PORT Register*
:name: tab-tti-tx-data-port-register
:widths: 10 30 13 9 38
* - **Size [bits]**
  - **Field Name**
  - **Memory Access**
  - **Reset Value**
  - **Description**
* - 32 [31:0]
  - TX_DATA
  - W
  - 0x0
  - Data Write to the TTI TX Data Buffer
:::

##### TTI_QUEUE_SIZE Register

:::{list-table} *TTI_QUEUE_SIZE Register*
:name: tab-queue-size-register
:widths: 10 30 13 9 38
* - **Size [bits]**
  - **Field Name**
  - **Memory Access**
  - **Reset Value**
  - **Description**
* - 8 [31:24]
  - TX_DATA_BUFFER_SIZE
  - R
  - IMPL
  - Transmit Data Buffer Size in DWORDs:
    * 0x0: 2
    * 0x1: 4
    * 0x2: 8
    * 0x3: 16
    * 0x4: 32
    * 0x5: 64
    * 0x6: 128
    * 0x7: 256
    * 0x8-0xF:

      Reserved for future use
* - 8 [23:16]
  - RX_DATA_BUFFER_SIZE
  - R
  - IMPL
  - Receive Data Buffer Size in DWORDs:
    * 0x0: 2
    * 0x1: 4
    * 0x2: 8
    * 0x3: 16
    * 0x4: 32
    * 0x5: 64
    * 0x6: 128
    * 0x7: 256
    * 0x8-0xF:

      Reserved for future use
* - 8 [15:8]
  - TX_DESC_BUFFER_SIZE
  - R
  - IMPL
  - TX Descriptor Buffer Size in DWORDs:
    * 0x0: 2
    * 0x1: 4
    * 0x2: 8
    * 0x3: 16
    * 0x4: 32
    * 0x5: 64
    * 0x6: 128
    * 0x7: 256
    * 0x8-0xF:

      Reserved for future use
* - 8 [7:0]
  - RX_DESC_BUFFER_SIZE
  - R
  - IMPL
  - RX Descriptor Buffer Size in DWORDs:
    * 0x0: 2
    * 0x1: 4
    * 0x2: 8
    * 0x3: 16
    * 0x4: 32
    * 0x5: 64
    * 0x6: 128
    * 0x7: 256
    * 0x8-0xF:

      Reserved for future use
:::

##### TTI_IBI_QUEUE_SIZE Register

:::{list-table} *TTI_IBI_QUEUE_SIZE Register*
:name: tab-ibi-queue-size-register
:widths: 10 30 13 9 38
* - **Size [bits]**
  - **Field Name**
  - **Memory Access**
  - **Reset Value**
  - **Description**
* - 8 [7:0]
  - IBI_QUEUE_SIZE
  - R
  - IMPL
  - IBI Queue Size in DWORDs:
    * 0x0: 2 DWORDS
    * 0x1: 4 DWORDs
    * 0x2: 8 DWORDs
    * 0x3: 16 DWORDs
    * 0x4: 32 DWORDs
    * 0x5: 64 DWORDs
    * 0x6: 128 DWORDs
    * 0x7: 256 DWORDs
    * 0x8-0xF: Reserved for future use
:::

##### TTI_QUEUE_THLD_CONTROL Register

:::{list-table} *TTI_QUEUE_THLD_CONTROL Register*
:name: tab-tti-queue-threshold-control-register
:widths: 10 30 13 9 38
* - **Size [bits]**
  - **Field Name**
  - **Memory Access**
  - **Reset Value**
  - **Description**
* - 8 [31:24]
  - IBI_THLD
  - R/W
  - 0x1
  - Controls the minimum number of IBI Queue entries needed to trigger the IBI threshold interrupt.
* - 8 [23:16]
  - RESERVED
  -
  -
  -
* - 8 [15:8]
  - RX_DESC_THLD
  - R/W
  - 0x1
  - Controls the minimum number of TTI RX Descriptor Queue entries needed to trigger the TTI RX Descriptor interrupt.
* - 8 [7:0]
  - TX_DESC_THLD
  - R/W
  - 0x1
  - Controls the minimum number of empty TTI TX Descriptor Queue entries needed to trigger the TTI TX Descriptor interrupt.
:::

##### TTI_DATA_BUFFER_THLD_CONTROL Register

:::{list-table} *TTI_IBI_QUEUE_THLD_CONTROL Register*
:name: tab-tti-ibi-queue-threshold-control-register
:widths: 10 30 13 9 38
* - **Size [bits]**
  - **Field Name**
  - **Memory Access**
  - **Reset Value**
  - **Description**
* - 3 [26:24]
  - RX_START_THLD
  - R/W
  - 0x1
  - Minimum number of available TTI RX Data queue entries, in DWORDs, that will initiate the TTI RX Data transfer.
    Transfer starts when there are at least 2{sup}`N+1` RX Buffer DWORD entries available.
* - 3 [18:16]
  - TX_START_THLD
  - R/W
  - 0x1
  - Minimum number of TTI TX Data queue entries, in DWORDs, that will initiate the TTI TX transfer.
    Transfer starts when there are at least 2{sup}`N+1` TX Buffer DWORDs to be written.
* - 3 [10:8]
  - RX_DATA_THLD
  - R/W
  - 0x1
  - Minimum number of TTI RX Data queue entries of data received, in DWORDs, that will trigger the TTI RX Data interrupt.
    Interrupt triggers when 2{sup}`N+1` RX Buffer DWORD entries are received during the Read transfer.
* - 3 [2:0]
  - TX_DATA_THLD
  - R/W
  - 0x1
  - Minimum number of available TTI TX Data queue entries, in DWORDs, that will trigger the TTI TX Data interrupt.
    Interrupt triggers when 2{sup}`N+1` TX Buffer DWORD entries are available.
:::

#### Target Transaction Interface TX Descriptor

:::{list-table} *Target Transaction Interface TX Descriptor*
:name: tab-tti-target-transaction-interface-tx-descriptor
:widths: 10 30 13 9 38
* - **Size [bits]**
  - **Field Name**
  - **Memory Access**
  - **Reset Value**
  - **Description**
* - 16 [31:16]
  - TBD
  - TBD
  - TBD
  - TBD
:::

#### Target Transaction Interface RX Descriptor

:::{list-table} *Target Transaction Interface RX Descriptor*
:name: tab-tti-target-transaction-interface-rx-descriptor
:widths: 10 30 13 9 38
* - **Size [bits]**
  - **Field Name**
  - **Memory Access**
  - **Reset Value**
  - **Description**
* - 16 [31:16]
  - TBD
  - TBD
  - TBD
  - TBD
:::

#### TTI Queues

TTI TX Descriptor, TTI TX Data, TTI RX Descriptor, TTI RX Data and TTI IBI queues should be implemented as FIFO queues of 32 bit (1 DWORD) width.
Depth shall be parametrizable and register `TTI_QUEUE_SIZE`’s reset value should be set accordingly.
In order to prevent overflow/underrun scenarios, a programmable threshold signal is provided.
Software-issued reset of the queues contents is also possible.

#### Errors

1. [Generic Read] Device didn’t have data in time to respond to the controller
    1. Action taken by hardware
        1. NACK the next byte of data
        2. Report Error in the Error Register
        3. Raise `ERR_IRQ`
    2. Action taken by software
        1. Prepare an IBI with Pending Read Notification
        2. If MCTP, then use `5’h0E` Interrupt Identifier (Section 5.1.6.2.1, I3C Basic)
2. [Generic Write] Device was overrun
    1. Prevention mechanisms
        1. Active Controller should use `SETMWL`, `SETMRL` based on realistically set `GETMWL`, `GETMRL` values
    2. Action taken by hardware
        1. NACK the next byte of data
        2. Report Error in the Error Register
        3. Raise `ERR_IRQ`
    3. Action taken by software
        1. Prepare an IBI with Error Type Notification
            1. Can use `5’h0D` Interrupt Identifier (Section 5.1.6.2.1, I3C Basic)

## Ideas for the future (informative)

* Add Debug EC
* Virtual TTI
    * Consider reusing existing CSRs from Active Controller in this way?
* [MCTP Binding](https://www.dmtf.org/sites/default/files/standards/documents/DSP0233_1.0.0WIP.pdf)

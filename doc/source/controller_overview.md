# I3C Controller overview

## Architecture

The design is partitioned into two primary subsystems: the **Host Controller Interface (HCI)** and the **Host Controller (HC)**. These subsystems communicate via command/response queues and shared lookup tables (DAT/DCT).

### High-Level Block Diagram

:::{figure-md} fig-hc-top
![](img/hc_top_level_arch.png)

High-Level Block Diagram
:::


### Subsystems
* **HCI (Host Controller Interface):**
    * **Interface:** AXI/AHB (Slave interface).
    * **Function:** Handles communication with the Host CPU. It populates Control and Status Registers (CSRs) and transfers relevant information between the CSRs and the internal hardware queues (Command, Response, TX, RX, IBI).
* **HC (Host Controller):**
    * **Function:** Reads operational data from the queues and translates them into physical I3C transactions (driving SDA/SCL output signals).
    * **Components:** Consists of the `flow_active` module (protocol logic) and the low-level PHY FSMs (`i3c_controller_fsm` / `i2c_controller_fsm`).

### Data Flow
1.  **Command Generation:** Software writes commands to HCI CSRs.
2.  **Queue Population:** HCI logic pushes these commands into the Command Queue.
3.  **Execution:** HC fetches commands, consults the Device Address Table (DAT) or Device Characteristics Table (DCT), and executes the transaction on the bus.
4.  **Response:** Results are written back to the Response Queue for software to read.

---

## Microarchitecture

The Host Controller (HC) logic is split into a "decode" stage (Flow Active FSM) and "execute" stage (i3c/i2c controller FSM).

### `flow_active` (Decode FSM)
This module acts as a decoder. It consumes raw data from queues and converts it into atomic control signals (`fmt_*` signals) for the downstream controller FSMs.

* **Interfaces:**
    * **Upstream:** Read/Write access to HCI Queues (Cmd, Resp, Tx, Rx, IBI).
    * **Downstream:** `fmt` interface (`fmt_byte_o` + flags) to `i2c_controller_fsm` / `i3c_controller_fsm`.
* **Operating Principle:**
    * Operates in **PIO Mode** (Programmed I/O) using **SDR** (Standard Data Rate).
    * `fmt_byte_o` is the data, that will be sent on the I3C bus.
* **FSM States & Transitions:**
    1.  **Idle:** Waits for `i3c_fsm_en_i` signal indicating a new command is present in the Command Queue or IBI to wake up FSM.
    2.  **WaitForCmd:** Fetches the 64-bit Command Descriptor from the Command Queue.
    3.  **FetchDAT:** Retrieves the Device Address Table (DAT) entry corresponding to the command's Device Index. Transitions to the execution stage based on `cmd_attr` (Command Attribute).
    4.  **Execution:**
        * *I2C Write Immediate / I3C Write Immediate*
        * *Fetch TxData* (for regular writes): reads data from TX Queue
        * *Fetch RxData* (for regular reads): writes data into RX Queue
    5.  **WriteResp:** Generates a Response Descriptor, loads it into the Response Queue, and returns to **Idle**.

:::{figure-md} fig-flow-active-fsm
![](img/flow_active_fsm.png)

Flow Active FSM 
:::

### `i3c_controller_fsm` (Execute / Timing FSM)
This module functions as the main controller of the I3C bus, handling the serialization of data and precise bus timing.

* **Function:**
    * Consumes `fmt` signals (byte data + control flags like Start/Stop/Nak).
    * Drives physical **SDA** and **SCL** lines.
    * **Timing FSM:** Generates the SCL clock based on I3C SDR timing requirements.
    * **Serialization:** Serializes the `fmt_byte` onto the SDA line.
    * **Protocol Framing:** Reacts to `fmt_flag_start` and `fmt_flag_stop` to generate Start/Stop conditions.

---

## Features List (MVP)

The following features constitute the Minimum Viable Product (MVP) scope for the I3C Controller.

### Host Controller Interface (HCI)
* **Registers (RDL):** Full implementation of the Register Description List for configuration and status monitoring.
* **Queues:** Support for Command, Response, TX, RX, and IBI queues.
* **Tables:**
    * **DAT (Device Address Table):** Storage for Dynamic Addresses and device types.
    * **DCT (Device Characteristics Table):** Storage for device-specific parameters (PID, BCR, DCR).

### Controller Core Logic
* **SDA Arbitration Management:** Handling of bus arbitration during Start/Restart phases.
* **Frame Generation:**
    * **Read Frame:** Support for SDR Read transactions with and without `7'h7E` I3C address.
    * **Write Frame:** Support for SDR Write transactions with and without `7'h7E` I3C address.
* **IBI Handling:** Detection and processing of In-Band Interrupts from Targets.
* **HDR Pattern Generation:**
    * **HDR Exit Pattern:** Logic to generate the specific sequence to exit High Data Rate modes (ensuring bus reset/compatibility).
    * **HDR Restart Pattern:** Logic to generate the HDR Restart sequence.
* **Error Handling:** Target Error Detection and Escalation mechanisms.

### Common Command Codes (CCC)


The MVP includes support for the following subset of CCCs required for basic bus management and initialization.

#### Broadcast Support
* **ENEC:** Enable Events Command (Broadcast).
* **DISEC:** Disable Events Command (Broadcast).
* **RSTDAA:** Reset Dynamic Address Assignment (Broadcast).
* **ENTDAA:** Enter Dynamic Address Assignment (Broadcast).
* **SETAASA:** Set All Addresses to Static Address (Broadcast).

#### Direct Support
* **ENEC:** Enable Events Command (Direct).
* **DISEC:** Disable Events Command (Direct).
* **SETDASA:** Set Dynamic Address from Static Address (Direct).
* **SETNEWDA:** Set New Dynamic Address (Direct).
* **GETPID:** Get Provisional ID (Direct).
* **GETBCR:** Get Bus Characteristics Register (Direct).
* **GETDCR:** Get Device Characteristics Register (Direct).
* **GETSTATUS:** Get Device Status (Direct).

### Error Conditions

The MVP supports the following ERROR_STATUS conditions from Table 1 Error Status Codes in Response Descriptor I3C TCRI Spec.

:::{list-table} Error Status Codes
:name: error-status-codes
:widths: 15 10 10 20
:header-rows: 1

* - **Error Code**
  - **ERR_STATUS Value**
  - **I3C TCRI Spec Section**
  - **Notes**
* - CRC
  - 0x1
  - 6.4.1.1
  - 
* - PARITY
  - 0x2
  - 6.4.1.2
  - 
* - FRAME
  - 0x3
  - 6.4.1.3
  - 
* - ADDR_HEADER
  - 0x4
  - 6.4.1.4
  - 
* - NACK
  - 0x5
  - 6.4.1.5
  - 
* - OVL
  - 0x6
  - 6.4.1.6
  - 
* - I3C_SHORT_READ_ERR
  - 0x7
  - 6.4.1.7
  - 
* - HC_ABORTED
  - 0x8
  - 6.4.1.8
  - 
* - I2C_WR_DATA_NACK or BUS_ABORTED
  - 0x9
  - 6.4.1.9
  - 
* - NOT_SUPPORTED
  - 0xA
  - 6.4.1.10
  - 
* - ABORTED_WITH_CRC
  - 0xB
  - 6.4.1.11
  - This is used as an internal default state for errors. This means that internal hardware bugs can mistakenly produce the AbortedWithCRC error status.
* - Transfer Type Specific
  - 0xC – 0xF
  - 6.4.1.12
  - 
:::

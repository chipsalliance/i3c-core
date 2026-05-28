# Firmware Integration Guide

This chapter provides guidance for firmware developers integrating and configuring the I3C core.
It covers the bring-up sequence, register configuration requirements, known limitations,
and operational notes that firmware must account for.

## I3C Core Bring-Up Flow

The following sequence describes the recommended bring-up procedure for an integrator
initializing the I3C core in Standby Controller (Target) mode.
This mirrors the boot sequence exercised in the verification environment.

### Step 1: Discover Extended Capabilities

Read `EXT_CAPS_SECTION_OFFSET` to obtain the base of the Extended Capabilities linked list.
Walk the list by reading `EXTCAP_HEADER` at each offset; the `CAP_ID` field identifies the
capability and `CAP_LENGTH` gives the offset to the next entry.

Expected capability IDs (in discovery order):

| CAP_ID | Extended Capability |
|--------|---------------------|
| 0xC0   | Secure Firmware Recovery Interface |
| 0x12   | Standby Controller Mode |
| 0xC4   | Target Transaction Interface (TTI) |
| 0xC1   | SoC Management Interface |
| 0x02   | Controller Config |

### Step 2: Configure Bus Condition Timers

These timers define the time from a STOP condition until the corresponding bus condition
is declared. All values are in clock cycles. Configure based on system clock frequency.

| Register | Bus Condition | Typical Duration | Formula |
|----------|---------------|------------------|---------|
| `T_FREE_REG` | Bus Free (tBUF/tCAS) | 38.4 ns (pure I3C bus) | `ceil(fclk_MHz * 38.4 / 1000)` |
| `T_AVAL_REG` | Bus Available (tAVAL) | 1 us | `fclk_MHz` |
| `T_IDLE_REG` | Bus Idle (tIDLE) | 200 us | `fclk_MHz * 200` |

```{note}
The tAVAL timer starts at STOP detection. Per I3C spec v1.1.1 Section 5.1.3.2.2,
the Bus Available Condition is defined as a period during which the Bus Free Condition
is sustained continuously for at least tAVAL. Firmware may take tBUF into account
when programming T_AVAL_REG if needed.
```

### Step 3: Configure HDR Error Recovery Timer (Optional)

The optional 60 us HDR error recovery timer (per I3C spec Section 5.1.10.1.9) allows
the Target to recover from TE0/TE1 errors if both SCL and SDA remain high for a
configurable period.

| Register | Description |
|----------|-------------|
| `T_HDR_TIMEOUT_REG` | Threshold in clock cycles (default: `fclk_MHz * 60`) |
| `HDR_TIMEOUT_EN_REG` | Set bit 0 to enable the timer |

When enabled and a TE0 or TE1 error has placed the Target into HDR mode, the timer
counts cycles where both SCL and SDA are stable high. Once the threshold is reached,
the Target exits HDR mode and returns to Idle.

### Step 4: Configure Standby Controller Mode

Write `STBY_CR_CONTROL.STBY_CR_ENABLE_INIT = 2` to boot in Standby Controller mode.

### Step 5: Set Target Addresses

Configure static for both the main and virtual (recovery) targets:

```
STBY_CR_DEVICE_ADDR.STATIC_ADDR       = <main_static_addr>
STBY_CR_DEVICE_ADDR.STATIC_ADDR_VALID = 1
STBY_CR_VIRT_DEVICE_ADDR.VIRT_STATIC_ADDR       = <virtual_static_addr>
STBY_CR_VIRT_DEVICE_ADDR.VIRT_STATIC_ADDR_VALID = 1
```

Dynamic addresses may also be pre-set at boot time for debug or test purposes:

```
STBY_CR_DEVICE_ADDR.DYNAMIC_ADDR       = <main_dyn_addr>
STBY_CR_DEVICE_ADDR.DYNAMIC_ADDR_VALID = 1
STBY_CR_VIRT_DEVICE_ADDR.DYNAMIC_ADDR       = <virtual_dyn_addr>
STBY_CR_VIRT_DEVICE_ADDR.DYNAMIC_ADDR_VALID = 1
```

In production flows the Dynamic Address is normally assigned by the Controller
via SETDASA, SETNEWDA, SETAASA or ENTDAA CCCs; pre-setting it at boot is primarily
useful during board bring-up and lab debug.

```{note}
If ENTDAA is used for dynamic address assignment, the Provisioned ID (PID)
registers must be configured first (see [Step 7](#step-7-configure-pid-registers)).
The Controller reads the PID during the ENTDAA procedure to identify each Target.
```

### Step 6: Configure BCR and DCR

Write the Bus Characteristics Register (BCR) variable bits and Device Characteristics
Register (DCR) in the `STBY_CR_DEVICE_CHAR` and `STBY_CR_VIRTUAL_DEVICE_CHAR` registers.

**Main Target BCR Requirements:**

| BCR Bit | Value | Meaning |
|---------|-------|---------|
| [4] | 1 | Exposes a Virtual Target |
| [3] | 0 | Not Offline Capable |
| [2] | 1 | Always uses MDB in IBI Payload |
| [1] | 1 | Capable of IBI requests |
| [0] | 0 | No speed limitation |

The RDL reset default for the main target `BCR_VAR` is `5'b10110`, which matches these
requirements.

**Virtual Target BCR Requirements:**

| BCR Bit | Value | Meaning |
|---------|-------|---------|
| [4] | 1 | Is a Virtual Target |
| [3] | 0 | Not Offline Capable |
| [2] | 0 | Does not apply (bit 1 is 0) |
| [1] | 0 | Not capable of IBI requests |
| [0] | 0 | No speed limitation |

The RDL reset default for the virtual target `BCR_VAR` is `5'b10000`, which matches
these requirements.

```{warning}
Although the virtual target `BCR_VAR` register is read-write, firmware must not
set bit [1] (IBI capable). The virtual target does not support IBI and
programming it as IBI-capable will indicate to the Controller invalid target capabilities.
```

### Step 7: Configure PID Registers

Write the Provisioned ID for main and virtual targets in the `STBY_CR_DEVICE_PID_HI`
/ `STBY_CR_DEVICE_PID_LO` and `STBY_CR_VIRTUAL_DEVICE_PID_HI` /
`STBY_CR_VIRTUAL_DEVICE_PID_LO` registers.

The PID is a 48-bit identifier composed of a MIPI manufacturer ID and a vendor-specific
part number. See the I3C specification (Section 5.1.4.1.1) for the PID format and
assignment rules.

### Step 8: Configure TTI Thresholds and Interrupts

Configure queue thresholds and enable desired interrupts in the TTI registers
**before** enabling the bus:

- `TTI.QUEUE_THLD_CTRL` -- Set RX descriptor and data thresholds
- `TTI.INTERRUPT_ENABLE` -- Enable desired TTI interrupts
- `TTI.TARGET_ERR_INTR_ENABLE` -- Enable desired error interrupts (TE0-TE5, Framing, RI errors)

### Step 9: Enable the Bus

```
HC_CONTROL.BUS_ENABLE = 1
```

Setting `BUS_ENABLE` enables the I3C bus monitor. When cleared, the PHY input pins are
internally forced high, preventing START/STOP detection and any bus activity recognition.

```{note}
`BUS_ENABLE` only gates the bus monitor. It does **not** prevent firmware from writing
to the TX or IBI FIFOs. It is firmware's responsibility to refrain from queuing I3C
data (IBI or TX) until the bus is enabled and the Target has been addressed by the
Controller.
```

---

## PIOControl Registers -- Do Not Access

```{warning}
The PIOControl register block is unverified and
shall not be accessed by firmware. Accessing these registers may hang the AXI bus.
```

---

## In-Band Interrupt (IBI) Configuration

### IBI Enable and Retry

IBIs are controlled through `TTI.CONTROL`:

- `IBI_EN` (bit 12): Set to 1 to allow the Target to service the IBI queue.
  Reset default is 1 (enabled).
- `IBI_RETRY_NUM` (bits 15:13): Number of retry attempts before giving up:
  - `0x0`: Never retry (give up after first NACK)
  - `0x1`-`0x6`: Retry this many times
  - `0x7`: Retry indefinitely until the Controller sends DISEC

The IBI retry counter can be reset via `TTI.RESET_CONTROL.IBI_RETRY_CTR_RST`.

### IBI Payload Length

Firmware SHALL always set IBI length > 0. Every IBI transmission includes
a Mandatory Data Byte (MDB) followed by optional additional data bytes.

### IBI Status Codes

After each IBI attempt, `TTI.STATUS.LAST_IBI_STATUS` (bits 14:12) is updated:

| Code | Name | Description |
|------|------|-------------|
| 000 | Success | IBI was transmitted and ACK'd by the Controller |
| 001 | FailureNack | Controller NACK'd the IBI before data was sent; device will retry |
| 010 | FailurePartialData | Controller NACK'd after partial data; remaining IBI queue data is discarded |
| 011 | FailureRetry | IBI could not be serviced due to retry count exhaustion |
| 100 | FailureArbitration | IBI lost address arbitration; device will retry |

```{note}
`LAST_IBI_STATUS` is not queued. It reflects only the most recent IBI outcome.
If multiple IBIs complete before firmware reads the field, only the last status
is visible. Firmware should read this field promptly after receiving an
`IBI_DONE` interrupt.
```

### IBI Queue Reset

`TTI.RESET_CONTROL.IBI_QUEUE_RST` empties the IBI FIFO and resets the internal IBI
descriptor state machine (`descriptor_ibi`) back to Idle. Any in-progress IBI
descriptor is discarded.

### IBI Failure Handling Examples

**Example 1 -- Clear stale data and re-queue after FailureRetry:**
1. Write `IBI_QUEUE_RST` to clear stale FIFO data and reset the descriptor FSM
2. Write `IBI_RETRY_CTR_RST` to reset the retry counter
3. Re-queue IBI descriptor and data before enabling the next IBI attempt

**Example 2 -- Reset retry counter only (keep queued data):**
1. Write `IBI_RETRY_CTR_RST` to reset the retry counter
2. The previously queued IBI data remains in the FIFO and will be retried

---

## Address Behavior and Priority

### Dynamic vs Static Address Priority

Per the I3C specification, once a Target has been assigned a Dynamic Address, it stops
responding to its Static Address. The address matching logic implements this as:

- If `DYNAMIC_ADDR_VALID = 1`, the Target matches only on `DYNAMIC_ADDR`
- If `DYNAMIC_ADDR_VALID = 0` and `STATIC_ADDR_VALID = 1`, the Target matches on `STATIC_ADDR`

This applies independently to both the main target and the virtual target.

### IBI Address

The IBI address is derived from the main target's active address:

- If `DYNAMIC_ADDR_VALID = 1`, the IBI address is `DYNAMIC_ADDR`
- Otherwise, the IBI address is `STATIC_ADDR`

IBI transmission is gated on the address being valid (either static or dynamic).
This is the same address used for Private Read/Write matching; there is no separate
IBI-specific address register.

### Virtual Target Address

The virtual target has its own independent static/dynamic address pair
(`VIRT_STATIC_ADDR`, `VIRT_DYNAMIC_ADDR`) with the same priority rules.
Both the main and virtual target addresses are checked in parallel for every
incoming transaction; when the virtual target address matches, the `virtual_device_sel`
signal is asserted, routing the transaction to the recovery handler data path.

---

## RESET_CONTROL Register Limitations

### TX_DATA_RST

Writing `TX_DATA_RST` resets both the TTI TX Data Queue and the internal `tti_conv_Nto8`
width converter. This is necessary because the first DWORD is immediately loaded into the
converter upon write and cannot be cleared from the queue alone.

### IBI_QUEUE_RST

`IBI_QUEUE_RST` empties the IBI FIFO and resets the internal IBI descriptor state machine.
See [IBI Queue Reset](#ibi-queue-reset) above.

### General Notes

Queue resets should not be performed while a transfer is in flight on the I3C bus.
The hardware does not gate resets on transfer state; resetting a queue mid-transfer
may leave the bus-side FSM in an inconsistent state.

---

## Max Read/Write Length (MRL/MWL)

The `SETMRL` and `SETMWL` CCCs (both Broadcast and Direct) update the
`STBY_CR_MRL` and `STBY_CR_MWL` registers respectively. These register values
are **not enforced in hardware**. The design does not impose any maximum on the
number of bytes that can be read or written in a single Private transfer.

It is the responsibility of firmware to:
1. Read `STBY_CR_MRL` / `STBY_CR_MWL` to determine the current limits
2. Ensure that TX descriptors and data queued for Private Reads do not exceed MRL
3. Be prepared to handle Private Writes up to MWL bytes

```{note}
The Controller may update MRL/MWL at any time via CCC without notifying the Target
firmware through an interrupt. Firmware should poll these registers if it needs
current values.
```

---

## Private Writes During Recovery Flows

During an active recovery flow, private writes to the main target address MUST NOT
occur. The RX data FIFO is shared between the main target's Private Write path and
the recovery handler. If a private write to the main target were to arrive during
recovery, data would enter the RX FIFO and corrupt the recovery data stream.

When the virtual target address is matched (i.e. a recovery transaction is active),
the `virtual_device_sel` signal gates TTI interrupts. This means the standard RX
descriptor and data threshold interrupts are masked, so firmware is not incorrectly
alerted to recovery data appearing in the RX path.

---

## Transmit FIFO Behavior on Controller Early Termination

When the Controller terminates a Private Read early (before the Target has sent all
queued data), the Target FSM handles this as follows:

1. After transmitting a non-last data byte, the Target enters the `TxPReadTbitCont`
   state where it drives the T-bit high (indicating more data) and simultaneously
   prepares the next byte. Before the following SCL falling edge, the Controller
   may pull SDA low to signal a Repeated Start, aborting the read.
2. If the abort is detected (`bus_tx_rsp_i.abort`), the Target asserts `tx_pr_abort`
   and transitions to receive the next address byte.
3. The `descriptor_tx` module clears the current TX descriptor and flushes the
   remaining data bytes for that descriptor from the TX data FIFO.

**Known Limitation**: The `TTI.INTERRUPT_STATUS.TRANSFER_ABORT_STAT` interrupt is
defined in the register map but is **not yet implemented** (hardwired to 0).
Firmware currently has no register-level notification that a Private Read was
terminated early by the Controller. This is marked as a future enhancement in RTL.

---

## Unanticipated Private Reads

If the Controller initiates a Private Read to the Target's address but no TX descriptor
is available (i.e., firmware has not queued data for transmission), the Target NACKs
the transaction.

**Known Limitation**: There is currently no status flag or interrupt to notify firmware
that an unanticipated Private Read was attempted and rejected. Firmware has no way to
distinguish between "no read was attempted" and "a read was attempted but NACKed due
to empty TX queue."

---

## Registers Updated by CCC Without Firmware Notification

The following registers are updated autonomously by the hardware in response to CCC
commands. No interrupt is generated to notify firmware of the change:

| CCC | Register Updated | Notes |
|-----|-----------------|-------|
| SETDASA | `STBY_CR_DEVICE_ADDR.DYNAMIC_ADDR` / `DYNAMIC_ADDR_VALID` | Sets dynamic address (main or virtual) |
| SETNEWDA | `STBY_CR_DEVICE_ADDR.DYNAMIC_ADDR` / `DYNAMIC_ADDR_VALID` | Assigns a new dynamic address (main or virtual) |
| SETAASA | `STBY_CR_DEVICE_ADDR.DYNAMIC_ADDR` / `DYNAMIC_ADDR_VALID` | Copies static address to dynamic address (main and/or virtual) |
| RSTDAA | `STBY_CR_DEVICE_ADDR.DYNAMIC_ADDR` / `DYNAMIC_ADDR_VALID` | Clears dynamic address and valid bit (main and virtual) |
| SETMRL (Broadcast/Direct) | `STBY_CR_MRL.MRL` | Max Read Length |
| SETMRL (with IBI length) | `STBY_CR_MRL.IBIL` | IBI data length |
| SETMWL (Broadcast/Direct) | `STBY_CR_MWL.MWL` | Max Write Length |
| RSTACT | `STBY_CR_CCC_CONFIG_RSTACT_PARAMS.RST_ACTION` | Reset action level (defaults to 0x1 when no RSTACT is active) |
| ENEC | `TTI.CONTROL.IBI_EN`, `CRR_EN`, `HJ_EN` | Enables the corresponding event |
| DISEC | `TTI.CONTROL.IBI_EN`, `CRR_EN`, `HJ_EN` | Disables the corresponding event |

Firmware should poll these registers when current values are needed.

---

## Routing Requirements

The main target and virtual target share the same I3C bus interface and physical layer.
Address routing works as follows:

- Both addresses are checked in parallel on every incoming transaction
- The first byte (address + RnW) determines which target is being addressed
- The `virtual_device_sel` signal routes the data path to the recovery handler
- When the virtual target is selected, TTI queue interrupts are gated
- Both targets must be configured with distinct addresses; overlapping addresses
  result in undefined behavior

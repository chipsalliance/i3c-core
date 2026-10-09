# I3C Common Command Codes (CCC)

The I3C core supports all CCCs required by the I3C Basic spec, please see "Table 16 I3C Common Command Codes" for a full reference.

All CCCs are exercised with Cocotb tests.

## Broadcast CCCs

The following Broadcast CCCs are currently supported by the core (all required Broadcast CCCs as per the errata, and one optional Broadcast CCC):

* ENEC (R) - Enable Events Command
* DISEC (R) - Disable Events Command
* SETMWL (R) - Set Max Write Length
* SETMRL (R) - Set Max Read Length
* SETAASA (O) - Set All Addresses to Static Addresses
* ENTDAA (R) - Enter Dynamic Address Assignment
* RSTDAA (R) - Reset Dynamic Address Assignment
* RSTACT (R) - Target Reset Action
  * Broadcast (Format 1) supports defining bytes 0x0, 0x1 and 0x2
  * The core arms the action after an error free defining-byte T bit.

The following Broadcast CCCs are recognized but not actively handled. The core
ACKs 0x7E/W, then ignores the following commands until STOP or repeated START:

* ENTAS0-ENTAS3 - Enter Activity State (acknowledged, no behavioral change)
* ENTHDR0-ENTHDR7 - Enter HDR Mode (triggers HDR mode entry; HDR data transfer is not supported)
* ENDXFER - Data Transfer Ending Procedure Control
* SETBUSCON - Set Bus Context
* DEFGRPA / RSTGRPA - Group Address (ignored)
* MLANE - Multi-Lane (ignored)

## Direct CCCs

The following Direct CCCs are currently supported by the core (all required Direct CCCs, plus several optional/conditional ones):

* ENEC (R) - Enable Events Command
* DISEC (R) - Disable Events Command
* SETDASA (O) - Set Dynamic Address from Static Address
  * Primary (Format 1)
* SETNEWDA (C) - Set New Dynamic Address
* SETMWL (R) - Set Max Write Length
* SETMRL (R) - Set Max Read Length
* GETMWL (R) - Get Max Write Length
* GETMRL (R) - Get Max Read Length
* GETPID (C) - Get Provisioned ID
* GETBCR (C) - Get Bus Characteristics Register
* GETDCR (C) - Get Device Characteristics Register
* GETSTATUS (R) - Get Device Status
  * The two-byte format (Format 1)
  * Format 2 requests with any defining byte, including 0x00 (TGTSTAT), are NACKed at the target address without clearing Protocol Error or raising TE5.
* GETCAPS (R) - Get Optional Feature Capabilities
  * Without defining byte (Format 1)
  * With defining byte 0x93
* RSTACT (R) - Target Reset Action
  * Direct Write (Format 2) supports defining bytes 0x0, 0x1, 0x2 and VT identification 0x4
  * Direct Read (Format 3) supports defining bytes 0x00-0x02 for action queries, 0x04 for the VT flag, 0x81/0x82 for recovery timing (0xFF), and 0x84 for VT support (0x01)


## CCCs That Update Registers Without Firmware Notification

The following CCCs autonomously update internal registers without generating an
interrupt to notify firmware. Firmware should poll these registers if current
values are needed:

| CCC | Register Updated | Notes |
|-----|-----------------|-------|
| SETDASA | `STBY_CR_DEVICE_ADDR.DYNAMIC_ADDR` / `DYNAMIC_ADDR_VALID` | Sets dynamic address (main or virtual) |
| SETNEWDA | `STBY_CR_DEVICE_ADDR.DYNAMIC_ADDR` / `DYNAMIC_ADDR_VALID` | Assigns a new dynamic address (main or virtual) |
| SETAASA | `STBY_CR_DEVICE_ADDR.DYNAMIC_ADDR` / `DYNAMIC_ADDR_VALID` | Copies static address to dynamic address (main and/or virtual) |
| RSTDAA | `STBY_CR_DEVICE_ADDR.DYNAMIC_ADDR` / `DYNAMIC_ADDR_VALID` | Clears dynamic address and valid bit (main and virtual) |
| SETMRL (Broadcast/Direct) | `STBY_CR_MRL.MRL` | Max Read Length; not enforced in hardware |
| SETMRL (with IBI length) | `STBY_CR_MRL.IBIL` | IBI data length |
| SETMWL (Broadcast/Direct) | `STBY_CR_MWL.MWL` | Max Write Length; not enforced in hardware |
| RSTACT | `STBY_CR_CCC_CONFIG_RSTACT_PARAMS.RST_ACTION` | Reset action level (defaults to 0x1 when no RSTACT is active) |
| ENEC | `TTI.CONTROL.IBI_EN`, `CRR_EN`, `HJ_EN` | Enables the corresponding event |
| DISEC | `TTI.CONTROL.IBI_EN`, `CRR_EN`, `HJ_EN` | Disables the corresponding event |

```{note}
MRL and MWL values are informational only. The hardware does not enforce these
limits on Private Read or Private Write transfers. See {doc}`firmware_guide` for
details on firmware responsibilities.
```

## Multi-Byte CCC Register Atomicity

Several Direct GET CCCs return multi-byte values. The CCC state machine
transmits these byte-by-byte, selecting each byte from the source signal
combinationally as it is needed. There is no snapshot or shadow register;
the source is re-read on every byte. If the underlying CSR is modified
mid-transfer, remaining bytes will reflect the new value while
already-transmitted bytes retain the old value.

| CCC | Bytes | Source | Updated By |
|-----|-------|--------|------------|
| GETBCR | 1 | `STBY_CR_DEVICE_CHAR.BCR_*` | FW |
| GETDCR | 1 | `STBY_CR_DEVICE_CHAR.DCR` | FW |
| GETSTATUS | 2 | `TTI.INTERRUPT_STATUS`, `TTI.STATUS` | HW |
| GETMWL | 2 | Internal flop | SETMWL CCC |
| GETMRL | 2 or 3, per sampled BCR[2] | Internal flop | SETMRL CCC |
| GETPID | 6 | `STBY_CR_DEVICE_CHAR.PID_HI` + `STBY_CR_DEVICE_PID_LO.PID_LO` | FW |

**GETPID**: The 48-bit PID is assembled combinationally from two CSR
registers (`STBY_CR_DEVICE_CHAR` and `STBY_CR_DEVICE_PID_LO`). If firmware
writes either register while a GETPID CCC is in progress, the byte being
transmitted in that cycle and all subsequent bytes will use the new register
value. Firmware should write both PID registers before the Target receives
a dynamic address (before ENTDAA / SETDASA / SETAASA), since GETPID is
only issued after address assignment.

**GETMWL / GETMRL**: These read internal flops that are only written by the
SETMWL / SETMRL CCC handler. Since only one CCC can be active on the bus at
a time, GET and SET cannot overlap. These registers are read-only to firmware
(`sw = r`).

**SETMRL / GETMRL length**: Firmware controls BCR[2] through bit 2 of
`STBY_CR_DEVICE_CHAR.BCR_VAR` or `STBY_CR_VIRTUAL_DEVICE_CHAR.BCR_VAR`.
Direct commands sample the addressed target's bit at its ACK; broadcast SETMRL
samples the OR of both bits at the command T-bit. The handler uses two bytes
when clear and three when set. Later firmware changes affect the next message,
not the current one. Two-byte SETMRL preserves the shared IBIL value; extra bytes
are ignored. The virtual target's third GETMRL byte remains zero.

For SET CCCs, **SETMRL** commits MRL (bytes 0-1) and optional IBIL (byte 2) to
`STBY_CR_MRL` on separate clock cycles. A firmware read of `STBY_CR_MRL`
between those two updates sees the new MRL with the stale IBIL. **SETMWL**
commits both MWL bytes to `STBY_CR_MWL` in a single cycle.

## CCC Error Handling

The core detects errors during CCC processing:

* **TE1**: CCC command code parity error
* **TE2**: CCC defining-byte or data parity error
* **TE5**: Wrong R/W direction for a Direct CCC (e.g., SET command with Read)
  * Correct-direction SETDASA requests to an already-addressed target are NACKed without reporting TE5.
* **Framing Error**: SETDASA/SETNEWDA padding bit error (Bit[0] != 0)

These errors are reported through the `TTI.TARGET_ERR_INTR_STATUS` register.
TE1, TE2, and framing errors also set `TTI.STATUS.PROTOCOL_ERROR`; TE5 does not.
GETSTATUS clears Protocol Error on successful final-T-bit completion, without
waiting for STOP or another CCC. An aborted read leaves it set.

With `TTI.TARGET_ERR_CTRL.TE2_ERR_DET_EN` set, a detected CCC data parity error
halts processing until STOP. Incomplete fields also require STOP recovery;
premature repeated START recovery is not implemented. CCC errors do not mark
later private-write RX descriptors, whose errors come from private-write parity
or RX overflow.

See {doc}`error_handling` for full details.

# Error Detection and Recovery

This chapter describes the error detection registers, interrupt wiring, error
counters, and recovery mechanisms implemented in the I3C core.

For definitions of the Target Error types (TE0-TE5), refer to the I3C Basic
specification v1.1.1, Sections 5.1.10.1 through 5.1.10.6.

## Error Signal Path

Each error is detected in the RTL control logic and routed to the TTI as a
single-cycle pulse. The TTI contains per-error interrupt logic and an 8-bit
saturating counter. The flow is:

```
Detection (ctrl/) --> pulse --> TTI interrupt_ctl --> STATUS bit + IRQ
                           \-> TTI counter       --> 8-bit saturating count
```

## Error Detection Sources

The following table shows where each error originates in the RTL and what
detection enable register bit gates it:

| Error | RTL Source Module | Detection Enable CSR |
|-------|-------------------|----------------------|
| TE0 | `i3c_target_fsm.sv` (address match logic) | `TARGET_ERR_CTRL.TE0_ERR_DET_EN` |
| TE1 | `ccc.sv` (CCC command parity check) | `TARGET_ERR_CTRL.TE1_ERR_DET_EN` |
| TE2 | `ccc.sv` (CCC data parity) + `i3c_target_fsm.sv` (Private Write parity) | `TARGET_ERR_CTRL.TE2_ERR_DET_EN` |
| TE3 | `ccc_entdaa.sv` (PID mismatch during ENTDAA) | `TARGET_ERR_CTRL.TE3_ERR_DET_EN` |
| TE4 | `ccc_entdaa.sv` (invalid reserved byte during ENTDAA) | `TARGET_ERR_CTRL.TE4_ERR_DET_EN` |
| TE5 | `ccc.sv` (wrong R/W direction for Direct CCC) | `TARGET_ERR_CTRL.TE5_ERR_DET_EN` |
| Framing | `ccc.sv` (SETDASA/SETNEWDA padding bit error) | `TARGET_ERR_CTRL.FRAMING_ERR_DET_EN` |
| RI PEC | `recovery_handler.sv` (PEC/CRC mismatch) | `TARGET_ERR_CTRL.RI_PEC_ERR_DET_EN` |
| RI Length | `recovery_handler.sv` (payload length mismatch) | `TARGET_ERR_CTRL.RI_LENGTH_ERR_DET_EN` |
| RI Read-Only | `recovery_handler.sv` (write to read-only register) | `TARGET_ERR_CTRL.RI_READONLY_ERR_DET_EN` |
| RI Unsupported | `recovery_handler.sv` (unsupported command code) | `TARGET_ERR_CTRL.RI_UNSUPPORTED_ERR_DET_EN` |
| RI RX FIFO Overflow | `recovery_handler.sv` (RX FIFO overflow) | `TARGET_ERR_CTRL.RI_RX_FIFO_OVERFLOW_ERR_DET_EN` |
| RI Indirect FIFO Overflow | `recovery_handler.sv` (Indirect FIFO overflow) | `TARGET_ERR_CTRL.RI_INDIRECT_FIFO_OVERFLOW_ERR_DET_EN` |

All detection enable bits reset to 1 (enabled). FW may clear individual bits to
suppress detection for debug purposes.

## Interrupt Registers

Each error has a corresponding bit in three TTI registers. All share the same
bit positions:

| Bit | Error | Status Field | Enable Field | Force Field |
|-----|-------|-------------|--------------|-------------|
| 1 | TE0 | `TE0_ERR_STAT` | `TE0_ERR_EN` | `TE0_ERR_FORCE` |
| 2 | TE1 | `TE1_ERR_STAT` | `TE1_ERR_EN` | `TE1_ERR_FORCE` |
| 3 | TE2 | `TE2_ERR_STAT` | `TE2_ERR_EN` | `TE2_ERR_FORCE` |
| 4 | TE3 | `TE3_ERR_STAT` | `TE3_ERR_EN` | `TE3_ERR_FORCE` |
| 5 | TE4 | `TE4_ERR_STAT` | `TE4_ERR_EN` | `TE4_ERR_FORCE` |
| 6 | TE5 | `TE5_ERR_STAT` | `TE5_ERR_EN` | `TE5_ERR_FORCE` |
| 7 | Framing | `FRAMING_ERR_STAT` | `FRAMING_ERR_EN` | `FRAMING_ERR_FORCE` |
| 8 | RI PEC | `RI_PEC_ERR_STAT` | `RI_PEC_ERR_EN` | `RI_PEC_ERR_FORCE` |
| 9 | RI Length | `RI_LENGTH_ERR_STAT` | `RI_LENGTH_ERR_EN` | `RI_LENGTH_ERR_FORCE` |
| 10 | RI Read-Only | `RI_READONLY_ERR_STAT` | `RI_READONLY_ERR_EN` | `RI_READONLY_ERR_FORCE` |
| 11 | RI Unsupported | `RI_UNSUPPORTED_ERR_STAT` | `RI_UNSUPPORTED_ERR_EN` | `RI_UNSUPPORTED_ERR_FORCE` |
| 12 | RI RX Overflow | `RI_RX_FIFO_OVERFLOW_ERR_STAT` | `RI_RX_FIFO_OVERFLOW_ERR_EN` | `RI_RX_FIFO_OVERFLOW_ERR_FORCE` |
| 13 | RI Indirect Overflow | `RI_INDIRECT_FIFO_OVERFLOW_ERR_STAT` | `RI_INDIRECT_FIFO_OVERFLOW_ERR_EN` | `RI_INDIRECT_FIFO_OVERFLOW_ERR_FORCE` |

**Register behavior:**

- **`TARGET_ERR_INTR_STATUS`**: Read to see pending errors. Write-1-to-clear.
- **`TARGET_ERR_INTR_ENABLE`**: Set bits to allow the corresponding error to
  propagate to the aggregated `irq_o` output. The status bit is set regardless
  of the enable; the enable only gates the IRQ line.
- **`TARGET_ERR_INTR_FORCE`**: Set bits to force the corresponding status bit
  high (for testing). Auto-clears.

All error interrupts are OR'd together with the TTI queue interrupts into a
single `irq_o` output (`assign irq_o = |irqs`).

## Error Counters

Each error type has an 8-bit saturating counter. Counters increment on every
error pulse (per-byte, not per-transfer) and saturate at 0xFF.

| Counter Register | Error |
|-----------------|-------|
| `TARGET_ERR_CNT_TE0.CNT` | TE0 |
| `TARGET_ERR_CNT_TE1.CNT` | TE1 |
| `TARGET_ERR_CNT_TE2.CNT` | TE2 |
| `TARGET_ERR_CNT_TE3.CNT` | TE3 |
| `TARGET_ERR_CNT_TE4.CNT` | TE4 |
| `TARGET_ERR_CNT_TE5.CNT` | TE5 |
| `TARGET_ERR_CNT_FRAMING.CNT` | Framing |
| `TARGET_ERR_CNT_RI_PEC.CNT` | RI PEC |
| `TARGET_ERR_CNT_RI_LENGTH.CNT` | RI Length |
| `TARGET_ERR_CNT_RI_READONLY.CNT` | RI Read-Only |
| `TARGET_ERR_CNT_RI_UNSUPPORTED.CNT` | RI Unsupported |
| `TARGET_ERR_CNT_RI_RX_FIFO_OVERFLOW.CNT` | RI RX Overflow |
| `TARGET_ERR_CNT_RI_INDIRECT_FIFO_OVERFLOW.CNT` | RI Indirect Overflow |

Counters are RW. Write any value to set the counter (write 0 to clear).
Counters increment independently of the detection enable and interrupt enable
bits -- if the error pulse fires, the counter increments.

---

## Error Recovery Mechanisms

### HDR Exit Pattern Detection

Per I3C spec Section 5.2.1.1.1. The implementation uses a shift register that
counts SDA falling edges while SCL is held low. After 4 edges, the HDR Exit
Pattern is detected and the Target exits HDR mode.

### HDR Error Recovery Timeout

Per I3C spec Section 5.1.10.1.9. When enabled via `HDR_TIMEOUT_EN_REG = 1`,
the Target counts cycles where both SCL and SDA are stable high while in HDR
error mode (entered due to TE0 or TE1). When the count reaches
`T_HDR_TIMEOUT_REG`, the Target exits HDR mode. See {doc}`firmware_guide`
Step 4 for configuration.

### Target Reset Pattern Detection

The `target_reset_detector` module monitors the bus for the Target Reset
Pattern and asserts `target_reset_detect_o` when detected.

---

## Protocol Error Reporting (GETSTATUS)

`TTI.STATUS.PROTOCOL_ERROR` (bit 8) is set when any of the following occur:
- TE1 (CCC command parity error)
- TE2 (CCC or Private Write data parity error)
- Framing error (SETDASA/SETNEWDA padding bit)

This bit is readable by the Controller via the GETSTATUS CCC (Format 1).
It is sticky and remains set until cleared.

---

## Queue Status Registers

For debug and monitoring, the TTI provides real-time queue status:

| Register | Fields | Description |
|----------|--------|-------------|
| `QUEUE_STATUS` | Bits [9:0] | Full/empty flags for RX desc, TX desc, RX data, TX data, IBI queues |
| `DESC_QUEUE_DEPTH` | `RX[7:0]`, `TX[15:8]` | Current descriptor queue fill levels |
| `DATA_QUEUE_DEPTH` | `RX[7:0]`, `TX[15:8]` | Current data queue fill levels (DWORDs) |
| `IBI_QUEUE_DEPTH` | `[7:0]` | Current IBI queue fill level |

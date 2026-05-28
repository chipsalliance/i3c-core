# Target

## Testpoints

### `i3c_target_write`

Test: [i3c_target_write](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_i3c_target.py)

Spawns a TTI agent that reads from TTI descriptor and data queues
and stores received data.

While the agent is running the test issues several private writes
over I3C. Data sent over I3C is compared with data received by
the agent.

The test runs at core clock of 100 and 200 MHz. The slowest clock that does not result in a tSCO violation is 166 MHz.
The I3C bus clock is set to 12.5 MHz.

### `i3c_target_write_long`

Tests:
- [i3c_target_write_255](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_i3c_target.py)- [i3c_target_write_256](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_i3c_target.py)

Verifies the handling of long private writes (255 and 256 bytes)
that are not issued in any other test, in order to cover upper
bits of transaction length signals in the design.

Uses the same flow as i3c_target_write.

### `i3c_target_read`

Test: [i3c_target_read](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_i3c_target.py)

Writes a data chunk and its descriptor to TTI TX queues, issues
an I3C private read transfer. Verifies that the data matches.
Repeats the two steps N times.

Writes N data chunks and their descriptors to TTI TX queues,
issues N private read transfers over I3C. For each one verifies
that data matches.

Writes a data chunk and its descriptor to TTI TX queues, issues
an I3C private read transfer which is shorter than the length of
the chunk. Verifies that the received data matches with the chunk.
Repeats the steps N times.

The test runs at core clock of 100 and 200 MHz. The slowest clock that does not result in a tSCO violation is 166 MHz.
The I3C bus clock is set to 12.5 MHz.

### `i3c_target_read_long`

Test: [i3c_target_read_long](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_i3c_target.py)

Verifies the correct handling of long private reads (255 and 256 bytes)
that are not issued in any other tests, in order to cover upper bits
of transaction length signals in the design.

### `i3c_target_read_empty`

Test: [i3c_target_read_empty](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_i3c_target.py)

Issues multiple read transactions to the target and randomly selects 
whether each transaction has data.

If transaction is selected to contain data, writes a data chunk and
its descriptor to TTI TX queues, and verifies that the data matches.

If transaction doesn't contain data, checks that request is NACKed.

### `i3c_target_read_to_multiple_targets`

Test: [i3c_target_read_to_multiple_targets](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_i3c_target.py)

Sends multiple I3C frame, each containing multiple read transactions
with randomly selected addresses.
If transaction addresses I3C target, randomly selects if transaction
returns data or is NACked. Compares returned data if available.

If transaction doesn't address I3C target, expects NACK to be returned.

### `i3c_target_ibi`

Test: [i3c_target_ibi](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_i3c_target.py)

Writes an IBI descriptor to the TTI IBI queue. Waits until the
controller services the IBI. Checks if the mandatory byte (MDB)
matches on both sides.

Reads the LAST_IBI_STATUS fields of the TTI STATUS CSR. Ensures
that it is equal to 0 (no error).

Writes an IBI descriptor followed by N bytes of data to the TTI
IBI queue. Waits until the controller services the IBI. Checks if
the mandatory byte (MDB) and data matches on both sides.

Repeats the LAST_IBI_STATUS check.

The test runs at core clock of 100 and 200 MHz. The slowest clock that does not result in a tSCO violation is 166 MHz.
The I3C bus clock is set to 12.5 MHz.

### `i3c_target_ibi_retry`

Test: [i3c_target_ibi_retry](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_i3c_target.py)

Disables ACK-ing IBIs in the I3C controller model, issues an IBI
from the target by writing to TTI IBI queue. Waits for a fixed
time period - sufficiently long for the target to retry sending
the IBI, reads LAST_IBI_STATUS from the TTI STATUS CSR, check
if it is set to 3 (IBI retry).

Re-enables ACK-ing of IBIs in the controller model, waits for the
model to service the IBI, compares the IBI mandatory byte (MDB)
with the one written to the TTI queue. Reads LAST_IBI_STATUS from
the TTI STATUS CSR, check if it is set to 0 (no error).

The test runs at core clock of 100 and 200 MHz. The slowest clock that does not result in a tSCO violation is 166 MHz.
The I3C bus clock is set to 12.5 MHz.

### `i3c_target_ibi_data`

Test: [i3c_target_ibi_data](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_i3c_target.py)

Sets a limit on how many IBI data bytes may be accepted in the
controller model. Issues an IBI with more data bytes by writing
to the TTI IBI queue, checks if the IBI gets serviced correctly,
compares data.

Issues another IBI with data payload within the set limit, checks
if it gets serviced correctly, compares data.

The test runs at core clock of 100 and 200 MHz. The slowest clock that does not result in a tSCO violation is 166 MHz.
The I3C bus clock is set to 12.5 MHz.

### `i3c_target_ibi_data_long`

Test: [i3c_target_ibi_data_long](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_i3c_target.py)

Verifies issuing an IBI of a maximum length obtained via the
GETMRL CCC. Also covers upper bits of the IBI descriptor data
length.

### `i3c_target_writes_and_reads`

Test: [i3c_target_writes_and_reads](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_i3c_target.py)

Writes a randomized data chunk to the TTI TX data queue, writes
a corresponding descriptor to the TTI TX descriptor queue.

Issues private write transfers to the target with randomized
payloads, waits until a TTI interrupt is set by polling TTI
INTERRUPT_STATUS CSR. Reads received data from TTI RX queues,
compares it with what has been sent.

Does a private read transfer, compares if the received data equals
the data written to TTI TX queue in the beginning of the test.

The test runs at core clock of 100 and 200 MHz. The slowest clock that does not result in a tSCO violation is 166 MHz.
The I3C bus clock is set to 12.5 MHz.

### `i3c_target_pwrite_err_detection`

Test: [i3c_target_pwrite_err_detection](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_i3c_target.py)

Verifies target reports no error conditions using CSR and GETSTATUS CCC.
Sends I3C private write with incorrect T-bit value.
Checks that the CSR reports protocol error condition and checks
that RX descriptor has error condition flag set.
Sends GETSTATUS CCC and checks that it also reports protocol error.

### `i3c_target_pwrite_overflow_detection`

Test: [i3c_target_pwrite_overflow_detection](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_i3c_target.py)

Verifies target reports no error conditions using CSR and GETSTATUS CCC.
Sends I3C private write with more data than target can receive.
Checks that the CSR doesn't report protocol error condition and checks
that RX descriptor has error condition flag set.
Sends GETSTATUS CCC and checks that it also doesn't report protocol error.

### `i3c_target_private_read_sizes_and_abort`

Test: [i3c_target_private_read_sizes_and_abort](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_i3c_target.py)

Tests private read transfers with specific sizes and controller-initiated
aborts.

Performs private reads of exactly 256 bytes, 8 bytes, 11 bytes (non-word-
aligned), and a controller-abort scenario where the read is terminated
early. Verifies data matches and the target recovers cleanly after abort.

### `i3c_target_tx_flush_clears_converter`

Test: [i3c_target_tx_flush_clears_converter](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_i3c_target.py)

Verifies that TTI RESET_CONTROL.TX_DATA_RST flushes both the TX FIFO
and the width_converter_Nto8 shift register.

Writes data to the TX FIFO without a descriptor, asserts TX_DATA_RST,
then writes new data with a descriptor and performs a private read.
Verifies only the post-flush data is returned.

### `i3c_target_rx_flush_clears_converter`

Test: [i3c_target_rx_flush_clears_converter](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_i3c_target.py)

Verifies that TTI RESET_CONTROL.RX_DATA_RST flushes both the RX FIFO
and the width_converter_8toN shift register.

Writes data to the RX FIFO via Private Write to overflow the queue,
asserts RX_DATA_RST, then writes new data via Private Write.
Verifies that data from first transfer does not corrupt second transfer.

### `priv_write_normal_stop_baseline`

Test: [priv_write_normal_stop_baseline](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_i3c_target.py)

Baseline: 8-byte private write completes normally with STOP.
Verifies RX descriptor byte count equals 8 and data matches.

### `priv_write_stop_mid_byte`

Test: [priv_write_stop_mid_byte](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_i3c_target.py)

8-byte private write. After 5 complete bytes and T-bits, sends 4 bits
of byte 6, then STOP. Verifies RX descriptor reports 5 bytes and data
matches. Also verifies clean recovery with a subsequent normal write.

### `priv_write_sr_mid_byte`

Test: [priv_write_sr_mid_byte](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_i3c_target.py)

8-byte private write. After 5 complete bytes, sends 4 bits of byte 6,
then Repeated Start followed by STOP. Verifies RX descriptor reports
5 bytes. Also verifies clean recovery.

### `priv_write_stop_during_tbit`

Test: [priv_write_stop_during_tbit](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_i3c_target.py)

8-byte private write. After 5 complete bytes and T-bits, sends 8 data
bits of byte 6 (no T-bit), then STOP fires while FSM is in
RxPWriteTbit. Tests correct handling of STOP during T-bit phase.

BLOCKED BY DESIGN BUG: rx_fifo_wvalid_raw fires but rx_last_byte_o
does not, resulting in data pushed without a descriptor.

### `priv_write_sr_during_tbit`

Test: [priv_write_sr_during_tbit](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_i3c_target.py)

8-byte private write. After 5 complete bytes and T-bits, sends 8 data
bits of byte 6, then Sr fires while FSM is in RxPWriteTbit. Tests
correct handling of Repeated Start during T-bit phase.

BLOCKED BY DESIGN BUG: rx_fifo_wvalid_raw fires but rx_last_byte_o
does not, resulting in data pushed without a descriptor.

### `priv_write_tight_timing_sr`

Test: [priv_write_tight_timing_sr](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_i3c_target.py)

5-byte private write. All bytes and T-bits complete normally. Sr issued
immediately after the last T-bit (tight timing). Verifies descriptor
reports exactly 5 bytes (not 4 due to off-by-one).


# Data over-/underflow handling

## Testpoints

### `Reading from empty RX descriptor FIFO`

Test: empty_rx_desc_read

Perform read bus access to the empty RX descriptor queue,
verify that response comes back and it holds value of 0.

### `Reading from empty RX data FIFO`

Test: empty_rx_data_read

Perform read bus access to the empty RX descriptor queue,
verify that response comes back and it holds value of 0.

### `Reading from empty indirect FIFO`

Test: empty_indirect_fifo_read

Perform read bus access to the empty RX descriptor queue,
verify that response comes back and it holds value of 0.

### `Writing to full TX descriptor FIFO`

Test: full_tx_desc_write

Perform multiple write bus accesses to the TX descriptor queue,
verify that all transactions has finished.

### `Writing to full TX data FIFO`

Test: full_tx_data_write

Perform multiple write bus accesses to the TX data queue,
verify that all transactions has finished.

### `Writing to full IBI FIFO`

Test: full_ibi_write

Perform multiple write bus accesses to the IBI queue,
verify that all transactions has finished.


# Bus timers top-level

## Testpoints

### `STOP condition starts the counter`

Test: bus_timers_stop_starts_counter

Verifies that detecting a STOP condition on the I3C bus starts the
bus_timers counter and that the counter progresses through the bus
busy, free, available and idle states in the correct order with the
expected timing.

### `START condition resets the counter`

Test: bus_timers_reset_on_start

Verifies that a START condition detected after a STOP resets the
bus_timers counter back to 0 and deasserts all timer-state outputs
(bus_free, bus_available, bus_idle), leaving bus_busy asserted.

### `HDR mode entry holds the counter at 0`

Test: bus_timers_reset_on_hdr_entry

Verifies that entering HDR mode (in_hdr_mode_i asserted) continuously
holds the bus_timers counter at 0 for the duration of HDR mode.
After HDR exit the counter stays at 0 until the next STOP condition,
which must then restart normal timer operation.

### `bus_idle`

Test: bus_idle

Generate STOP condition, wait for over 200us and ensure the target entered idle state. Then
generate START condition and ensure target left idle state.

### `exotic_idle_timings`

Test: exotic_idle_timings

The bus conditions in the bus_timers module operate independently from each other
with each one configured by its own CSR. This introduces the unlikely possibility
of T_AVAL < T_FREE and T_IDLE < T_AVAL. This test exists to cover these conditions.

### `bus_edge_detectors`

Test: bus_edge_detectors

Sets up different values of T_R and T_F timings and for each detector (SDA posedge,
SDA negedge, SCL posedge, SCL negedge) verifies both whether the edge is correctly
detected when held for appropriate duration and whether it doesn't get detected when
deasserted before the timing duration.


# CCC handling

## Testpoints

### `ccc_getstatus`

Test: [ccc_getstatus](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ccc.py)

The test reads PENDING_INTERRUPT field from the TTI INTERRUPT
status CSR. Next, it issues the GETSTATUS directed CCC to the
target. Finally it compares the interrupt status returned by the
CCC with the one read from the register.

### `ccc_setdasa`

Test: [ccc_setdasa](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ccc.py)

The test sets dynamic address and virtual dynamic address by
sending SETDASA CCC. Then it verifies that correct addresses have
been set by reading STBY_CR_DEVICE_ADDR CSR.
The test also sends a random number of CCCs targeting devices other
than DUT, and checks if the dynamic address was not accepted.

### `ccc_setdasa_nack`

Test: [ccc_setdasa_nack](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ccc.py)

The test sets dynamic address and virtual dynamic address by
sending SETDASA CCC. Then it sends second SETDASA command and checks
that targets NACKed them.

### `ccc_setnewda`

Test: [ccc_setnewda](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ccc.py)

The test sets dynamic address and virtual dynamic address directly
using CSR accesses. Then it sends SETNEWDA commands to both targets
and checks their dynamic addresses got updated.

### `ccc_rstdaa`

Test: [ccc_rstdaa](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ccc.py)

Sets dynamic address via STBY_CR_DEVICE_ADDR CSR, then sends
RSTDAA CCC and verifies that the address got cleared.

### `ccc_getbcr`

Test: [ccc_getbcr](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ccc.py)

Reads BCR register content by sending GETBCR CCC and examining
returned data.

### `ccc_getdcr`

Test: [ccc_getdcr](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ccc.py)

Reads DCR register content by sending GETDCR CCC and examining
returned data.

### `ccc_getmwl`

Test: [ccc_getmwl](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ccc.py)

Reads MWL register content by sending GETMWL CCC and examining
returned data.

### `ccc_getmrl`

Test: [ccc_getmrl](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ccc.py)

Reads MRL register content by sending GETMWL CCC and examining
returned data.

### `ccc_setaasa`

Test: [ccc_setaasa](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ccc.py)

Issues the broadcast SETAASA CCC and checks if the target uses
its static address as dynamic by examining STBY_CR_DEVICE_ADDR
CSR.

### `ccc_setaasa_ignore`

Test: [ccc_setaasa_ignore](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ccc.py)

Assigns dynamic address different to static address using CSR.
Issues the broadcast SETAASA CCC and checks if the target ignores
this command by examining STBY_CR_DEVICE_ADDR CSR.

### `ccc_setaasa_single`

Test: [ccc_setaasa_single](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ccc.py)

Pre-configures the dynamic address of either the regular or the virtual
device via CSR (with valid=1), then sends SETAASA. Verifies that the
pre-configured device retains its CSR-set address while the other
device receives its static address as the new dynamic address.

### `ccc_getpid`

Test: [ccc_getpid](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ccc.py)

Sends the CCC to the target and examines if the returned PID
matches the expected.

### `ccc_enec_disec_direct`

Test: [ccc_enec_disec_direct](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ccc.py)

Sends DISEC CCC to the target and verifies that events are disabled.
Then, sends ENEC CCC to the target and checks that events are enabled.

### `ccc_enec_disec_bcast`

Test: [ccc_enec_disec_bcast](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ccc.py)

Sends broadcast DISEC CCC and verifies that events are disabled.
Then, sends broadcast ENEC CCC and checks that events are enabled.

### `ccc_setmwl_direct`

Test: [ccc_setmwl_direct](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ccc.py)

Sends directed SETMWL CCC to the target and verifies that the
register got correctly set. The check is performed by examining
relevant wires in the target DUT.

### `ccc_setmrl_direct`

Test: [ccc_setmrl_direct](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ccc.py)

Sends directed SETMRL CCC to the target and verifies that the
register got correctly set. The check is performed by examining
relevant wires in the target DUT.

### `ccc_setmwl_bcast`

Test: [ccc_setmwl_bcast](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ccc.py)

Sends broadcast SETMWL CCC and verifies that the
register got correctly set. The check is performed by examining
relevant wires in the target DUT.

### `ccc_setmrl_bcast`

Test: [ccc_setmrl_bcast](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ccc.py)

Sends SETMRL CCC and verifies that the
register got correctly set. The check is performed by examining
relevant wires in the target DUT.

### `ccc_rstact`

Test: [ccc_rstact](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ccc.py)

Sends directed/broadcast RSTACT CCC to the target followed by reset pattern
and checks if reset action was stored correctly. The check is
done by examining DUT wires. Then, triggers target reset and
verifies that the peripheral_reset_o signal gets asserted.

### `ccc_direct_multiple_wr`

Test: [ccc_direct_multiple_wr](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ccc.py)

Sends a sequence of multiple directed SETMWL CCCs. The first and
the last have non-matching address. The two middle ones set MWL
to different values. Verify that the target responded to correct
addresses and executed both CCCs.

### `ccc_direct_multiple_rd`

Test: [ccc_direct_multiple_rd](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ccc.py)

Sends SETMWL CCC. Then sends multiple directed GETMWL CCCs to
thee different addresses. Only the one for the target should
be ACK-ed with the correct MWL content.

### `ccc_entdaa`

Test: [ccc_entdaa](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ccc.py)

Verifies ENTDAA procedure: controller issues ENTDAA CCC, target responds
with 64-bit device ID, controller assigns dynamic address. Checks address
is set correctly in STBY_CR_DEVICE_ADDR CSR.

### `ccc_entdaa_arb_lost`

Test: [ccc_entdaa_arb_lost](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ccc.py)

Verifies ENTDAA arbitration-lost path: when arbitration_lost_i is asserted
during ID bit transmission, the DUT enters LostArbitration state and
retries on the next ENTDAA round.

### `ccc_entdaa_early_stop`

Test: [ccc_entdaa_early_stop](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ccc.py)

Verifies ENTDAA with early STOP after assigning only the main target.
The virtual target should remain unaddressed.

### `ccc_entdaa_te3_te4`

Test: [ccc_entdaa_te3_te4](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ccc.py)

Verifies TE3 and TE4 error handling during ENTDAA.

TE3: Parity error on assigned address causes target to NACK, retries
on next ENTDAA round.
TE4: Controller assigns same address to two targets, causes error.

Ensures that CSR with error counter does not overflow.

### `ccc_enthdr_all_codes`

Test: [ccc_enthdr_all_codes](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ccc.py)

Verifies all ENTHDR codes (0x20-0x27) cause the target to enter HDR mode.
After each ENTHDR, verifies clean recovery with HDR exit pattern.

### `ccc_error_det_enable`

Test: [ccc_error_det_enable](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ccc.py)

Verifies TE0-TE5 error detection enable CSR bits can be toggled.
When TE0 is disabled, unsupported CCC should not trigger error.
When TE0 is re-enabled, error detection resumes.

### `ccc_getcaps`

Test: [ccc_getcaps](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ccc.py)

Tests GETCAPS (0x95) direct GET CCC with various defining bytes,
targeting both main and virtual targets.

### `ccc_setdasa_padding_err`

Tests:
- [ccc_setdasa_padding_err](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ccc.py)- [ccc_setdasa_padding_err_det_disabled](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ccc.py)

Verifies that SETDASA/SETNEWDA with padding bit[0]=1 triggers a framing
error and does NOT apply the address.

### `ccc_te2_parity`

Test: [ccc_te2_parity](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ccc.py)

Verifies TE2 error detection: bad T-bit parity on CCC defining byte
causes the target to abort the CCC and signal TE2.

### `ccc_te5_wrong_direction`

Test: [ccc_te5_wrong_direction](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ccc.py)

TE5 error: wrong R/W direction for direct CCC.
GET CCC sent with W direction causes NACK.
SET CCC sent with R direction causes NACK.

### `ccc_unknown_broadcast`

Test: [ccc_unknown_broadcast](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ccc.py)

Unknown broadcast CCCs should be silently ignored (target accepts data
but takes no action). Verifies no crash and clean recovery.

### `ccc_unsupported_direct_nack`

Test: [ccc_unsupported_direct_nack](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ccc.py)

Verifies that unsupported direct CCCs are NACKed by the target.
Tests deprecated, unsupported, and vendor-specific CCC codes.

### `ccc_vendor_codes`

Test: [ccc_vendor_codes](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ccc.py)

Verifies vendor-specific CCC codes:
Broadcast vendor CCCs (0x61-0x7F): target ignores data silently.
Direct vendor CCCs: target NACKs.

### `ccc_abort_bcast_stop`

Test: [ccc_abort_bcast_stop](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ccc.py)

Controller STOP during CCC at various phases:
STOP during broadcast SET data (incomplete data).
Verifies clean recovery.

### `ccc_abort_get_sr`

Test: [ccc_abort_get_sr](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ccc.py)

Controller Sr abort during multi-byte GET CCC reads. Reads fewer bytes
than expected, then sends Sr to abort. Verifies clean recovery and
correct subsequent CCC processing.

### `ccc_addr_lifecycle`

Test: [ccc_addr_lifecycle](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ccc.py)

Full address lifecycle: RSTDAA -> SETDASA -> verify -> SETNEWDA -> verify ->
RSTDAA -> verify cleared. Tests both main and virtual targets.

### `ccc_back_to_back`

Test: [ccc_back_to_back](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ccc.py)

Back-to-back CCCs with no idle gap between transactions.
Verifies all CCCs process correctly.

### `ccc_chain_bcast`

Test: [ccc_chain_bcast](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ccc.py)

Chain multiple broadcast CCCs via Sr+7E/W within a single frame.
Verifies each CCC takes effect.

### `ccc_chain_direct`

Test: [ccc_chain_direct](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ccc.py)

Chain multiple direct CCCs within a single frame.
Verifies correct target address matching across chained CCCs.

### `ccc_random_interleave`

Test: [ccc_random_interleave](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ccc.py)

Random sequence of SET/GET CCCs to random targets. Stress tests the
CCC FSM state machine with varied patterns.

### `ccc_rstact_arm_clear_on_start`

Test: [ccc_rstact_arm_clear_on_start](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ccc.py)

Verifies RSTACT arm is cleared by START (not Sr). After arming with
whole-target reset, a private transfer (START) clears the arm state.

### `ccc_rstact_escalation_clear`

Test: [ccc_rstact_escalation_clear](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ccc.py)

Verifies that RSTACT CCC and GETSTATUS CCC clear the escalation counter,
preventing escalated reset on the next target reset pattern.

### `ccc_rstact_read_action`

Test: [ccc_rstact_read_action](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ccc.py)

Verifies RSTACT internal state after arming. Per spec, rstact_armed is
cleared by the next START (not Sr), so a subsequent read may return
the armed action.

### `ccc_rstact_unsupported_db`

Test: [ccc_rstact_unsupported_db](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ccc.py)

Verifies RSTACT with unsupported defining bytes is NACKed.

### `ccc_rstact_vt_detect`

Test: [ccc_rstact_vt_detect](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ccc.py)

Verifies RSTACT Defining Byte 0x04 (Virtual Target Detect) flag set/clear
and Defining Byte 0x84 (Virtual Target Indication) behavior.

### `ccc_rstact_vt_detect_no_reset_arm`

Test: [ccc_rstact_vt_detect_no_reset_arm](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ccc.py)

Verifies DB=0x04 does not arm a reset action: default peripheral->escalation
path still works after sending RSTACT with VT detect defining byte.

### `ccc_setmwl_sr_abort_during_data`

Test: [ccc_setmwl_sr_abort_during_data](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ccc.py)

Sr abort during SETMWL data phase. Verifies that the target does not apply
the partial data.

BLOCKED BY DESIGN BUG: set_tx_data_complete fires unconditionally on Sr
abort.

### `ccc_getstatus_abort_then_chain_setmwl`

Test: [ccc_getstatus_abort_then_chain_setmwl](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ccc.py)

Verifies that aborting GETSTATUS mid-read and immediately chaining into
another CCC (SETMWL) in the same bus frame does not corrupt the target
state.

### `ccc_getstatus_sr_abort_clears_protocol_err`

Test: [ccc_getstatus_sr_abort_clears_protocol_err](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ccc.py)

Verifies GETSTATUS Sr abort behavior with protocol error flag. Per spec,
a target shall only clear its pending status upon successfully completing
the GETSTATUS response.

BLOCKED BY DESIGN BUG: set_tx_data_complete fires unconditionally on Sr
abort, causing premature error clearing.

### `ccc_getstatus_sr_abort_done_assert`

Test: [ccc_getstatus_sr_abort_done_assert](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ccc.py)

Verifies that aborting GETSTATUS during T-Bit transfer does not fire get_status_done
and reports protocol error.

### `ccc_entdaa_virtual_only`

Test: [ccc_entdaa_virtual_only](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ccc.py)

Coverage: ccc.sv RxCmdTbit -> HandleVirtualTargetENTDAA.
Boot with main target already addressed. Virtual target has no dynamic
address. ENTDAA skips HandleTargetENTDAA and goes directly to
HandleVirtualTargetENTDAA.

### `ccc_entdaa_main_only`

Test: [ccc_entdaa_main_only](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ccc.py)

Coverage: HandleTargetENTDAA -> WaitForENTDAAEnd (entdaa_needs_virt_addr=0).
Boot with virtual target already addressed. Main target has no dynamic
address. After main completes, FSM goes to WaitForENTDAAEnd.

### `ccc_entdaa_both_addressed`

Test: [ccc_entdaa_both_addressed](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ccc.py)

Coverage: RxCmdTbit -> WaitForENTDAAEnd.
Boot with both targets already addressed. ENTDAA goes directly to
WaitForENTDAAEnd since neither target needs an address.

### `ccc_te0_reserved_addr_direct`

Test: [ccc_te0_reserved_addr_direct](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ccc.py)

Coverage: Toggle is_te0_err_condition, te0_err_ccc (ccc.sv:769).
Send a direct CCC where the target address phase uses 7E/R (reserved
address with read bit). Triggers TE0 in TxTargetAddrAck.

### `ccc_direct_chain_7e_termination`

Test: [ccc_direct_chain_7e_termination](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ccc.py)

Coverage: ccc.sv target_addr_matches_rsvd -> NextCCC.
After a direct GET CCC response, send Sr+7E/W instead of STOP. Triggers
the reserved address path in TxTargetAddrAck, transitioning to NextCCC
for CCC chaining.

### `ccc_all_det_en_toggle`

Test: [ccc_all_det_en_toggle](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ccc.py)

Coverage: All *_det_en_i toggle coverage.
For TE0, TE1, TE2, TE5: toggle the detection enable CSR, inject
the error with det_en=0 (verify no error flag), then with det_en=1
(verify error fires).

### `ccc_te2_direct_def_byte_tbit`

Test: [ccc_te2_direct_def_byte_tbit](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ccc.py)

Coverage: ccc.sv RxDirectDefByteTbit -> DoneCCC,
WaitDirectRstart -> RxDirectDefByteTbit.
Send a direct CCC with defining byte, then an extra data byte with bad
T-bit parity before the repeated start for the target address.

### `ccc_direct_extra_data_before_addr`

Test: [ccc_direct_extra_data_before_addr](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ccc.py)

Coverage: ccc.sv WaitDirectRstart -> RxDirectDefByteTbit,
RxDirectDefByteTbit -> WaitDirectRstart.
Send a direct CCC with defining byte, then extra data bytes with good
T-bit parity before the repeated start. Then complete the CCC normally.

### `ccc_te2_data_byte_direct_set`

Test: [ccc_te2_data_byte_direct_set](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ccc.py)

Coverage: RxDataTbit -> DoneCCC (ccc.sv:1104-1108).
Send a direct SET CCC (SETMWL) and inject T-bit parity error on the
first data byte after the target ACKs the address.

### `ccc_entdaa_te3_det_en_toggle`

Test: [ccc_entdaa_te3_det_en_toggle](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ccc.py)

Coverage: Toggle te3_err_det_en_i in ccc_entdaa.
Inject TE3 (bad address parity during ENTDAA) with te3_err_det_en=0
then with te3_err_det_en=1.

### `ccc_entdaa_te4_det_en_disabled`

Test: [ccc_entdaa_te4_det_en_disabled](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ccc.py)

Coverage: TE4_ERR_DET_EN=0 path in ccc_entdaa.
Inject TE4 (7E/W instead of 7E/R) with te4_err_det_en=0.
Target should ACK the invalid reserved byte, TE4_ERR_STAT must remain 0,
and the TE4 error counter must not increment.

### `ccc_stop_mid_transfer`

Test: [ccc_stop_mid_transfer](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ccc.py)

Coverage: Multiple FSM -> DoneCCC transitions via STOP override.
Tests STOP during RxDefByte, RxDefByteOrBusCond, WaitDirectRstart,
TxData, TxDataTbitCont, and TxDataTbitEnd states.

### `ccc_entdaa_stop_in_waitstart`

Test: [ccc_entdaa_stop_in_waitstart](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ccc.py)

Coverage: ENTDAA FSM WaitStart -> Done.
Issue ENTDAA CCC byte, then STOP immediately before Sr+7E/R.

### `ccc_entdaa_stop_in_sendidbit`

Test: [ccc_entdaa_stop_in_sendidbit](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ccc.py)

Coverage: ENTDAA FSM SendIDBit -> Done.
Start ENTDAA, let Sr+7E/R complete and begin ID bit transmission,
then issue STOP mid-ID-bit.

### `ccc_entdaa_stop_in_receiveaddr`

Test: [ccc_entdaa_stop_in_receiveaddr](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ccc.py)

Coverage: ENTDAA FSM ReceiveAddr -> Done.
Complete ID bit transmission (64 bits), then issue STOP mid-address-byte.

### `ccc_entdaa_stop_in_ackrsvdbyte`

Test: [ccc_entdaa_stop_in_ackrsvdbyte](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ccc.py)

Coverage: ENTDAA FSM AckRsvdByte -> Done.
Issue STOP during the reserved byte ACK phase of ENTDAA.

### `ccc_entdaa_stop_in_sendnack`

Test: [ccc_entdaa_stop_in_sendnack](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ccc.py)

Coverage: ENTDAA FSM SendNack -> Done.
Inject TE4 (7E/W instead of 7E/R) so target NACKs. ENTDAA FSM enters
SendNack, then issue STOP.

### `ccc_stop_during_target_read`

Test: [ccc_stop_during_target_read](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ccc.py)

Coverage: TxData->DoneCCC, TxDataTbitCont->DoneCCC,
TxDataTbitEnd->DoneCCC, TxTargetAddrAck->DoneCCC.
Issues real bus-level STOP during target-driven read phases.

### `ccc_csr_concurrent_stress`

Test: [ccc_csr_concurrent_stress](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ccc.py)

Stress test: concurrent random FW (AXI) and I3C CCC accesses to
CCC-affected CSRs. FW randomly reads/writes CCC-related CSRs via AXI
in the background while I3C performs 50 random supported CCC operations
(GET and SET). GET CCCs verify ACK; SET CCCs send random valid data.
Goal: expose data races, coherency bugs, or FSM hangs under concurrent
access from both interfaces.

### `entdaa`

Test: [](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ccc.py)

Perform the ENTDAA procedure, validate the addresses were assigned correctly.

### `entdaa_parity_errors`

Test: [](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ccc.py)

Perform the ENTDAA procedure, inject parity errors to offered addresses.
Validate no address with a parity error was assigned.
Disable parity checking and validate that addresses are assigned despite the error.


# CSR access check

## Testpoints

### `Test CSR accesses`

Tests:
- [dat_csr_access](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_csr_access.py)- [dct_csr_access](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_csr_access.py)- [base_csr_access](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_csr_access.py)- [pio_csr_access](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_csr_access.py)- [ec_sec_fw_rec_csr_access](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_csr_access.py)- [ec_stdby_ctrl_mode_csr_access](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_csr_access.py)- [ec_tti_csr_access](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_csr_access.py)- [ec_soc_mgmt_csr_access](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_csr_access.py)- [ec_contrl_config_csr_access](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_csr_access.py)- [ec_csr_access](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_csr_access.py)

Walk over all CSRs, write random value using AHB/AXI, read it back,
and compare with expected output.

### `AXI burst read`

Test: [basic_burst_read](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_csr_access.py)

Tests if the CSRs can be correctly read using variously
configured AXI burst read transactions.

At the beginning, the first 1KB of the register map is dumped
in 4B chunks using the regular read_csr helper function
which issues a single 4B AXI read for each chunk of data.

Then, for multiple possible combinations of arburst, arlen, arsize,
arlock and aruser signal values a burst read is issued for a random
starting address. Its response is then compared with values dumped
at the beginning.

### `AXI burst write`

Test: [basic_burst_write](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_csr_access.py)

Tests if the CSRs can be correctly written to using variously
configured AXI burst write transactions.

Firstly, the test data is prepared for each register in the map,
taking into account properties of their fields. This results in
a 1KB write data and expected readback buffers.

Then, for multiple possible combinations of awburst, awlen, awsize,
awlock and awuser signal values a burst write is issued for a random
starting address, with data supplied by the test write data buffer.

After confirming the transaction got an OKAY response, the same range
of memory that had just been written to is then read back using
the regular read_csr function and the obtained data is compared
with the expected readback buffer.

### `AXI stall accesses`

Tests:
- [write_stall](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_csr_access.py)- [read_stall](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_csr_access.py)- [write_b_channel_skid_full](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_csr_access.py)- [read_r_channel_skid_full](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_csr_access.py)

Issue randomized read and write transactions, stall R and B channels
for random time, release the bus and compare with expected output.


# Empty queue read handling

## Testpoints

### `normal_read_empty_rx_desc_queue`

Test: normal_read_empty_rx_desc_queue

Read TTI RX_DESC_QUEUE_PORT when empty in normal mode. Must complete
without hanging and return 0.

### `normal_read_empty_rx_data_port`

Test: normal_read_empty_rx_data_port

Read TTI RX_DATA_PORT when empty in normal mode. Must complete
without hanging and return 0.

### `normal_read_empty_indirect_fifo_data`

Test: normal_read_empty_indirect_fifo_data

Read INDIRECT_FIFO_DATA when empty in normal mode. Must complete
without hanging and return 0.

### `normal_read_empty_all_queues`

Test: normal_read_empty_all_queues

Read all three empty FIFO ports in normal mode sequentially.
Verifies no AXI bus deadlock from back-to-back external reads.

### `recovery_read_empty_rx_desc_queue`

Test: recovery_read_empty_rx_desc_queue

Read TTI RX_DESC_QUEUE_PORT when empty in recovery mode. This is
the scenario that caused the AXI deadlock bug: recovery_pending=1
caused R1MUX contention.

### `recovery_read_empty_rx_data_port`

Test: recovery_read_empty_rx_data_port

Read TTI RX_DATA_PORT when empty in recovery mode. Must complete
without hanging.

### `recovery_read_empty_indirect_fifo_data`

Test: recovery_read_empty_indirect_fifo_data

Read INDIRECT_FIFO_DATA when empty in recovery mode. Must complete
without hanging.

### `recovery_read_empty_all_queues`

Test: recovery_read_empty_all_queues

Read all three empty FIFO ports in recovery mode sequentially.
Verifies no AXI bus deadlock from back-to-back external reads while
recovery_pending is asserted.

### `concurrent_recovery_xfer_and_rx_desc_read`

Test: concurrent_recovery_xfer_and_rx_desc_read

While an I3C recovery read (PROT_CAP) is in-flight, which asserts
recovery_pending, concurrently read TTI RX_DESC_QUEUE_PORT via AXI.
This is the exact scenario that triggered the AXI deadlock bug.

### `concurrent_recovery_xfer_and_tx_desc_write`

Test: concurrent_recovery_xfer_and_tx_desc_write

While an I3C recovery read (PROT_CAP) is in-flight, which asserts
recovery_pending, concurrently write TTI TX_DESC_QUEUE_PORT via AXI.

### `concurrent_recovery_xfer_and_all_queue_access`

Test: concurrent_recovery_xfer_and_all_queue_access

While an I3C recovery read (PROT_CAP) is in-flight, which asserts
recovery_pending, concurrently access all TTI queue ports via AXI:
read RX_DESC, read RX_DATA, write TX_DESC, and read INDIRECT_FIFO.

### `recovery_write_rx_data_observation`

Test: recovery_write_rx_data_observation

Writes data to INDIRECT_FIFO_DATA on the virtual target via the
recovery interface. In parallel, monitors the RTL signal
tti_rx_depth to verify data flow observation.


# Enter and exit HDR mode

## Testpoints

### `Enter and exit HDR-DDR mode`

Tests:
- [enter_exit_hdr_mode_write](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_enter_exit_hdr_mode.py)- [enter_restart_exit_hdr_mode_write](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_enter_exit_hdr_mode.py)- [enter_exit_hdr_mode_read](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_enter_exit_hdr_mode.py)- [enter_restart_exit_hdr_mode_read](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_enter_exit_hdr_mode.py)

Issues ENTHDR0 CCC to the target, verifies that the target FSM
is in IdleHDR state. Issues at least 1 read/write HDR-DDR command(s)
followed by HDR exit pattern, verifies that
the target FSM is back in Idle state.

### `HDR timeout disabled by default`

Test: [hdr_timeout_disabled_by_default](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_enter_exit_hdr_mode.py)

Verifies that the HDR timeout timer does not fire when the enable bit
is 0 (default configuration).

### `HDR timeout configurable threshold`

Test: [hdr_timeout_configurable_threshold](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_enter_exit_hdr_mode.py)

Verifies that the HDR timeout timer fires at the configured threshold,
not a hardcoded value.

### `HDR timeout resets on line low`

Test: [hdr_timeout_resets_on_line_low](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_enter_exit_hdr_mode.py)

Verifies that the HDR timeout timer resets when either SCL or SDA
goes low.

### `HDR timeout does not fire for CCC HDR`

Test: [hdr_timeout_does_not_fire_for_ccc_hdr](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_enter_exit_hdr_mode.py)

Verifies that the HDR timeout timer does NOT fire during normal HDR
mode entered via ENTHDR CCC.

### `HDR timeout recovery TE0`

Test: [hdr_timeout_recovery_te0](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_enter_exit_hdr_mode.py)

Verifies 60us timeout recovery after TE0 error (invalid reserved
address). Timer triggers HDR exit and recovery.

### `HDR timeout recovery TE1`

Test: [hdr_timeout_recovery_te1](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_enter_exit_hdr_mode.py)

Verifies 60us timeout recovery after TE1 error (CCC parity error).
Timer triggers HDR exit and recovery.

### `HDR exit pattern works alongside timer`

Test: [hdr_exit_pattern_works_alongside_timer](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_enter_exit_hdr_mode.py)

Verifies that the normal HDR Exit Pattern still works correctly when
the HDR timeout timer is enabled.

### `cycle_all_hdr_modes`

Test: [cycle_all_hdr_modes](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_enter_exit_hdr_mode.py)




# IBI handling

## Testpoints

### `ibi_accept_read_all_data`

Test: ibi_accept_read_all_data

Accept IBI, read all data bytes. Exercises MDB-only and various
payload lengths. Verifies data integrity on controller side.

### `ibi_accept_partial_no_repeat`

Test: ibi_accept_partial_no_repeat

Controller truncates additional IBI data bytes. Target shall NOT
repeat the unserviced IBI per Sec 5.1.6.2 item 1.a.

### `ibi_refuse_no_retry_on_rstart`

Test: ibi_refuse_no_retry_on_rstart

After NACK, target retries on Bus Available/Start but NOT on Repeated
Start. Verifies WaitRestart->RxFByte transition (not RxFByteArb).

### `ibi_refuse_and_disable`

Test: ibi_refuse_and_disable

Refuse IBI, then disable interrupts via DISEC CCC. Target must NOT
retry until ENEC re-enables. NACKs the IBI followed by broadcast
DISEC, then re-enables via ENEC.

### `ibi_accept_then_ccc`

Test: ibi_accept_then_ccc

After accepting IBI and reading data, controller issues Sr->CCC.
Verifies CCC executes correctly. Also verifies PENDING_INTERRUPT
field behavior.

### `ibi_refuse_then_ccc`

Test: ibi_refuse_then_ccc

After NACKing IBI, controller issues Sr->CCC. Target must NOT attempt
IBI during the Sr->CCC frame. After STOP and bus available, target
retries the IBI.

### `ibi_initiation_bus_available_vs_start`

Test: ibi_initiation_bus_available_vs_start

Target initiates IBI via Bus Available Condition (1us) or during Bus
Start within Bus Free (38.4ns). Verifies both initiation paths.

### `ibi_arbitration_dut_wins`

Test: ibi_arbitration_dut_wins

Lower address equals higher priority. Verifies DUT can send IBI when
configured with a lower address and wins arbitration.

### `ibi_arbitration_dut_loses_bus_available_wait`

Test: ibi_arbitration_dut_loses_bus_available_wait

After losing arbitration (simulated via NACK), DUT sets ibi_inhibit
and must wait for Bus Available (1us) before retrying. Controller
issues transactions in between.

### `ibi_back_to_back`

Test: ibi_back_to_back

Multiple IBIs issued sequentially. Verifies each is received correctly
with proper status and interrupt behavior.

### `ibi_arb_loss_address`

Test: ibi_arb_loss_address

DUT loses IBI arbitration to a lower-address peer during the address
phase. RTL sets ibi_inhibit and DUT must NOT retry on the next Start,
only after Bus Available.

### `ibi_arb_loss_rnw_bit`

Test: ibi_arb_loss_rnw_bit

DUT tries IBI (addr+RnW=1) during a controller-initiated write to the
same 7-bit address (addr+RnW=0). Address bits match on the bus;
arbitration is lost on the RnW bit.

### `ibi_nack_sr_private_write`

Test: ibi_nack_sr_private_write

Controller NACKs IBI then chains Sr followed by Private Write to the
target within the same bus frame. Target must NOT attempt IBI on the
chained Repeated Start.

### `ibi_nack_sr_directed_disec`

Test: ibi_nack_sr_directed_disec

Controller NACKs IBI then chains Sr followed by Directed DISEC with
DISINT to the target. Verifies IBI is disabled and target does not
retry.

### `ibi_accept_no_mdb_stop`

Test: ibi_accept_no_mdb_stop

Target always sends MDB (BCR[2]=1). Controller ACKs but sends STOP
without reading MDB. Target should report a non-success IBI status
since MDB was not consumed.

### `ibi_accept_no_mdb_sr_ccc`

Test: ibi_accept_no_mdb_sr_ccc

Target always sends MDB (BCR[2]=1). Controller ACKs but sends
Sr followed by CCC without reading MDB. Target should report a
non-success IBI status since MDB was not consumed.

### `ibi_tbit_abort_sr_ccc`

Test: ibi_tbit_abort_sr_ccc

Controller ACKs IBI, reads partial data (T-bit abort by stopping
early), then chains Sr followed by CCC. Target should report
IbiPartialData status.

### `ibi_queue_while_disabled_then_enable`

Test: ibi_queue_while_disabled_then_enable

IBI data queued while IBI_EN=0 sits dormant in the descriptor pipeline
until IBI_EN is set to 1. Verifies the IBI fires correctly after
enabling.

### `ibi_retry_ctr_fw_reset`

Test: ibi_retry_ctr_fw_reset

Verifies IBI_RETRY_CTR_RST singlepulse resets the retry counter
mid-sequence. Without the FW reset, NACKs would exhaust the retry
limit.

### `ibi_multiple_arb_losses`

Test: ibi_multiple_arb_losses

Tests behavior after multiple IBI arbitration losses. Verifies
correct retry and recovery behavior.

KNOWN ISSUE: IBI_QUEUE_RST only empties the FIFO; it does not
reset descriptor_ibi state machine.

### `ibi_queued_during_hdr_fires_after_exit`

Test: ibi_queued_during_hdr_fires_after_exit

Verifies IBI queued while DUT is in HDR mode fires correctly after
the HDR exit pattern is detected and Bus Available occurs.

### `rxfbytearb_collision_blind_drive`

Test: rxfbytearb_collision_blind_drive

RxFByteArb arb-loss on RnW bit with conforming controller. Per
spec, address arbitration is open-drain: 0 is dominant. DUT enters
RxFByteArb driving the IBI address and loses arbitration.

### `ibi_flush_from_idle_interrupt_flood`

Test: ibi_flush_from_idle_interrupt_flood

Tests IBI queue flush from idle state with interrupt flooding.

KNOWN ISSUE: IBI_QUEUE_RST only empties the FIFO; it does not
reset descriptor_ibi state machine.

### `ibi_multi_queue_nack_recovery`

Test: ibi_multi_queue_nack_recovery

Pre-queues 3 IBIs into the TTI IBI FIFO, NACKs the first until retry
exhaustion (retry_num=0), then FW resets the retry counter via
IBI_RETRY_CTR_RST. The target retries the same IBI (still loaded in
descriptor_ibi), controller accepts it and all subsequent IBIs drain
in FIFO order. Verifies multi-IBI queuing, NACK retry exhaustion,
FW-initiated retry counter reset, and IBI pipeline recovery.

### `ibi_multi_queue_partial_then_continue`

Test: ibi_multi_queue_partial_then_continue

Pre-queues 3 IBIs, controller truncates the first IBI (partial read).
descriptor_ibi flushes remaining data and auto-advances to the next
queued IBI without FW intervention. Remaining IBIs are accepted with
correct data. Verifies Flush -> Idle auto-advance path and that
target does NOT repeat the partially-aborted IBI (Sec 5.1.6.2).

### `ibi_multi_queue_mixed_abort`

Test: ibi_multi_queue_mixed_abort

Pre-queues 4 IBIs, exercises both abort types in sequence:
IBI #0 is partially aborted (auto-advance via Flush), IBI #1 is
accepted normally, IBI #2 is NACKed with retry exhaustion then
recovered via FW retry counter reset, IBI #3 is accepted after
auto-advancing from FIFO. Verifies interleaved partial-abort
and NACK recovery paths in a single multi-IBI sequence.

### `ibi_rxfbytearb_wins_arbitration`

Test: ibi_rxfbytearb_wins_arbitration

Coverage: i3c_target_fsm.sv RxFByteArb -> IbiReadAck.
DUT has low address (0x10), wins IBI arbitration during a
controller-initiated Start. FSM enters RxFByteArb and drives the
IBI address, winning arbitration.

### `ibi_inhibit_retry_release`

Test: ibi_inhibit_retry_release

Coverage: i3c_target_fsm.sv InhibitRetry -> InhibitNone transition.
With retry_num=0, a single NACK exhausts retries. FW resets the retry
counter to release inhibit. DUT retries and succeeds.

### `ibi_rxfbytearb_retry_exhausted`

Test: ibi_rxfbytearb_retry_exhausted

Coverage: i3c_target_fsm.sv RxFByteArb -> RxFByte.
Start with retry_num=7, NACK the DUT, then change retry_num=0 via CSR.
Now ibi_can_retry is false, so RxFByteArb falls through to RxFByte.

### `ibi_arb_lost_in_drive_addr`

Test: ibi_arb_lost_in_drive_addr

Coverage: i3c_target_fsm.sv IbiDriveAddr -> WaitRestart.
DUT has a high address (0x60). It enters IbiDriveAddr via
bus_available. A background task forces arbitration loss by driving SDA
low, causing the FSM to transition to WaitRestart.

### `ibi_not_attempted_without_addr`

Test: ibi_not_attempted_without_addr

Coverage: i3c_target_fsm.sv ibi_pending (cond).
DUT is initialized with neither a static nor a dynamic address.
An IBI is then pushed to the IBI queue and the test ensures
that no action of sending the IBI is attempted by the DUT until
it has a valid address assigned.

### `ibi_retry_count_limit`

Test: 

NACK all IBIs until count limit is reached

### `test_ibi_pending_read_notification`

Test: ibi_pending_read_notification



### `test_ibi_refuse_retry`

Test: ibi_refuse_retry




# Target interrupts

## Testpoints

### `rx_desc_stat`

Test: [rx_desc_stat](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_i3c_target.py)

Enables RX_DESC_STAT TTI interrupt, checks if the irq_o signal is
deasserted, sends a private write over I3C to the target and
waits for irq_o assertion. Once the interrupt is asserted reads
a RX descriptor from the TTI RX descriptor queue, ensures that
irq_o gets deasserted after the read.

### `tx_desc_stat`

Test: [tx_desc_stat](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_i3c_target.py)

Enables TX_DESC_STAT TTI interrupt, checks if the irq_o signal is
deasserted, writes data to TTI TX data queue followed by writing
a descriptor to TTI TX descriptor queue, sends a private read
over I3C and waits for irq_o assertion. Once the interrupt is
asserted clears it by writing 1 to the TX_DESC_STAT fields of TTI
INTERRUPT_STATUS csr and ensures that irq_o signal gets deasserted.

### `ibi_done`

Test: [ibi_done](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_i3c_target.py)

Enables IBI_DONE_EN TTI interrupt, checks if the irq_o signal is
deasserted, and the status bit in TTI INTERRUPT_STATUS CSR cleared.
Issues and IBI, waits for it to be serviced by the controller.
Checks if the status bit is set in INTERRUPT_STATUS CSR and the
irq_o signal asserted. Reads LAST_IBI_STATUS field from the TTI
STATUS CSR, ensures that irq_o gets deasserted and status bit gets
cleared afterwards.

### `interrupt_force`

Test: [interrupt_force](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_i3c_target.py)

The test is run for each TTI interrupt:
 - TX_DESC_STAT_EN
 - RX_DESC_STAT_EN
 - RX_DESC_THLD_STAT_EN
 - RX_DATA_THLD_STAT_EN
 - IBI_DONE_EN

Ensures that irq_o is deasserted. Disables the interrupt in TTI
INTERRUPT_ENABLE CSR, forces the interrupt by writing 1 to the
corresponding field in TTI INTERRUPT_FORCE CSR, ensures that
the irq_o does not get asserted.

Enables the interrupt in TTI INTERRUPT_ENABLE CSR, forces the
interrupt by writing 1 to the corresponding field in
TTI INTERRUPT_FORCE CSR, ensures that the irq_o does get asserted.

Clears the interrupt by writing 1 to its corresponding field in
TTI INTERRUPT_STATUS CSR, ensures that irq_o gets deasserted and
the status bit cleared.

### `rx_desc_overflow`

Test: [rx_desc_overflow](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_i3c_target.py)

Checks if the tti_rx_desc_full signal gets asserted when there
are enough unhandled private writes issued to overfill the
RX descriptor FIFO.


# Recovery mode tests

## Testpoints

### `virtual_write`

Test: virtual_write

Tests CSR write(s) through recovery protocol using the virtual
target address. In the beginning sets the TTI and recovery
addresses via two SETDASA CCCs.

Performs a write to DEVICE_RESET register via the recovery
protocol targeting the virtual address. Reads the CSR content
back through AHB/AXI, checks if the transfer was successful and
the content read back matches. Then reads again the DEVICE_RESET
register, this time via the recovery protocol. Check if the content
matches.

Reads PENDING_INTERRUPT field from INTERRUPT_STATUS CSR via the
GET_STATUS CCC command issued to the TTI I3C address. Verifies
that the content read back matches what is set in the CSR.

Writes to the INDIRECT_FIFO_CTRL register using recovery protocol,
reads content of the register via AHB/AXI and verifies that their
content matches.

The test runs at core clock of 100 and 200 MHz. The slowest clock that does not result in a tSCO violation is 166 MHz.
The I3C bus clock is set to 12.5 MHz.

### `virtual_overwrite`

Test: virtual_overwrite

Tests CSR write(s) with lengths over CSR size to the virtual
address using recovery protocol.

Performs a write to on of DEVICE_RESET/RECOVERY_CTRL/INDIRECT_FIFO_CTRL
registers via the recovery protocol targeting the virtual address.
Reads the CSR content back through AHB/AXI. Then reads again
the selected register, this time via the recovery protocol.
Check if the content matches value stored in the register.

### `virtual_write_alternating`

Test: virtual_write_alternating

Sets the TTI and recovery addresses via two SETDASA CCCs.

Writes to DEVICE_RESET via recovery protocol targeting the virtual
device address. Reads the register content through AHB/AXI and
check if it matches with what has been written.

Sends a private write transfer to the TTI address. Reads the
data back from TTI TX data queue and check that it matches.

Disables the recovery mode by writing 0x2 to DEVICE_STATUS register
and repeats the previous steps to test whether the I3C core
responds both to TTI and virtual addresses.

The test runs at core clock of 100 and 200 MHz. The slowest clock that does not result in a tSCO violation is 166 MHz.
The I3C bus clock is set to 12.5 MHz.

### `read_fifo_ctrl`

Test: read_fifo_ctrl

Sets the TTI and recovery addresses via two SETDASA CCCs.

Writes to DEVICE_RESET via recovery protocol targeting the virtual
device address. Reads the register content through AHB/AXI and
check if it matches with what has been written.

Writes to INDIRECT_FIFO_CTRL via recovery protocol targeting the virtual
device address. Reads the register content via recovery protocol targeting
the virtual device address and check if it matches with what has been written.
Reads the register content through AHB/AXI and check if it matches with
what has been written.

### `write`

Test: write

Sets the TTI and recovery addresses via two SETDASA CCCs.

Performs a write to DEVICE_RESET register via the recovery
protocol targeting the virtual address. Reads the CSR content
back through AHB/AXI, checks if the transfer was successful and
the content read back matches. Then reads again the DEVICE_RESET
register, this time via the recovery protocol. Check if the content
matches.

Writes to the INDIRECT_FIFO_CTRL register using recovery protocol,
reads content of the register via AHB/AXI and verifies that their
content matches.

The test runs at core clock of 100 and 200 MHz. The slowest clock that does not result in a tSCO violation is 166 MHz.
The I3C bus clock is set to 12.5 MHz.

### `indirect_fifo_write`

Test: indirect_fifo_write

Sets the TTI and recovery addresses via two SETDASA CCCs.

Retrieves indirect FIFO status and pointers by reading
INDIRECT_FIFO_STATUS CSR over AHB/AXI bus. Writes data to the
indirect FIFO through the recovery interface and retrieves status
and pointers again. Reads the data from the FIFO back through
AHB/AXI bus, retrieves FIFO pointers. Lastly clears the indirect
FIFO by writing to INDIRECT_FIFO_CTRL through the recovery
interface and obtains the pointers again.

After each FIFO status and pointer retrieval checks if both
match the expected behavior.

The test runs at core clock of 100 and 200 MHz. The slowest clock that does not result in a tSCO violation is 166 MHz.
The I3C bus clock is set to 12.5 MHz.

### `write_pec`

Test: write_pec

Sets the TTI and recovery addresses via two SETDASA CCCs.

Writes some data to DEVICE_RESET register using the recovery
interface. Then, repeats the write with different data but
deliberately corrupts the recovery packet's checksum (PEC).
Finally, reads the content of DEVICE_RESET CSR over AHB/AXI
and ensures that it matches with what was written in the first
transfer. The test shall use random data length and value.

The test runs at core clock of 100 and 200 MHz. The slowest clock that does not result in a tSCO violation is 166 MHz.
The I3C bus clock is set to 12.5 MHz.

### `read`

Test: read

Sets the TTI and recovery addresses via two SETDASA CCCs.

Writes random data to the PROT_CAP recovery CSR via AHB/AXI.
Disables the recovery mode, writes some data to TTI TX queues
via AHB/AXI, enables the recovery mode and reads PROT_CAP using
the recovery protocol. Checks if the content matches what was
written in the beginning of the test.

The test runs at core clock of 100 and 200 MHz. The slowest clock that does not result in a tSCO violation is 166 MHz.
The I3C bus clock is set to 12.5 MHz.

### `read_short`

Test: read_short

Sets the TTI and recovery addresses via two SETDASA CCCs.

Writes random data to the PROT_CAP recovery CSR via AHB/AXI.
Disables the recovery mode, writes some data to TTI TX queues
via AHB/AXI, enables the recovery mode and reads PROT_CAP using
the recovery protocol. The I3C read transfer is deliberately
shorter - the recovery read is terminated by the I3C controller.
Checks if the content read back matches what was written in the
beginning of the test.

The test runs at core clock of 100 and 200 MHz. The slowest clock that does not result in a tSCO violation is 166 MHz.
The I3C bus clock is set to 12.5 MHz.

### `read_long`

Test: read_long

Sets the TTI and recovery addresses via two SETDASA CCCs.

Writes random data to the PROT_CAP recovery CSR via AHB/AXI.
Disables the recovery mode, writes some data to TTI TX queues
via AHB/AXI, enables the recovery mode and reads PROT_CAP using
the recovery protocol. The I3C read transfer is deliberately
longer - the recovery read is terminated by the I3C target.
Checks if the content read back matches what was written in the
beginning of the test.

The test runs at core clock of 100 and 200 MHz. The slowest clock that does not result in a tSCO violation is 166 MHz.
The I3C bus clock is set to 12.5 MHz.

### `virtual_read`

Test: virtual_read

Sets the TTI and recovery addresses via two SETDASA CCCs. Disables
the recovery mode.

Issues a series of recovery read commands to all CSRs mentioned in the
spec. The series is repeated twice - for recovery mode enabled and disabled.
Each transfer is checked if the response is ACK or NACK and in case of
ACK if PEC checksum is correct.

Checks if CSRs that should be available anytime (i.e. when the recovery
mode is off) are always accessible, checks if other CSRs are accessible
only in the recovery mode.

The test runs at core clock of 100 and 200 MHz. The slowest clock that does not result in a tSCO violation is 166 MHz.
The I3C bus clock is set to 12.5 MHz.

### `virtual_read_alternating`

Test: virtual_read_alternating

Alternates between recovery mode reads and TTI reads. Initially
sets the TTI and recovery addresses via two SETDASA CCCs.

Writes random data to the PROT_CAP register over AHB/AXI, reads
the register through the recovery protocol and check if the
content matches.

Writes data and its descriptor to TTI TX queues, issues a private
I3C read, verifies that the data read back matches.

Disables the recovery mode and repeats the recovery and TTI reads
to ensure that both TTI and recovery transfers are possible
regardless of the recovery mode setting.

The test runs at core clock of 100 and 200 MHz. The slowest clock that does not result in a tSCO violation is 166 MHz.
The I3C bus clock is set to 12.5 MHz.

### `payload_available`

Test: payload_available

Sets the TTI and recovery addresses via two SETDASA CCCs.

Ensures that initially the recovery_payload_available_o signal
is deasserted. Then writes data to the indirect FIFO via the
recovery interface and checks if the signal gets asserted.

Reads from INDIRECT_FIFO_DATA CSR over AHB/AXI and checks if the
read causes the signal to be deasserted again.

The test runs at core clock of 100 and 200 MHz. The slowest clock that does not result in a tSCO violation is 166 MHz.
The I3C bus clock is set to 12.5 MHz.

### `image_activated`

Test: image_activated

Sets the TTI and recovery addresses via two SETDASA CCCs.

Ensures that initially the image_activated_o signal is deasserted.
Writes 0xF to the 3rd byte of the RECOVERY_CTRL register using the
recovery interface. Checks if the signal gets asserted. Then writes
0xFF to the same byte of the register and checks if the signal
gets deasserted.

The test runs at core clock of 100 and 200 MHz. The slowest clock that does not result in a tSCO violation is 166 MHz.
The I3C bus clock is set to 12.5 MHz.

### `indirect_fifo_reset_access`

Test: indirect_fifo_reset_access

Sets the recovery address via SETDASA CCC.

Writes data to indirect FIFO and waits for the values to propagate
through the core.

Resets indirect FIFO and writes new data to the indirect FIFO.
Reads indirect FIFO and compares received data with one written after reset.

### `recovery_flow`

Test: recovery_flow

The test exercises firmware image transfer flow using the recovery
protocol. It consists of two agents running concurrently.

The AHB/AXI agent is responsible for recovery operation from the
system bus side. It mimics operation of the recovery handling
firmware.

The BFM agent issues I3C transactions and is responsible for pushing
a firmware image to the target.

The test runs at core clock of 100 and 200 MHz. The slowest clock that does not result in a tSCO violation is 166 MHz.
The I3C bus clock is set to 12.5 MHz.

### `ocp_csr_access`

Test: ocp_csr_access

Sets the TTI and recovery addresses via two SETDASA CCCs.

Writes to DEVICE_RESET via recovery protocol targeting the virtual
device address. Reads the register content through AHB/AXI and
check if it matches with what has been written.

Writes to all remaining recovery CSRs using AHB/AXI, reads back
their values and compares them.

### `ri_error_detection`

Test: ri_error_detection

Tests Recovery Interface error detection, interrupt status, and counters.
Validates RI_PEC_ERR (PEC/CRC error detection), RI_PROT_ERR (protocol
error detection), and associated interrupt and counter behavior.

### `ri_comprehensive_stress`

Test: ri_comprehensive_stress

Comprehensive Recovery Interface stress test covering PEC errors,
T-bit parity errors, and protocol edge cases in rapid succession.

### `ri_error_injection_stress`

Test: ri_error_injection_stress

Tests Recovery Interface resilience to various I3C framing errors and
abnormal conditions including controller-side protocol violations and
unexpected bus events.

### `ri_length_underrun`

Test: ri_length_underrun

Tests that writing to INDIRECT_FIFO_DATA with RI length field 1 byte
larger than actual data sent results in a length underrun error.

### `ri_mid_byte_stop`

Test: ri_mid_byte_stop

Tests that issuing STOP mid-byte during different phases of the RI
protocol is handled correctly. The device should detect the error
and recover gracefully.

### `ri_read_interrupted_by_ccc`

Test: ri_read_interrupted_by_ccc

Tests RI protocol error handling when the READ command's read phase is
interrupted by various bus conditions instead of the expected
Sr + Addr+R sequence.

### `chained_ri_and_ccc_commands`

Test: chained_ri_and_ccc_commands

Tests chaining of Recovery Interface commands, CCCs, and private writes
within sequences using Sr. All RI/private transfers use Sr, only CCCs
use broadcast address. Verifies correct interleaving.

### `indirect_fifo_large_write`

Test: indirect_fifo_large_write

Tests writing more than 256 bytes to the INDIRECT_FIFO via I3C
interface. The INDIRECT_FIFO has a fixed size (typically 256 bytes).
Verifies correct handling of writes that exceed capacity.

### `indirect_fifo_two_writes_overflow`

Test: indirect_fifo_two_writes_overflow

Tests two consecutive writes to the INDIRECT_FIFO that together exceed
capacity. First write fits, second write overflows. Verifies correct
handling of the overflow condition.

### `indirect_fifo_parity_error`

Test: indirect_fifo_parity_error

Tests that T-bit (parity) errors during INDIRECT_FIFO_DATA write are
handled correctly. Verifies parity errors on specific bytes are
detected and reported.

### `indirect_fifo_overflow_pointer`

Test: indirect_fifo_overflow_pointer

Tests that WRITE_INDEX does not increment when writing to a full
INDIRECT_FIFO. Fills the hardware FIFO completely and verifies
the pointer behavior on overflow.

### `write_exceeds_register_size`

Test: write_exceeds_register_size

Tests behavior when writing more data than the register size allows.
Attempts to write excess bytes to a recovery CSR and verifies
correct handling.

### `private_read_and_ri_read`

Test: private_read_and_ri_read

Verifies that a recovery interface PROT_CAP read and a standard private
read from the TTI TX FIFO work correctly and do not interfere with
each other.

### `parity_error_isolation`

Test: parity_error_isolation

Verifies that parity/PEC errors on RI writes do not leak into the TTI
interrupt path, and that T-bit errors on normal target writes do
produce the expected TTI interrupts.

### `recovery_readonly_write_error`

Test: recovery_readonly_write_error

Coverage: recovery_handler readonly_err=1, unsupported_err=0.
Sends WRITE commands to read-only registers (PROT_CAP, DEVICE_ID,
DEVICE_STATUS, HW_STATUS) and verifies PROT_ERROR=READONLY.
Also tests readonly_err_det_en toggle for suppression.

### `recovery_read_write_phase_parity`

Test: recovery_read_write_phase_parity

Coverage: RxLenH parity error on write-phase PEC.
Sends a recovery READ command with a T-bit parity error on the PEC byte
of the write phase. Recovery receiver detects error in RxLenH and
transitions to Error.

### `recovery_write_pec_tbit_error`

Test: recovery_write_pec_tbit_error

Coverage: RxPec parity error on descriptor.
Sends a recovery WRITE command where the PEC byte has a T-bit parity
error. Verifies the error is detected in RxPec state.

### `recovery_write_pec_overflow`

Test: recovery_write_pec_overflow

Send a recovery WRITE command with more than one PEC bytes with
length_err_det_en_i enabled and disabled.

### `recovery_all_det_en_toggle`

Test: recovery_all_det_en_toggle

Coverage: Toggle all *_det_en_i signals.
For each error detection enable bit in TARGET_ERR_CTRL: disable det_en
and trigger error (verify not flagged), enable det_en and trigger error
(verify flagged).

### `recovery_read_abort_at_len`

Test: recovery_read_abort_at_len

Coverage: TxLenL/TxLenH bus_rstart_i -> Done.
Aborts a recovery READ at different points in the response length
transmission using command_read_abort.

### `recovery_premature_sr_in_header`

Test: recovery_premature_sr_in_header

Coverage: Premature stop in RxCmd/RxLenL via bus_rstart_i.
Sends partial recovery command headers with Sr at unexpected points
during RxCmd and RxLenL states.

### `recovery_queue_resets`

Test: recovery_queue_resets

Coverage: Toggle reg_rst_i, reg_rst_we_o, reg_rst_data_o on all queues.
Exercises all RESET_CONTROL queue reset bits to toggle the reg_rst
signals on every queue (IBI, RX desc, RX data, TX data).

### `recovery_hdr_mode_abort`

Test: recovery_hdr_mode_abort

Coverage: in_hdr_mode_i override -> Error.
Triggers TE0 error during an active recovery transaction to force
in_hdr_mode_i=1 while the recovery FSM is in an active state.
Recovers via HDR exit.

### `recovery_length_det_en_toggle`

Test: recovery_length_det_en_toggle

Coverage: length error detection enable combinations.
Tests length_err_det_en=0 (error suppressed), length_err_det_en=1
with underrun (error detected), and correct length (no error).

### `recovery_queue_thresholds`

Test: recovery_queue_thresholds

Coverage: Toggle threshold input signals on all queues.
Writes non-default values to QUEUE_THLD_CTRL and DATA_BUFFER_THLD_CTRL
to toggle start_thrld_i and ready_thrld_i on all queues.

### `recovery_write_premature_stop_in_data`

Test: recovery_write_premature_stop_in_data

Coverage: Premature stop in RxData and RxPec with length underrun.
Sends a recovery WRITE with premature STOP during data or PEC phase,
verifying correct error handling.

### `recovery_read_premature_start_in_pec`

Test: recovery_read_premature_start_in_pec

Coverage: Premature Sr in TxPec.
Sends a recovery read with premature Start during PEC phase.

### `recovery_indirect_fifo_overflow`

Test: recovery_indirect_fifo_overflow

Coverage: Toggle indirect_fifo_overflow_err_det_en_i and
rx_fifo_overflow_err_det_en_i.
Writes more data to INDIRECT_FIFO_DATA than the FIFO can hold to
trigger overflow, with det_en toggled.

### `recovery_ibi_queue_full`

Test: recovery_ibi_queue_full

Coverage: Toggle ibi_queue.full_o.
Fills the IBI queue (depth=64) by writing MDB-only IBI descriptors
without triggering IBI acceptance. Verifies queue fills and device
remains functional after reset.

### `recovery_bypass_fifo_done`

Test: recovery_bypass_fifo_done

Coverage: Bypass path to Done in ExecFifoWrite.
Enables bypass mode, writes data to INDIRECT_FIFO via recovery
interface, then asserts REC_PAYLOAD_DONE to trigger the bypass
exit path from ExecFifoWrite.

### `recovery_hdr_abort_per_state`

Test: recovery_hdr_abort_per_state

Coverage: in_hdr_mode_i Error from ExecCsrWrite, TxData, TxLenH,
TxLenL, TxPec.
Uses TE0 injection to force the recovery FSM into Error from specific
Tx states during READ responses.

### `recovery_read_abort_txlenl`

Test: recovery_read_abort_txlenl

Coverage: TxLenL bus_rstart_i -> Done.
Sends Sr immediately after the read address ACK, before the target
finishes transmitting the LEN_L byte.

### `recovery_bypass_fifo_race`

Test: recovery_bypass_fifo_race

Coverage: Bypass ExecFifoWrite -> Done.
Enables bypass mode, sends a large INDIRECT_FIFO_DATA write via I3C,
then races to set REC_PAYLOAD_DONE via CSR before the normal dcnt
path completes.

### `recovery_readonly_write_irq`

Test: recovery_readonly_write_irq

Verifies that writing to a read-only recovery register triggers the
RI_READONLY_ERR interrupt output (irq_o toggle 0->1->0).

### `recovery_unsupported_cmd_irq`

Test: recovery_unsupported_cmd_irq

Verifies that sending an unsupported command code triggers the
RI_UNSUPPORTED_ERR interrupt output (irq_o toggle 0->1->0).

### `recovery_tx_pec_csr_data_race`

Test: recovery_tx_pec_csr_data_race

PEC coherency under concurrent FW CSR writes. FW toggles
RECOVERY_STATUS every few clocks in the background while
the controller performs reads of the same register via I3C.
Verifies that PEC is always correct despite concurrent AXI
writes, proving csr_data snapshot integrity.
Spec ref: OCP Recovery v1.1 Section 8.4.

### `recovery_ri_csr_concurrent_stress`

Test: recovery_ri_csr_concurrent_stress

Stress test: concurrent random FW (AXI) and I3C accesses to
recovery interface CSRs. FW randomly reads/writes RI CSRs via
AXI in the background while I3C performs random read/write
operations via the recovery protocol. Every I3C read checks
PEC, data length, and NACK status. Exposes data races,
coherency bugs, or FSM hangs under concurrent access.


# Recovery bypass

## Testpoints

### `simple_write_read`

Test: indirect_fifo_write

Verify basic bypass functionality
- Enable I3C Core bypass in the Recovery Handler via CSR
- Write to the TTI TX Data Queue and read from the Indirect FIFO Queue
- Compare the data and verify it hasn't changed

### `check_csr_access`

Tests:
- ocp_csr_access_bypass_enabled- ocp_csr_access_bypass_disabled

Verify accessibility of CSRs as specified in the OCP Secure Firmware Recovery
specification with additional bypass features
- Write to all RW and read from all RO Secure Firmware Recovery Registers
- Write to bypass registers with W1C property
- Ensure the reserved fields of tested registers were not written
- Ensure RW registers can be written and read back
- Ensure RO registers cannot be written
- Perform checks with bypass disabled and enabled

### `recovery_status_wires`

Tests:
- payload_available- image_activated

Verify recovery status wires as specified in the Caliptra SS Hardware Specification
- Write to the TTI TX Queue and read from the Indirect FIFO Queue.
- Ensure correct state of the `payload_available` wire
- Write to the Recovery Control CSR to activate an image
- Ensure correct state of the `image_activated` wire

### `indirect_fifo_overflow`

Test: indirect_fifo_overflow

Verify that access is rejected when the Indirect FIFO Queue overflows

### `indirect_fifo_underflow`

Test: indirect_fifo_underflow

Verify that access is rejected when the Indirect FIFO Queue underflows

### `i3c_bus_traffic_during_loopback`

Test: i3c_bus_traffic_during_loopback

Verify that the Recovery Handler with bypass enabled is not in any way interfered by any
I3C bus traffic

### `check_axi_filtering`

Test: axi_filtering

Verify that AXI access to Secure Firmware Recovery registers is filtered
- AXI IDs from the privileged ID list should always grant access to all registers
- Once ID filtering is disabled, register access should be granted regardless of the
  transaction ID
- With ID filtering enabled, all transactions with ID outside of the privileged ID list
  should be rejected with SLVERR response and register access request should not be
  propagated to the CPUIF

### `bypass_read`

Test: read

Verify basic read functionality through recovery bypass
- Enable I3C Core bypass in the Recovery Handler via CSR
- Read from a recovery CSR via the bypass path
- Verify data integrity

### `cptra_mcu_recovery`

Test: recovery_flow

Verify that Caliptra Subsystem can perform a full Recovery Sequence with the I3C Core with
the bypass feature enabled. This test will run software on both Caliptra core and Caliptra
MCU to interact with the I3C Core and Caliptra RoT.
- MCU should initialize the I3C Core with bypass enabled
- Caliptra ROM should enable Recovery Mode
- MCU should load the image to the Indirect FIFO Queue which will be read by Caliptra ROM
- MCU should activate the image
- Caliptra ROM should write the image to the MCU SRAM
- The image should be identical with the one read form a simulated QSPI

### `bypass_to_i3c_switch`

Test: bypass_to_normal_mode_switch

Boot the core in bypass mode and perform AXI recovery flow. During AXI recovery
send random I3C traffic and assert all I3C packets are NACKed. 
Switch to I3C mode and send regular I3C traffic, make sure it is handled correctly.
The test should cover corner cases where the switch happens in the middle of an I3C transaction.


# target_peripheral_reset

## Testpoints

### `target_peripheral_reset`

Test: target_peripheral_reset

Issues I3C target reset pattern and verifies successful peripheral reset.

### `target_escalated_reset`

Test: target_escalated_reset

Issues I3C target reset patterns and verifies successful reset escalation.

### `reset_at_min_timing`

Test: reset_at_min_timing

Valid reset at exact spec minimum timing (tDIG_H = 140ns). Tests the
target reset detector when the bus operates at the minimum timing
thresholds specified in the I3C specification.

### `13_transitions_fails`

Test: 13_transitions_fails

Only 13 SDA transitions should NOT trigger reset. The spec requires
exactly 14 SDA transitions. With only 13, the FSM should remain in
AwaitPattern and not trigger a reset.

### `15_transitions_before_scl`

Test: 15_transitions_before_scl

15 SDA transitions before SCL rise should NOT trigger reset. Extra
transitions beyond 14 while SCL is still low should prevent the
pattern from being recognized.

### `scl_glitch_during_pattern`

Test: scl_glitch_during_pattern

SCL goes high briefly during SDA transitions. When SCL goes stable
high during the 14 SDA transitions, the transition counter should
reset and pattern recognition should fail.

### `scl_glitch_during_pattern_final_edge`

Test: scl_glitch_during_pattern_final_edge

SCL goes high together with the 14th SDA transition. This way, the
reset detector FSM should already move to the AwaitSCL state, but then
immediately detect SCL being stable high due to the posedge occuring
too early, which should reset it to the default state and pattern
recognition should fail.

### `sda_stable_low_during_await_scl`

Test: sda_stable_low_during_await_scl

SDA goes stable low while waiting for SCL rise. In AwaitSCL state,
if SDA becomes stable low, FSM should abort back to AwaitPattern.

### `scl_drops_during_await_sr`

Test: scl_drops_during_await_sr

SCL goes low before START condition detected. In AwaitSr state, if
SCL becomes stable low before START is detected, FSM should abort
back to AwaitPattern.

### `scl_drops_during_await_p`

Test: scl_drops_during_await_p

SCL goes low before STOP condition detected. In AwaitP state, if
SCL becomes stable low before STOP is detected, FSM should abort
back to AwaitPattern.

### `back_to_back_resets`

Test: back_to_back_resets

Multiple valid resets in succession. Verifies that the FSM returns
cleanly to initial state after reset and can detect subsequent
reset patterns.

### `reset_after_failed_pattern`

Test: reset_after_failed_pattern

Verifies FSM recovers after a failed pattern and can detect subsequent
valid reset patterns.

### `first_edge_must_be_falling`

Test: first_edge_must_be_falling

Pattern counting starts on negative edge. Per FSM logic, the first
counted transition must be a falling edge. Starting with a rising edge
should not be counted.

### `timing_at_2x_minimum`

Test: timing_at_2x_minimum

Verifies reset detection works at 2x minimum timing (more relaxed
timing). Serves as a sanity check that the detector is not too strict.

### `very_fast_timing_below_spec`

Test: very_fast_timing_below_spec

Test with timing faster than spec minimum (aggressive timing). Tests
if the detector can keep up with fast transitions.

### `mixed_valid_and_invalid_patterns`

Test: mixed_valid_and_invalid_patterns

Sends a mix of valid and invalid patterns to stress the FSM
transitions and verify correct behavior under varied conditions.


# Target error detection

## Testpoints

### `te0_errors`

Test: [te0_errors](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_i3c_target.py)

TE0 error: reserved broadcast address triggers HDR error mode and
recovery. Tests all 8 reserved address patterns, both recovery methods
(HDR exit and timeout).
Ensures that CSR with error counter does not overflow.

### `te1_errors`

Test: [te1_errors](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_i3c_target.py)

TE1 error: CCC parity error triggers HDR error mode and recovery.
Tests various broadcast CCCs with bad T-bit parity, both recovery
methods, and ENTHDR0-specific behavior.
Ensures that CSR with error counter does not overflow.

### `te2_private_write_parity`

Test: [te2_private_write_parity](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_i3c_target.py)

TE2 error: bad T-bit parity on private write data causes data to be
discarded. Verifies RX FIFO is empty after parity error, error
registers update, and target recovers for subsequent transfers.
Ensures that CSR with error counter does not overflow.

### `te_error_registers_sweep`

Test: [te_error_registers_sweep](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_i3c_target.py)

Register infrastructure test: FORCE->STATUS, W1C, counter saturation,
ENABLE gating, and multi-bit FORCE. No bus traffic -- pure register
verification of the error detection infrastructure.

### `controller_abort_scenarios`

Test: [controller_abort_scenarios](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_i3c_target.py)

Controller abort during private write/read at random positions.
Verifies the target remains functional after aborted transactions.

### `te_error_sequence_mixing`

Test: [te_error_sequence_mixing](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_i3c_target.py)

Cross-coverage: inject TE0, TE1, TE2 in random order with recovery.
Verifies that each error type is correctly detected and only the
corresponding status/counter is updated.

### `te_error_ri_isolation`

Test: [te_error_ri_isolation](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_i3c_target.py)

Verifies TE errors do not corrupt RI path and vice versa.
Phase 1: TE0 error -> recover -> verify normal TTI traffic works.
Phase 2: Normal traffic after RI transfer -> verify no TE errors.

### `te_counter_per_event`

Test: [te_counter_per_event](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_i3c_target.py)

Verifies TE0/TE1 error counters increment exactly once per single
error event. TE0 fires once per corrupted address header. TE1 fires
once per CCC byte with bad parity.

### `te0_during_ccc_repeated_start`

Test: [te0_during_ccc_repeated_start](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_i3c_target.py)

Coverage: i3c_target_fsm.sv in_hdr_mode_i override from CheckSByte.
Trigger TE0 from RxSByteRepeated state via S+7E/W -> ACK -> Sr -> 7E/R.
FSM enters CheckSByte then transitions to InHDRMode via in_hdr_mode_i
override. Recovers via HDR timeout.

### `ri_interrupt_force_all`

Test: [ri_interrupt_force_all](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_i3c_target.py)

Tests interrupt FORCE mechanism for all RI error interrupt instances.
For each RI error type (readonly, unsupported, rx_fifo_overflow,
indirect_fifo_overflow): disable interrupt and force (verify no effect),
enable and force (verify status set and irq_o high), clear and verify
irq_o low.

### `ri_rx_fifo_overflow_irq`

Test: [ri_rx_fifo_overflow_irq](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_i3c_target.py)

Verifies that RX FIFO overflow triggers the RI_RX_FIFO_OVERFLOW_ERR
interrupt output (irq_o toggle 0->1->0) when both DET_EN and INTR_EN
are enabled.

### `ri_indirect_fifo_overflow_irq`

Test: [ri_indirect_fifo_overflow_irq](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_i3c_target.py)

Verifies that INDIRECT FIFO overflow triggers the
RI_INDIRECT_FIFO_OVERFLOW_ERR interrupt output (irq_o toggle 0->1->0)
when both DET_EN and INTR_EN are enabled.

### `error_counters_saturation`

Tests:
- [te5_counter_saturation](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_i3c_target.py)- [framing_counter_saturation](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_i3c_target.py)- [ri_pec_counter_saturation](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_i3c_target.py)- [ri_length_counter_saturation](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_i3c_target.py)- [ri_readonly_counter_saturation](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_i3c_target.py)- [ri_unsupported_counter_saturation](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_i3c_target.py)- [ri_rx_fifo_overflow_counter_saturation](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_i3c_target.py)- [ri_indirect_fifo_overflow_counter_saturation](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_i3c_target.py)

Writes 0xFE to error counter, triggers errors and ensures that
the counter increments without overflowing.
The tests cover counters for:
- TE5
- FRAMING
- RI_PEC
- RI_LENGTH
- RI_READONLY
- RI_UNSUPPORTED
- RI_RX_FIFO_OVERFLOW
- RI_INDIRECT_FIFO_OVERFLOW


# tSCO timing verification

## Testpoints

### `tsco_write_ack_handoff`

Test: tsco_write_ack_handoff

PROSECUTOR TEST: Verifies tSCO timing on write-ACK handoff.
Per I3C spec S5.1.2.3.1 step 2 and Table 87, after the target sees the
rising edge of SCL during ACK, it shall release SDA to Hi-Z within tSCO
(max 12ns). Sends a private write and measures tSCO on the ACK handoff.

### `tsco_setdasa_virtual_target`

Test: tsco_setdasa_virtual_target

PROSECUTOR TEST: Verifies tSCO timing on SETDASA to virtual target.
The bus monitor has detected a tSCO violation specifically during
SETDASA directed to the virtual target address. Measures tSCO during
that specific transaction.



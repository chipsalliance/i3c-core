# Target

[Test results](./sim-results/target.html){.external}

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

### `i3c_target_read_empty`

Test: [i3c_target_read_empty](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_i3c_target.py)

Issues multiple read transactions to the target and randomly selects,
which if transaction has data.

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


# Data over-/underflow handling

[Test results](./sim-results/target_bus_stall.html){.external}

## Testpoints

### `Reading from empty RX descriptor FIFO`

Test: [empty_rx_desc_read](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_bus_stall.py)

Perform read bus access to the empty RX descriptor queue,
verify that response comes back and it holds value of 0.

### `Reading from empty RX data FIFO`

Test: [empty_rx_data_read](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_bus_stall.py)

Perform read bus access to the empty RX descriptor queue,
verify that response comes back and it holds value of 0.

### `Reading from empty indirect FIFO`

Test: [empty_indirect_fifo_read](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_bus_stall.py)

Perform read bus access to the empty RX descriptor queue,
verify that response comes back and it holds value of 0.

### `Writing to full TX descriptor FIFO`

Test: [full_tx_desc_write](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_bus_stall.py)

Perform multiple write bus accesses to the TX descriptor queue,
verify that all transactions has finished.

### `Writing to full TX data FIFO`

Test: [full_tx_data_write](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_bus_stall.py)

Perform multiple write bus accesses to the TX data queue,
verify that all transactions has finished.

### `Writing to full IBI FIFO`

Test: [full_ibi_write](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_bus_stall.py)

Perform multiple write bus accesses to the IBI queue,
verify that all transactions has finished.


# CCC handling

[Test results](./sim-results/target_ccc.html){.external}

## Testpoints

### `ccc_getstatus`

Test: [ccc_getstatus](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ccc.py#L57)

The test reads PENDING_INTERRUPT field from the TTI INTERRUPT
status CSR. Next, it issues the GETSTATUS directed CCC to the
target. Finally it compares the interrupt status returned by the
CCC with the one read from the register.

### `ccc_setdasa`

Test: [ccc_setdasa](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ccc.py#L93)

The test sets dynamic address and virtual dynamic address by
sending SETDASA CCC. Then it verifies that correct addresses have
been set by reading STBY_CR_DEVICE_ADDR CSR.
The test also sends a random number of CCCs targeting devices other
than DUT, and checks if the dynamic address was not accepted.

### `ccc_setdasa_nack`

Test: [ccc_setdasa_nack](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ccc.py#L174)

The test sets dynamic address and virtual dynamic address by
sending SETDASA CCC. Then it sends second SETDASA command and checks
that targets NACKed them.

### `ccc_setnewda`

Test: [ccc_setnewda](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ccc.py#L215)

The test sets dynamic address and virtual dynamic address directly
using CSR accesses. Then it sends SETNEWDA commands to both targets
and checks their dynamic addresses got updated.

### `ccc_rstdaa`

Test: [ccc_rstdaa](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ccc.py#L283)

Sets dynamic address via STBY_CR_DEVICE_ADDR CSR, then sends
RSTDAA CCC and verifies that the address got cleared.

### `ccc_getbcr`

Test: [ccc_getbcr](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ccc.py#L360)

Reads BCR register content by sending GETBCR CCC and examining
returned data.

### `ccc_getdcr`

Test: [ccc_getdcr](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ccc.py#L392)

Reads DCR register content by sending GETDCR CCC and examining
returned data.

### `ccc_getmwl`

Test: [ccc_getmwl](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ccc.py#L422)

Reads MWL register content by sending GETMWL CCC and examining
returned data.

### `ccc_getmrl`

Test: [ccc_getmrl](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ccc.py#L439)

Reads MRL register content by sending GETMWL CCC and examining
returned data.

### `ccc_setaasa`

Test: [ccc_setaasa](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ccc.py#L457)

Issues the broadcast SETAASA CCC and checks if the target uses
its static address as dynamic by examining STBY_CR_DEVICE_ADDR
CSR.

### `ccc_setaasa_ignore`

Test: [ccc_setaasa_ignore](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ccc.py#L500)

Assigns dynamic address different to static address using CSR.
Issues the broadcast SETAASA CCC and checks if the target ignores
this command by examining STBY_CR_DEVICE_ADDR CSR.

### `ccc_getpid`

Test: [ccc_getpid](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ccc.py#L550)

Sends the CCC to the target and examines if the returned PID
matches the expected.

### `ccc_enec_disec_direct`

Test: [ccc_enec_disec_direct](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ccc.py#L610)

Sends DISEC CCC to the target and verifies that events are disabled.
Then, sends ENEC CCC to the target and checks that events are enabled.

### `ccc_enec_disec_bcast`

Test: [ccc_enec_disec_bcast](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ccc.py#L643)

Sends broadcast DISEC CCC and verifies that events are disabled.
Then, sends broadcast ENEC CCC and checks that events are enabled.

### `ccc_setmwl_direct`

Test: [ccc_setmwl_direct](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ccc.py#L672)

Sends directed SETMWL CCC to the target and verifies that the
register got correctly set. The check is performed by examining
relevant wires in the target DUT.

### `ccc_setmrl_direct`

Test: [ccc_setmrl_direct](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ccc.py#L690)

Sends directed SETMRL CCC to the target and verifies that the
register got correctly set. The check is performed by examining
relevant wires in the target DUT.

### `ccc_setmwl_bcast`

Test: [ccc_setmwl_bcast](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ccc.py#L708)

Sends broadcast SETMWL CCC and verifies that the
register got correctly set. The check is performed by examining
relevant wires in the target DUT.

### `ccc_setmrl_bcast`

Test: [ccc_setmrl_bcast](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ccc.py#L726)

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

Test: [ccc_direct_multiple_wr](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ccc.py#L800)

Sends a sequence of multiple directed SETMWL CCCs. The first and
the last have non-matching address. The two middle ones set MWL
to different values. Verify that the target responded to correct
addresses and executed both CCCs.

### `ccc_direct_multiple_rd`

Test: [ccc_direct_multiple_rd](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ccc.py#L839)

Sends SETMWL CCC. Then sends multiple directed GETMWL CCCs to
thee different addresses. Only the one for the target should
be ACK-ed with the correct MWL content.


# CSR access check

[Test results](./sim-results/target_csr_access.html){.external}

## Testpoints

### `Test CSR accesses`

Tests:
- [dat_csr_access](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_csr_access.py#L120)
- [dct_csr_access](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_csr_access.py#L126)
- [base_csr_access](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_csr_access.py#L135)
- [pio_csr_access](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_csr_access.py#L156)
- [ec_sec_fw_rec_csr_access](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_csr_access.py#L169)
- [ec_stdby_ctrl_mode_csr_access](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_csr_access.py#L179)
- [ec_tti_csr_access](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_csr_access.py#L270)
- [ec_soc_mgmt_csr_access](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_csr_access.py#L320)
- [ec_contrl_config_csr_access](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_csr_access.py#L327)
- [ec_csr_access](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_csr_access.py#L333)


Walks over all CSRs, write random value using AHB/AXI, reads it back,
and compares with expected output.


# Target error detection

[Test results](./sim-results/target_error_detection.html){.external}

## Testpoints

### `Detect target error condition 0`

Tests:
- [TE0_HDR_exit](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_err_conds.py#L61)
- [TE0_idle_exit](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_err_conds.py#L105)


Issues I3C transaction with address set to broadcast address with single
bit error.
Checks target FSM transitioned to WaitHDRExitOrIdle.
Either sends HDR exit pattern or waits 60us and checks that target
is back to Idle state.

### `Detect target error condition 1`

Tests:
- [TE1_HDR_exit](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_err_conds.py#L149)
- [TE1_idle_exit](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_err_conds.py#L188)


Issues I3C CCC transaction with invalid T-bit.
Checks target FSM transitioned to WaitHDRExitOrIdle.
Either sends HDR exit pattern or waits 60us and checks that target
is back to Idle state.

### `Detect target error condition 5`

Tests:
- [TE5_read_on_write](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_err_conds.py#L227)
- [TE5_write_on_read](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_err_conds.py#L263)


Issues one of the CCC that is either read-only, or write-only.
Issues target address with incorrect direction bit.
Checks that target NACKed transaction.


# Enter and exit HDR mode

[Test results](./sim-results/target_hdr.html){.external}

## Testpoints

### `Enter and exit HDR-DDR mode`

Tests:
- [enter_exit_hdr_mode_write](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_enter_exit_hdr_mode.py#L56)
- [enter_restart_exit_hdr_mode_write](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_enter_exit_hdr_mode.py#L112)
- [enter_exit_hdr_mode_read](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_enter_exit_hdr_mode.py#L172)
- [enter_restart_exit_hdr_mode_read](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_enter_exit_hdr_mode.py#L232)


Issues ENTHDR0 CCC to the target, verifies that the target FSM
is in IdleHDR state. Issues at least 1 read/write HDR-DDR command(s)
followed by HDR exit pattern, verifies that
the target FSM is back in Idle state.


# Target interrupts

[Test results](./sim-results/target_interrupts.html){.external}

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


# Recovery mode tests

[Test results](./sim-results/target_recovery.html){.external}

## Testpoints

### `virtual_write`

Test: [virtual_write](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_recovery.py#L194)

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

Test: [virtual_overwrite](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_recovery.py#L121)

Tests CSR write(s) with lengths over CSR size to the virtual
address using recovery protocl.

Performs a write to on of DEVICE_RESET/RECOVERY_CTRL/INDIRECT_FIFO_CTRL
registers via the recovery protocol targeting the virtual address.
Reads the CSR content back through AHB/AXI. Then reads again
the selected register, this time via the recovery protocol.
Check if the content matches value stored in the register.

### `virtual_write_alternating`

Test: [virtual_write_alternating](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_recovery.py#L304)

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

Test: [read_fifo_ctrl](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_recovery.py#L440)

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

Test: [write](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_recovery.py#L372)

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

Test: [indirect_fifo_write](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_bypass.py#L96)

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

Test: [write_pec](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_recovery.py#L635)

Sets the TTI and recovery addresses via two SETDASA CCCs.

Writes some data to DEVICE_RESET register using the recovery
interface. Then, repeats the write with different data but
deliberately corrupts the recovery packet's checksum (PEC).
Finally, reads the content of DEVICE_RESET CSR over AHB/AXI
and ensures that it matches with what was written in the first
transfer.

The test runs at core clock of 100 and 200 MHz. The slowest clock that does not result in a tSCO violation is 166 MHz.
The I3C bus clock is set to 12.5 MHz.

### `read`

Test: [read](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_bypass.py#L230)

Sets the TTI and recovery addresses via two SETDASA CCCs.

Writes random data to the PROT_CAP recovery CSR via AHB/AXI.
Disables the recovery mode, writes some data to TTI TX queues
via AHB/AXI, enables the recovery mode and reads PROT_CAP using
the recovery protocol. Checks if the content matches what was
written in the beginning of the test.

The test runs at core clock of 100 and 200 MHz. The slowest clock that does not result in a tSCO violation is 166 MHz.
The I3C bus clock is set to 12.5 MHz.

### `read_short`

Test: [read_short](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_recovery.py#L778)

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

Test: [read_long](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_recovery.py#L844)

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

Test: [virtual_read](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_recovery.py#L969)

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

Test: [virtual_read_alternating](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_recovery.py#L1055)

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

Test: [payload_available](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_bypass.py#L362)

Sets the TTI and recovery addresses via two SETDASA CCCs.

Ensures that initially the recovery_payload_available_o signal
is deasserted. Then writes data to the indirect FIFO via the
recovery interface and checks if the signal gets asserted.

Reads from INDIRECT_FIFO_DATA CSR over AHB/AXI and checks if the
read causes the signal to be deasserted again.

The test runs at core clock of 100 and 200 MHz. The slowest clock that does not result in a tSCO violation is 166 MHz.
The I3C bus clock is set to 12.5 MHz.

### `image_activated`

Test: [image_activated](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_bypass.py#L426)

Sets the TTI and recovery addresses via two SETDASA CCCs.

Ensures that initially the image_activated_o signal is deasserted.
Writes 0xF to the 3rd byte of the RECOVERY_CTRL register using the
recovery interface. Checks if the signal gets asserted. Then writes
0xFF to the same byte of the register and checks if the signal
gets deasserted.

The test runs at core clock of 100 and 200 MHz. The slowest clock that does not result in a tSCO violation is 166 MHz.
The I3C bus clock is set to 12.5 MHz.

### `indirect_fifo_reset_access`

Test: [indirect_fifo_reset_access](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_recovery.py#L1272)

Sets the recovery address via SETDASA CCC.

Writes data to indirect FIFO and waits for the values to propagate
through the core.

Resets indirect FIFO and writes new data to the indirect FIFO.
Reads indirect FIFO and compares received data with one written after reset.

### `recovery_flow`

Test: [recovery_flow](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_bypass.py#L562)

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

Test: [ocp_csr_access](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_recovery.py#L1540)

Sets the TTI and recovery addresses via two SETDASA CCCs.

Writes to DEVICE_RESET via recovery protocol targeting the virtual
device address. Reads the register content through AHB/AXI and
check if it matches with what has been written.

Writes to all remaining recovery CSRs using AHB/AXI, reads back
thier values and compares them.


# Recovery bypass

[Test results](./sim-results/target_recovery_bypass.html){.external}

## Testpoints

### `simple_write_read`

Test: [indirect_fifo_write](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_bypass.py#L96)

Verify basic bypass functionality
- Enable I3C Core bypass in the Recovery Handler via CSR
- Write to the TTI TX Data Queue and read from the Indirect FIFO Queue
- Compare the data and verify it hasn't changed

### `check_csr_access`

Tests:
- [ocp_csr_access_bypass_enabled](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_bypass.py#L1009)
- [ocp_csr_access_bypass_disabled](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_bypass.py#L1014)


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
- [payload_available](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_bypass.py#L362)
- [image_activated](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_bypass.py#L426)


Verify recovery status wires as specified in the Caliptra SS Hardware Specification
- Write to the TTI TX Queue and read from the Indirect FIFO Queue.
- Ensuring correct state of the `payload_available` wire
- Write to the Recovery Control CSR to activate an image
- Ensure correct state of the `image_activated` wire

### `indirect_fifo_overflow`

Test: [indirect_fifo_overflow](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_bypass.py#L183)

Verify that access is rejected when the Indirect FIFO Queue overflows

### `indirect_fifo_underflow`

Test: [indirect_fifo_underflow](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_bypass.py#L208)

Verify that access is rejected when the Indirect FIFO Queue underflows

### `i3c_bus_traffic_during_loopback`

Test: [i3c_bus_traffic_during_loopback](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_bypass.py#L477)

Verify that Recovery Handler with bypass enabled is not in any way interfered by any
I3C bus traffic

### `check_axi_filtering`

Test: [axi_filtering](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_bypass.py#L819)

Verify that AXI access to Secure Firmware Recovery registers is filtered
- AXI IDs from privileged ID list should always grant access to all registers
- Once ID filtering is disabled, register access should be granted regardless of the
  transaction ID
- With ID filtering enabled, all transactions with ID outside of the privileged ID list
  should be rejected with SLVERR response and register access request should not be
  propagated to the CPUIF

### `recovery_flow`

Test: [recovery_flow](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_bypass.py#L562)

Verify that Recovery Handler with bypass enabled can perform full Recovery Sequence
as specified in the Caliptra Root of Trust specification

### `cptra_mcu_recovery`

Test: [cptra_mcu_recovery](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_bypass.py)

Verify that Caliptra Subsystem can perform full Recovery Sequence with I3C Core with
bypass feature enabled. This test will run software on both Caliptra core and Caliptra
MCU to interact with the I3C Core and Caliptra RoT.
- MCU should initialize I3C Core with bypass enabled
- Caliptra ROM should enable Recovery Mode
- MCU should load image to Indirect FIFO Queue which will be read by Caliptra ROM
- MCU should activate an image
- Caliptra ROM should write an image to MCU SRAM
- The image should be identical with the one read form simulated QSPI


# target_peripheral_reset

[Test results](./sim-results/target_reset.html){.external}

## Testpoints

### `target_peripheral_reset`

Test: [target_peripheral_reset](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_target_reset.py#L69)

Issues I3C target reset pattern and verifies successful peripheral reset.

### `target_escalated_reset`

Test: [target_escalated_reset](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_target_reset.py#L76)

Issues I3C target reset patterns and verifies successful reset escalation.



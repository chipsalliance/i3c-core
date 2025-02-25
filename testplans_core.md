# Target

[Source file](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_i3c_target.py)

[Test results](./sim-results/target.html){.external}

## Testpoints

### `i3c_target_write`

Test: [`i3c_target_write`](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_i3c_target.py#L105)

Spawns a TTI agent that reads from TTI descriptor and data queues
and stores received data.

While the agent is running the test issues several private writes
over I3C. Data sent over I3C is compared with data received by
the agent.

The test runs at core clock of 100 and 200 MHz. The slowest clock that does not result in a tSCO violation is 166 MHz.
The I3C bus clock is set to 12.5 MHz

### `i3c_target_read`

Test: [`i3c_target_read`](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_i3c_target.py#L196)

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
The I3C bus clock is set to 12.5 MHz

### `i3c_target_ibi`

Test: [`i3c_target_ibi`](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_i3c_target.py#L299)

Writes an IBI descriptor to the TTI IBI queue. Waits until the
controller services the IBI. Checks if the mandatory byte (MDB)
matches on both sides.

Reads the LAST_IBI_STATUS fiels of the TTI STATUS CSR. Ensures
that it is equal to 0 (no error).

Writes an IBI descriptor followed by N bytes of data to the TTI
IBI queue. Waits until the controller services the IBI. Checks if
the mandatory byte (MDB) and data matches on both sides.

Repeats the LAST_IBI_STATUS check

The test runs at core clock of 100 and 200 MHz. The slowest clock that does not result in a tSCO violation is 166 MHz.
The I3C bus clock is set to 12.5 MHz

### `i3c_target_ibi_retry`

Test: [`i3c_target_ibi_retry`](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_i3c_target.py#L392)

Disables ACK-ing IBIs in the I3C controller model, issues an ibi
from the target by writing to TTI IBI queue. Waits for a fixed
time period - sufficiently long for the target to retry sending
the IBI, reads LAST_IBI_STATUS from the TTI STATUS CSR, check
if it is set to 3 (IBI retry).

Re-enables ACK-ing of IBIs in the controller model, waits for the
model to service the IBI, compares the IBI mandatory byte (MDB)
with the one written to the TTI queue. Reads LAST_IBI_STATUS from
the TTI STATUS CSR, check if it is set to 0 (no error).

The test runs at core clock of 100 and 200 MHz. The slowest clock that does not result in a tSCO violation is 166 MHz.
The I3C bus clock is set to 12.5 MHz

### `i3c_target_ibi_data`

Test: [`i3c_target_ibi_data`](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_i3c_target.py#L470)

Sets a limit on how many IBI data bytes may be accepted in the
controller model. Issues an IBI with more data bytes by writing
to the TTI IBI queue, checks if the IBI gets serivced correctly,
compares data.

Issues another IBI with data payload within the set limit, checks
if it gets serviced correctly, compares data.

The test runs at core clock of 100 and 200 MHz. The slowest clock that does not result in a tSCO violation is 166 MHz.
The I3C bus clock is set to 12.5 MHz

### `i3c_target_writes_and_reads`

Test: [`i3c_target_writes_and_reads`](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_i3c_target.py#L541)

Writes a randomized data chunk to the TTI TX data queue, writes
a corresponding descriptor to the TTI TX descriptor queue.

Issues private write transfers to the target with randomized
payloads, waits until a TTI interrupt is set by polling TTI
INTERRUPT_STATUS CSR. Reads received data from TTI RX queues,
compares it with what has been sent.

Does a private read transfer, compares if the received data equals
the data written to TTI TX queue in the beginning of the test.

The test runs at core clock of 100 and 200 MHz. The slowest clock that does not result in a tSCO violation is 166 MHz.
The I3C bus clock is set to 12.5 MHz


# CCC handling

[Source file](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ccc.py)

[Test results](./sim-results/target_ccc.html){.external}

## Testpoints

### `ccc_getstatus`

Test: [`ccc_getstatus`](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ccc.py#L47)

The test reads PENDING_INTERRUPT field from the TTI INTERRUPT
status CSR. Next, it issues the GETSTATUS directed CCC to the
target. Finally it compares the interrupt status returned by the
CCC with the one read from the register.

### `ccc_setdasa`

Test: [`ccc_setdasa`](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ccc.py#L81)

The test sets dynamic address and virtual dynamic address by
sending SETDASA CCC. Then it verifies that correct addresses have
been set by reading STBY_CR_DEVICE_ADDR CSR.

### `ccc_rstdaa`

Test: [`ccc_rstdaa`](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ccc.py#L132)

Sets dynamic address via STBY_CR_DEVICE_ADDR CSR, then sends
RSTDAA CCC and verifies that the address got cleared.

### `ccc_getbcr`

Test: [`ccc_getbcr`](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ccc.py#L168)

Reads BCR register content by sending GETBCR CCC and examining
returned data.

### `ccc_getdcr`

Test: [`ccc_getdcr`](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ccc.py#L186)

Reads DCR register content by sending GETDCR CCC and examining
returned data.

### `ccc_getmwl`

Test: [`ccc_getmwl`](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ccc.py#L202)

Reads MWL register content by sending GETMWL CCC and examining
returned data.

### `ccc_getmrl`

Test: [`ccc_getmrl`](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ccc.py#L220)

Reads MRL register content by sending GETMWL CCC and examining
returned data.

### `ccc_setaasa`

Test: [`ccc_setaasa`](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ccc.py#L239)

Issues the broadcast SETAASA CCC and checks if the target uses
its static address as dynamic by examining STBY_CR_DEVICE_ADDR
CSR.

### `ccc_getpid`

Test: [`ccc_getpid`](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ccc.py#L262)

Sends the CCC to the target and examines if the returned PID
matches the expected.

### `ccc_enec_disec_direct`

Test: [`ccc_enec_disec_direct`](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ccc.py#L295)

Sends DISEC CCC to the target and verifies that events are disabled.
Then, sends ENEC CCC to the target and checks that events are enabled.

### `ccc_enec_disec_bcast`

Test: [`ccc_enec_disec_bcast`](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ccc.py#L329)

Sends boradcast DISEC CCC and verifies that events are disabled.
Then, sends broadcast ENEC CCC and checks that events are enabled.

### `ccc_setmwl_direct`

Test: [`ccc_setmwl_direct`](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ccc.py#L359)

Sends directed SETMWL CCC to the target and verifies that the
register got correctly set. The check is performed by examining
relevant wires in the target DUT

### `ccc_setmrl_direct`

Test: [`ccc_setmrl_direct`](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ccc.py#L378)

Sends directed SETMRL CCC to the target and verifies that the
register got correctly set. The check is performed by examining
relevant wires in the target DUT

### `ccc_setmwl_bcast`

Test: [`ccc_setmwl_bcast`](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ccc.py#L397)

Sends broadcast SETMWL CCC and verifies that the
register got correctly set. The check is performed by examining
relevant wires in the target DUT

### `ccc_setmrl_bcast`

Test: [`ccc_setmrl_bcast`](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ccc.py#L416)

Sends SETMRL CCC and verifies that the
register got correctly set. The check is performed by examining
relevant wires in the target DUT

### `ccc_rstact_direct`

Test: [`ccc_rstact_direct`](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ccc.py#L435)

Sends directed RSTACT CCC to the target followed by reset pattern
and checks if reset action was stored correctly. The check is
done by examining DUT wires. Then, triggers target reset and
verifies that the peripheral_reset_o signal gets asserted.

### `ccc_rstact_bcast`

Test: [`ccc_rstact_bcast`](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ccc.py#L467)

Sends directed RSTACT CCC to the target followed by reset pattern
and checks if reset action was stored correctly. The check is
done by examining DUT wires. Then, triggers target reset and
verifies that the escalated_reset_o signal gets asserted.

### `ccc_direct_multiple_wr`

Test: [`ccc_direct_multiple_wr`](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ccc.py#L492)

Sends a sequence of multiple directed SETMWL CCCs. The first and
the last have non-matching address. The two middle ones set MWL
to different values. Verify that the target responded to correct
addresses and executed both CCCs.

### `ccc_direct_multiple_rd`

Test: [`ccc_direct_multiple_rd`](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ccc.py#L532)

Sends SETMWL CCC. Then sends multiple directed GETMWL CCCs to
thee different addresses. Only the one for the target should
be ACK-ed with the correct MWL content.


# Enter and exit HDR mode

[Source file](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_enter_exit_hdr_mode.py)

[Test results](./sim-results/target_hdr.html){.external}

## Testpoints

### `Enter and exit HDR mode`

Test: `enter_exit_hdr_mode`

Issues ENTHDR0 CCC to the target, verifies that the target FSM
is in IdleHDR state. Issues HDR exit pattern, verifies that
the target FSM is back in Idle state.


# target_interrupts

[Source file](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_interrupts.py)

[Test results](./sim-results/target_interrupts.html){.external}

## Testpoints

### `rx_desc_stat`

Test: [`rx_desc_stat`](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_interrupts.py#L69)

Enables RX_DESC_STAT TTI interrupt, checks if the irq_o signal is
deasserted, sends a private write over I3C to the target and
waits for irq_o assertion. Once the interrupt is asserted reads
a RX descriptor from the TTI RX descriptor queue, ensures that
irq_o gets deasserted after the read.

### `tx_desc_stat`

Test: [`tx_desc_stat`](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_interrupts.py#L106)

Enables TX_DESC_STAT TTI interrupt, checks if the irq_o signal is
deasserted, writes data to TTI TX data queue followed by writing
a descriptor to TTI TX descriptor queue, sends a private read
over I3C and waits for irq_o assertion. Once the interrupt is
asserted clears it by writing 1 to the TX_DESC_STAT fiels of TTI
INTERRUPT_STATUS csr and ensures that irq_o signal gets deasserted.

### `ibi_done`

Test: [`ibi_done`](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_interrupts.py#L153)

Enables IBI_DONE_EN TTI interrupt, checks if the irq_o signal is
deasserted, and the status bit in TTI INTERRUPT_STATUS CSR cleared.
Issues and IBI, waits for it to be serviced by the controller.
Checks if the status bit is set in INTERRUPT_STATUS CSR and the
irq_o signal asserted. Reads LAST_IBI_STATUS field from the TTI
STATUS CSR, ensures that irq_o gets deasserted and status bit gets
cleared afterwards.

### `interrupt_force`

Test: `interrupt_force`

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

[Source file](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_recovery.py)

[Test results](./sim-results/target_recovery.html){.external}

## Testpoints

### `virtual_write`

Test: [`virtual_write`](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_recovery.py#L108)

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
The I3C bus clock is set to 12.5 MHz

### `virtual_write_alternating`

Test: [`virtual_write_alternating`](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_recovery.py#L218)

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
The I3C bus clock is set to 12.5 MHz

### `write`

Test: [`write`](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_recovery.py#L287)

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
The I3C bus clock is set to 12.5 MHz

### `indirect_fifo_write`

Test: [`indirect_fifo_write`](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_recovery.py#L355)

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
The I3C bus clock is set to 12.5 MHz

### `write_pec`

Test: [`write_pec`](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_recovery.py#L454)

Sets the TTI and recovery addresses via two SETDASA CCCs.

Writes some data to DEVICE_RESET register using the recovery
interface. Then, repeats the write with different data but
deliberately corrupts the recovery packet's checksum (PEC).
Finally, reads the content of DEVICE_RESET CSR over AHB/AXI
and ensures that it matches with what was written in the first
transfer.

The test runs at core clock of 100 and 200 MHz. The slowest clock that does not result in a tSCO violation is 166 MHz.
The I3C bus clock is set to 12.5 MHz

### `read`

Test: [`read`](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_recovery.py#L509)

Sets the TTI and recovery addresses via two SETDASA CCCs.

Writes random data to the PROT_CAP recovery CSR via AHB/AXI.
Disables the recovery mode, writes some data to TTI TX queues
via AHB/AXI, enables the recovery mode and reads PROT_CAP using
the recovery protocol. Checks if the content matches what was
written in the beginning of the test.

The test runs at core clock of 100 and 200 MHz. The slowest clock that does not result in a tSCO violation is 166 MHz.
The I3C bus clock is set to 12.5 MHz

### `read_short`

Test: [`read_short`](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_recovery.py#L597)

Sets the TTI and recovery addresses via two SETDASA CCCs.

Writes random data to the PROT_CAP recovery CSR via AHB/AXI.
Disables the recovery mode, writes some data to TTI TX queues
via AHB/AXI, enables the recovery mode and reads PROT_CAP using
the recovery protocol. The I3C read transfer is deliberately
shorter - the recovery read is terminated by the I3C controller.
Checks if the content read back matches what was written in the
beginning of the test.

The test runs at core clock of 100 and 200 MHz. The slowest clock that does not result in a tSCO violation is 166 MHz.
The I3C bus clock is set to 12.5 MHz

### `read_long`

Test: [`read_long`](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_recovery.py#L663)

Sets the TTI and recovery addresses via two SETDASA CCCs.

Writes random data to the PROT_CAP recovery CSR via AHB/AXI.
Disables the recovery mode, writes some data to TTI TX queues
via AHB/AXI, enables the recovery mode and reads PROT_CAP using
the recovery protocol. The I3C read transfer is deliberately
longer - the recovery read is terminated by the I3C target.
Checks if the content read back matches what was written in the
beginning of the test.

The test runs at core clock of 100 and 200 MHz. The slowest clock that does not result in a tSCO violation is 166 MHz.
The I3C bus clock is set to 12.5 MHz

### `virtual_read`

Test: [`virtual_read`](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_recovery.py#L788)

Sets the TTI and recovery addresses via two SETDASA CCCs. Disables
the recovery mode.

Issues a series of recovery read commands to all CSRs mentioned in the
spec. The series is repeated twice - for recovery mode enabled and disabled.
Each transfer is checked if the response is ACK or NACK and in case of
ACK if PEC checksum is correct.

Checks if CSRs that sould be available anytime (i.e. when the recovery
mode is off) are always accessible, checks if other CSRs are accessible
only in the recovery mode.

The test runs at core clock of 100 and 200 MHz. The slowest clock that does not result in a tSCO violation is 166 MHz.
The I3C bus clock is set to 12.5 MHz

### `virtual_read_alternating`

Test: [`virtual_read_alternating`](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_recovery.py#L874)

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
The I3C bus clock is set to 12.5 MHz

### `payload_available`

Test: [`payload_available`](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_recovery.py#L955)

Sets the TTI and recovery addresses via two SETDASA CCCs.

Ensures that initially the recovery_payload_available_o signal
is deasserted. Then writes data to the indirect FIFO via the
recovery interface and checks if the signal gets asserted.

Reads from INDIRECT_FIFO_DATA CSR over AHB/AXI and checks if the
read causes the signal to be deasserted again.

The test runs at core clock of 100 and 200 MHz. The slowest clock that does not result in a tSCO violation is 166 MHz.
The I3C bus clock is set to 12.5 MHz

### `image_activated`

Test: [`image_activated`](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_recovery.py#L1022)

Sets the TTI and recovery addresses via two SETDASA CCCs.

Ensures that initially the image_activated_o signal is deasserted.
Writes 0xF to the 3rd byte of the RECOVERY_CTRL register using the
recovery interface. Checks if the signal gets asserted. Then writes
0xFF to the same byte of the register and checks if the signal
gets deasserted.

The test runs at core clock of 100 and 200 MHz. The slowest clock that does not result in a tSCO violation is 166 MHz.
The I3C bus clock is set to 12.5 MHz

### `recovery_flow`

Test: [`recovery_flow`](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_recovery.py#L1074)

The test exercises firmware image transfer flow using the recovery
protocol. It consists of two agents running concurrently.

The AHB/AXI agent is responsible for recovery operation from the
system bus side. It mimicks operation of the recovery handling
firmware.

The BFM agent issues I3C transactions and is responsible for pushing
a firmware image to the target.

The test runs at core clock of 100 and 200 MHz. The slowest clock that does not result in a tSCO violation is 166 MHz.
The I3C bus clock is set to 12.5 MHz


# target_peripheral_reset

[Source file](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_target_reset.py)

[Test results](./sim-results/target_reset.html){.external}

## Testpoints

### `target_peripheral_reset`

Test: [`target_peripheral_reset`](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_target_reset.py#L70)

Issues I3C target reset pattern and verifies successful peripheral reset

### `target_escalated_reset`

Test: [`target_escalated_reset`](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_target_reset.py#L77)

Issues I3C target reset patterns and verifies successful reset escalation



# axi_filtering

## Testpoints

### `axi_filtering_disabled`

Tests:
- read_hci_version_csr_id_filter_off- read_pio_section_offset_filter_off- write_to_controller_device_addr_filter_off- write_should_not_affect_ro_csr_filter_off- sequence_csr_read_filter_off- sequence_csr_write_filter_off- collision_with_write_id_filter_off- collision_with_read_id_filter_off- write_read_burst_id_filter_off- write_burst_collision_with_read_id_filter_off- read_burst_collision_with_write_id_filter_off

Verifies CSR access is granted when the AXI filtering feature is disabled.
Verifies transaction response and contents.

### `axi_filtering_priv`

Tests:
- read_hci_version_csr_id_filter_on_priv- read_pio_section_offset_filter_on_priv- write_to_controller_device_addr_filter_on_priv- write_should_not_affect_ro_csr_filter_on_priv- sequence_csr_read_filter_on_priv- sequence_csr_write_filter_on_priv- collision_with_write_id_filter_on_priv- collision_with_read_id_filter_on_priv- write_read_burst_id_filter_on_priv- write_burst_collision_with_read_id_filter_on_priv- read_burst_collision_with_write_id_filter_on_priv

Verifies CSR access is granted when the AXI filtering is enabled
and the transaction has a privileged ID.
Verifies transaction response and contents.

### `axi_filtering_non_priv`

Tests:
- read_hci_version_csr_id_filter_on_non_priv- read_pio_section_offset_filter_on_non_priv- write_to_controller_device_addr_filter_on_non_priv- write_should_not_affect_ro_csr_filter_on_non_priv- sequence_csr_read_filter_on_non_priv- sequence_csr_write_filter_on_non_priv- collision_with_write_id_filter_on_non_priv- collision_with_read_id_filter_on_non_priv- write_read_burst_id_filter_on_non_priv- write_burst_collision_with_read_id_filter_on_non_priv- read_burst_collision_with_write_id_filter_on_non_priv

Verifies CSR access is denied when the AXI filtering feature is enabled
and the transaction ID doesn't match any of the privileged IDs.

### `axi_filtering_mixed_priv`

Tests:
- collision_with_write_id_filter_on_mixed- collision_with_read_id_filter_on_mixed- collision_with_write_mixed_priv- collision_with_read_mixed_priv

Issues an ID-randomized colliding read and write transactions sequence.
Verifies AXI CSR access response for each separate transaction.
Ensures that access errors are raised only for unprivileged transactions.


# bus_monitor

## Testpoints

### `bus_monitor`

Test: bus_monitor

Tests operation of the bus_monitor module along with its sub-modules.
Performs a number of I3C transactions between a simulated controller
and a simulated target. Counts start, repeated start and stop events
reported by bus_monitor. Verifies that the counts match what's expected.


# bus_rx_flow

## Testpoints

### `multiple_bit_reads`

Test: multiple_bit_reads

Drives SCL line with a steady clock, issues multiple bit read
requests, verifies that the module returns correct data sampled
from the SDA line.

### `multiple_byte_reads`

Test: multiple_byte_reads

Drives SCL line with a steady clock, issues multiple byte read
requests, verifies that the module returns correct data sampled
from the SDA line.


# Bus timers top-level

## Testpoints

### `get_status`

Test: bus_timers

Tests the bus_timers module responsible for tracking bus free,
idle and available states. Triggers the module and verifies if
the signals corresponding to bus states get asserted after the
required time period.


# bus_tx

## Testpoints

### `bit_tx_negedge`

Test: bit_tx_negedge

Requests the bus_tx module to drive SDA right after SCL falling
edge. Checks if the requested bit value is driven correctly.

### `bit_tx_pre_posedge`

Test: bit_tx_pre_posedge

Requests the bus_tx module to drive SDA just before SCL rising
edge. Checks if the requested bit value is driven correctly.

### `bit_tx_high_level`

Test: bit_tx_high_level

Requests the bus_tx module to drive SDA just before SCL falling
edge. Checks if the requested bit value is driven correctly.

### `bit_tx_low_level`

Test: bit_tx_low_level

Requests the bus_tx module to drive SDA when SCL in in stable
low state. Checks if the requested bit value is driven correctly.

### `byte_tx`

Test: byte_tx

Drives controls of the bus_tx module in a sequence which sends
a data byte plus T bit to the I3C bus. For each bit sent checks
if SDA is driven correctly and bus timings are met.


# bus_tx_flow

## Testpoints

### `bit_tx_negedge`

Test: bit_tx_negedge

Requests the bus_tx_flow module to drive SDA right after SCL falling
edge. Checks if the requested bit value is driven correctly.

### `bit_tx_pre_posedge`

Test: bit_tx_pre_posedge

Requests the bus_tx_flow module to drive SDA just before SCL rising
edge. Checks if the requested bit value is driven correctly.

### `bit_tx_high_level`

Test: bit_tx_high_level

Requests the bus_tx_flow module to drive SDA just before SCL falling
edge. Checks if the requested bit value is driven correctly.

### `bit_tx_low_level`

Test: bit_tx_low_level

Requests the bus_tx_flow module to drive SDA when SCL in in stable
low state. Checks if the requested bit value is driven correctly.

### `byte_tx`

Test: byte_tx

Requests the bus_tx_flow module to transmit a data byte along with
T-bit. While the transmission is in progress samples SDA on rising
edges of SCL. Once the transmission finishes compares sampled data
with what was requested to be sent.


# ccc

## Testpoints

### `ccc`

Test: ccc

Instructs the ccc module to begin servicing GETSTATUS CCC. Feeds
data bytes and bits to the module via its bus_tx/bus_rx interfaces
to mimic actual I3C transaction. Checks if data bytes received
correspond to correct GETSTATUS CCC response.


# flow_active

## Testpoints

### `immediate_write`

Test: immediate_write

Testbench:
flow_active_wrapper (DUT) -> flow_active golden model

Intent:
Verify Private Write with Immediate Data Transfer Command Descriptor (7.2.2.1 TCRI Spec) to an individual I3C Target Device with known static address

Stimulus:
 - create a 64b CMD descriptor as per Table 16 7.2.2.1 TCRI Spec. With:
    - CMD_ATTR = 0x5 // ImmediateDataTransfer in Direct Format
    - TID: random transaction ID
    - I2C = 0x0 // I3C device
    - CMD: random this field is disregarded
    - CP = 0x0 // CMD field is not valid
    - DEV_ADDRESS: random allowed I3C address 
    - DTT: number of bytes to be transferred
    - MODE = 0x0 // standard I3C SDR Speed
    - RNW = 0x0 // Write transfer
    - WROC: random 
    - TOC: random
    - DATA_BYTES: random data to be sent
- split the 64b descriptor into 2 32b words (DWORD) and first write the lower DWORD into the COMMAND_PORT PIO reg followed by the upper DWORD.

Check:
    - correct start/restart fmt_flag is generated 
    - first fmt_byte is DEV_ADDRESS
    - following DTT fmt_bytes are DATA_BYTES
    - correct stop fmt_flag is generated


# csr_sw_access

## Testpoints

### `read_hci_version_csr`

Test: read_hci_version_csr

Reads the HCI version CSR and verifies its content.

### `read_pio_section_offset`

Test: read_pio_section_offset

Reads the PIO_SECTION_OFFSET CSR and verifies its content.

### `write_to_controller_device_addr`

Test: write_to_controller_device_addr

Writes to the CONTROLLER_DEVICE_ADDR CSR and verifies if the write was successful.

### `write_should_not_affect_ro_csr`

Test: write_should_not_affect_ro_csr

Writes to the HC_CAPABILITIES CSR which is read-only for software.
Verifies that the write did not succeed.

### `sequence_csr_read`

Test: sequence_csr_read

Performs a sequence of CSR reads. Verifies that each one succeeds.

### `sequence_csr_write`

Test: sequence_csr_write

Performs a sequence of CSR writes. Verifies that each one succeeds.


# descriptor_rx

## Testpoints

### `descriptor_rx`

Test: descriptor_rx

Tests the descriptor_rx module responsible for generating TTI RX
descriptors. The test sends N bytes to the module and verifies
that it emits a valid descriptor with data length set to N.


# descriptor_tx

## Testpoints

### `descriptor_tx`

Test: descriptor_tx

Tests the descriptor_tx module responsible for processing TTI TX
descriptors and controlling TTI data flow during I3C private
reads. Sends a descriptor to the module followed with the right
amount of data. Verifies that the module accepted the descriptor
and allowed the right amount of data bytes to pass through it.


# drivers

## Testpoints

### `test_drivers`

Test: drivers

Tests the I3C PHY module. Loops through all possible states of
SDA/SCL for OD and PP mode. Checks if driven data matches the
bus state.


# edge_detector

## Testpoints

### `pretrigger_with_delay`

Test: pretrigger_with_delay

Triggers the edge_detector module before an edge on a bus line,
emits the edge and counts clock cycles it takes the detector
to report the presence of the edge. Verifies that the count is
equal to the programmed delay.

### `posttrigger_with_delay`

Test: posttrigger_with_delay

Emits an edge on the bus, triggers the edge_detector module after
the edge when the bus line is high. Counts clock cycles it takes
the detector to report the edge event. The output detect signal
is asserted only if the bus line signal is stable for the
programmed delay time since the assertion of the trigger signal.
Verifies that the number of counted cycles is equal the programmed
delay.

### `trigger_with_delay`

Test: trigger_with_delay

Triggers the edge detector and emits a rising edge on a bus line
simultaneously. Counts clock cycles it takes the detector
to report the presence of the edge. Verifies that the count is
equal to the programmed delay.

### `pretrigger_no_delay`

Test: pretrigger_no_delay

Triggers the edge_detector module before an edge on a bus line,
emits the edge and counts clock cycles it takes the detector
to report the presence of the edge. Verifies that the count is
zero as the configured delay is also set to 0.

### `posttrigger_no_delay`

Test: posttrigger_no_delay

Triggers the edge_detector module when a bus line is high which
is after an edge. Counts clock cycles it takes the detector
to report the presence of the edge. Verifies that the count is
zero as the configured delay is also set to 0.

### `trigger_no_delay`

Test: trigger_no_delay

Triggers the edge detector and emits a rising edge on a bus line
simultaneously. Counts clock cycles it takes the detector
to report the presence of the edge. Verifies that the count is
zero as the configured delay is also set to 0.

### `falling_before_delay`

Test: falling_before_delay

Triggers the edge detector and emits a rising edge on a bus line
simultaneously. After half of the programmed delay passed the line
falls back to low. Verifies that the edge was not reported in this
scenario.


# flow_standby_i3c

## Testpoints

### `rx`

Test: rx

Tests basic operation of the flow_standby_i3c module. The test
instantiates two tasks serving as BFMs for RX and TX queues.
Then it simulates bus start condition followed by data reception
ended by bus stop condition.


# hci_queues

## Testpoints

### `clear_on_nonempty_resp_queue`

Test: clear_on_nonempty_resp_queue

Writes to the HCI queue RESET_CONTROL CSR bit which causes HCI
command response queue to be cleared. Then, polls the CSR until the
bit gets cleared by the hardware. To check if the queue has been
cleared puts a descriptor to the queue and reads it back. It
should be the same descriptor.

### `clear_on_nonempty_cmd_queue`

Test: clear_on_nonempty_cmd_queue

Puts a command descriptor to the HCI command queue. Writes to the
RESET_CONTROL CSR to the bit responsible for clearing the queue,
polls the CSR until the bit gets cleared by hardware. Verifies that
the queue got cleared by pushing and retrieving another descriptor
from the queue.

### `clear_on_nonempty_rx_queue`

Test: clear_on_nonempty_rx_queue

Puts 10 data words to the HCI RX data queue. Writes to the
RESET_CONTROL CSR to the bit responsible for clearing the queue,
polls the CSR until the bit gets cleared by hardware. Puts and
gets another data word from the queue to check if it was cleared.

### `clear_on_nonempty_tx_queue`

Test: clear_on_nonempty_tx_queue

Puts 10 data words to the HCI TX data queue. Writes to the
RESET_CONTROL CSR to the bit responsible for clearing the queue,
polls the CSR until the bit gets cleared by hardware. Puts and
gets another data word from the queue to check if it was cleared.

### `clear_on_nonempty_ibi_queue`

Test: clear_on_nonempty_ibi_queue

Puts 10 data words to the HCI IBI queue. Writes to the
RESET_CONTROL CSR to the bit responsible for clearing the queue,
polls the CSR until the bit gets cleared by hardware. Puts and
gets another data word from the queue to check if it was cleared.

### `cmd_capacity_status`

Test: cmd_capacity_status

Resets the HCI command queue and verifies that it is empty
afterwards.

### `resp_capacity_status`

Test: resp_capacity_status

Resets the HCI response queue and verifies that it is empty
afterwards.

### `rx_capacity_status`

Test: rx_capacity_status

Resets the HCI RX queue and verifies that it is empty
afterwards.

### `tx_capacity_status`

Test: tx_capacity_status

Resets the HCI TX queue and verifies that it is empty
afterwards.

### `ibi_capacity_status`

Test: ibi_capacity_status

Resets the HCI IBI queue and verifies that it is empty
afterwards.

### `cmd_setup_threshold`

Test: cmd_setup_threshold

Writes the threshold to appropriate register for the HCI command
queue (QUEUE_THLD_CTRL or DATA_BUFFER_THLD_CTRL).
Verifies that an appropriate value has been written to the CSR.
Verifies the threshold signal assumes the correct value.

### `resp_setup_threshold`

Test: resp_setup_threshold

Writes the threshold to appropriate register for the HCI response
queue (QUEUE_THLD_CTRL or DATA_BUFFER_THLD_CTRL).
Verifies that an appropriate value has been written to the CSR.
Verifies the threshold signal assumes the correct value.

### `rx_setup_threshold`

Test: rx_setup_threshold

Writes the threshold to appropriate register for the HCI data RX
queue (QUEUE_THLD_CTRL or DATA_BUFFER_THLD_CTRL).
Verifies that an appropriate value has been written to the CSR.
Verifies the threshold signal assumes the correct value.

### `tx_setup_threshold`

Test: tx_setup_threshold

Writes the threshold to appropriate register for the HCI data TX
queue (QUEUE_THLD_CTRL or DATA_BUFFER_THLD_CTRL).
Verifies that an appropriate value has been written to the CSR.
Verifies the threshold signal assumes the correct value.

### `ibi_setup_threshold`

Test: ibi_setup_threshold

Writes the threshold to appropriate register for the HCI IBI
queue (QUEUE_THLD_CTRL or DATA_BUFFER_THLD_CTRL).
Verifies that an appropriate value has been written to the CSR.
Verifies the threshold signal assumes the correct value.

### `resp_should_raise_thld_trig`

Test: resp_should_raise_thld_trig

Sets up a ready threshold of the read queue and checks whether the
trigger signal is properly asserted at different levels of the
queue fill.

### `rx_should_raise_thld_trig`

Test: rx_should_raise_thld_trig

Sets up a ready and start thresholds of the read queue and checks
whether the trigger signals are properly asserted at different
levels of the queue fill.

### `ibi_should_raise_thld_trig`

Test: ibi_should_raise_thld_trig

Sets up a ready threshold of the read queue and checks whether the
trigger signal is properly asserted at different levels of the
queue fill.

### `cmd_should_raise_thld_trig`

Test: cmd_should_raise_thld_trig

Sets up a ready threshold of the write queue and checks whether
the trigger is properly asserted at different levels of the queue
fill.

### `tx_should_raise_thld_trig`

Test: tx_should_raise_thld_trig

Sets up a ready and start threshold of the write queue and checks
whether the trigger is properly asserted at different levels of
the queue fill.


# i3c_bus_monitor

## Testpoints

### `bus_monitor_hdr_exit`

Test: bus_monitor_hdr_exit

Verifies that the i3c_bus_monitor module correctly detects HDR
exit pattern. Sends the HDR exit pattern and verifies that the
module does not react - initially the bus is in SDR mode. Instructs
the module that the bus has entered HDR mode, issues the HDR exit
pattern and counts the number of times the module reported HDR
exit. Checks if it reported exactly one HDR exit event.

### `target_reset_detection`

Test: target_reset_detection

Issues a target reset pattern to the I3C bus, verifies that the
i3c_bus_monitor correctly report it detected.


# pec

## Testpoints

### `pec`

Test: pec

Pushes random bytes through the recovery_pec module, compares
its computed checksum with its correspondent computed in software.


# tti_queues

## Testpoints

### `tti_tx_capacity_status`

Test: tti_tx_capacity_status

Resets the TTI TX queue and verifies that it is empty
afterwards.

### `tti_tx_desc_capacity_status`

Test: tti_tx_desc_capacity_status

Resets the TTI TX descriptor queue and verifies that it is empty
afterwards.

### `tti_rx_capacity_status`

Test: tti_rx_capacity_status

Resets the TTI RX queue and verifies that it is empty
afterwards.

### `tti_rx_desc_capacity_status`

Test: tti_rx_desc_capacity_status

Resets the TTI RX descriptor queue and verifies that it is empty
afterwards.

### `tti_tx_setup_threshold`

Test: tti_tx_setup_threshold

Writes the threshold to appropriate register for the TTI data TX
queue (QUEUE_THLD_CTRL or DATA_BUFFER_THLD_CTRL).
Verifies that an appropriate value has been written to the CSR.
Verifies the threshold signal assumes the correct value.

### `tti_tx_desc_setup_threshold`

Test: tti_tx_desc_setup_threshold

Writes the threshold to appropriate register for the TTI descriptor TX
queue (QUEUE_THLD_CTRL or DATA_BUFFER_THLD_CTRL).
Verifies that an appropriate value has been written to the CSR.
Verifies the threshold signal assumes the correct value.

### `tti_rx_setup_threshold`

Test: tti_rx_setup_threshold

Writes the threshold to appropriate register for the TTI data RX
queue (QUEUE_THLD_CTRL or DATA_BUFFER_THLD_CTRL).
Verifies that an appropriate value has been written to the CSR.
Verifies the threshold signal assumes the correct value.

### `tti_rx_desc_setup_threshold`

Test: tti_rx_desc_setup_threshold

Writes the threshold to appropriate register for the TTI descriptor RX
queue (QUEUE_THLD_CTRL or DATA_BUFFER_THLD_CTRL).
Verifies that an appropriate value has been written to the CSR.
Verifies the threshold signal assumes the correct value.

### `tti_ibi_setup_threshold`

Test: tti_ibi_setup_threshold

Writes the threshold to appropriate register for the TTI IBI
queue (QUEUE_THLD_CTRL or DATA_BUFFER_THLD_CTRL).
Verifies that an appropriate value has been written to the CSR.
Verifies the threshold signal assumes the correct value.

### `tti_ibi_should_raise_thld_trig`

Test: tti_ibi_should_raise_thld_trig

Sets up a ready threshold of the TTI queue and checks whether the
trigger signal is properly asserted at different levels of the
queue fill.

### `tti_rx_desc_should_raise_thld_trig`

Test: tti_rx_desc_should_raise_thld_trig

Sets up a ready threshold of the read queue and checks whether the
trigger signal is properly asserted at different levels of the
queue fill.

### `rx_should_raise_thld_trig`

Test: rx_should_raise_thld_trig

Sets up a ready and start thresholds of the read queue and checks
whether the trigger signals are properly asserted at different
levels of the queue fill.

### `tx_desc_should_raise_thld_trig`

Test: tti_tx_desc_should_raise_thld_trig

Sets up a ready and start threshold of the write queue and checks
whether the trigger is properly asserted at different levels of
the queue fill.

### `tx_should_raise_thld_trig`

Test: tx_should_raise_thld_trig

Sets up a ready and start threshold of the write queue and checks
whether the trigger is properly asserted at different levels of
the queue fill.

### `ibi_should_raise_thld_trig`

Test: ibi_should_raise_thld_trig

Sets up a ready and start threshold of the write queue and checks
whether the trigger is properly asserted at different levels of
the queue fill.

### `tti_ibi_capacity_status`

Test: tti_ibi_capacity_status

Resets the TTI TX IBI queue and verifies that it is empty
afterwards.


# width_converter_8toN

## Testpoints

### `converter`

Test: [width_converter_8ton_converter](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/block/width_converter_8toN/test_converter.py)

Pushes random byte stream to the converter module. After each
byte waits at random. Simultaneously receives N-bit data words
and generates pushback (deasserts ready) at random. Verifies if
the output data matches the input.

### `flush`

Test: [width_converter_8ton_flush](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/block/width_converter_8toN/test_converter.py)

Feeds M bytes to the module where M is in [1, 2, 3]. Asserts the
sink_flush_i signal, receives the output word and checks if it
matches the input data.


# width_converter_Nto8

## Testpoints

### `converter`

Test: [width_converter_nto8_converter](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/block/width_converter_Nto8/test_converter.py)

Pushes random N-bit word stream to the converter module. After each
word waits at random. Simultaneously receives bytes and generates
pushback (deasserts ready) at random. Verifies if the output data
matches the input.

### `flush`

Test: [width_converter_nto8_flush](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/block/width_converter_Nto8/test_converter.py)

Feeds an N-bit word to the module. Receives M bytes where M is in
[1, 2, 3] and asserts source_flush_i. Verifies that the module
ceases to output data as expected.


# Controller I3C flow

## Testpoints

### `Typical I3C operation`

Test: controller_typical_operation

- Configure the bus using CCC to assign dynamic addresses
- perform writes to multiple targets
- read from multiple targets
- service IBI
- issue restart of a target
- hot join a new target 
- service errors

### `multiple_interleaved_transaction_sequences`

Test: multiple_interleaved_transaction_sequences

Testbench:
I3C Controller (RTL) <-> I3C Target (RTL)

Intent:
Verify Chaining Private Writes and Private Reads with Immediate and Regular Data Transfer Command (7.2.2.1 / 7.2.2.2 TCRI Spec) to an individual I3C Target Device with known static address using Sr condition.

Stimulus:
- create random amount of 64b CMD descriptors as per Table 16/18 7.2.2.1 / 7.2.2.2 TCRI Spec. With:
    - TOC: random we want to test repeated start
- split the 64b descriptors into 2 32b words (DWORD) and first write the lower DWORD into the COMMAND_PORT PIO reg followed by the upper DWORD.
- we want to test a random sequence of reads / writes chained together by either Sr or P.
- For example: S->W->Sr->W->...->R->P->S->R->Sr->...->W->P

Check:
Verify that:
  - data being sent via TX_DATA_PORT is equal to data on the target I3C_EC.TTI.RX_DATA_PORT CSR.

### `controller_flow_simple`

Test: controller_flow_simple

Testbench:
I3C Controller (RTL) <-> I3C Target (RTL)

Intent:
Verify simple I3C operation including SETDASA CCC to assign dynamic address, I3C private read and I3C private write.

Stimulus:
- Issue a SETDASA CCC using an address assignment command descriptor with a random (valid) I3C dynamic address. 
- Generate random data (length: 1 < DATA_LENGTH < TX_QUEUE_DEPTH*4 bytes)
- Write data using the dynamic address in an I3C private write.
- Generate random data (length: 1 < DATA_LENGTH < TX_QUEUE_DEPTH*4 bytes)
- Write data to the I3C target using the TTI_TX_DATA_PORT.
- Read data using the dynamic address in an I3C private read.

Check:
  - SETDASA: the targets I3C_EC.STDBYCTRLMODE.STBY_CR_DEVICE_ADDR.DYNAMIC_ADDR CSR contains the dynamic address which was set.  
  - I3C private write: data being sent via TX_DATA_PORT is equal to data on the target I3C_EC.TTI.RX_DATA_PORT CSR. 
  - I3C private read: data read from controller RX_DATA_PORT matches data sent to TTI_TX_DATA_PORT
  - For all transactions: response descriptor data length matches data bytes specified in CMD desc, resp desc TID matches TID form CMD desc and resp error status is SUCCESS.


# Controller Data over-/underflow handling

## Testpoints

### `Controller Reading from empty IBI FIFO`

Test: controller_empty_rx_desc_read

Perform read bus access to the empty IBI queue,
verify that response comes back and it holds value of ?.

### `Controller Reading from empty RX data FIFO`

Test: controller_empty_rx_data_read

Perform read bus access to the empty RX data queue,
verify that response comes back and it holds value of ).

### `Controller Reading from empty resp FIFO`

Test: controller_empty_indirect_fifo_read

Perform read bus access to the empty resp queue,
verify that response comes back and it holds value of ?.

### `Controller Writing to full cmd FIFO`

Test: controller_full_tx_desc_write

Perform multiple write bus accesses to the cmd queue,
verify that all transactions have finished.

### `Controller Writing to full TX data FIFO`

Test: controller_full_tx_data_write

Perform multiple write bus accesses to the TX data queue,
verify that all transactions have finished.


# Controller CCC generation

## Testpoints

### `controller_ccc_enec_disec_bcast`

Test: [controller_ccc_enec_disec_bcast](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/i3c_axi_controller/test_controller_ccc.py)

Testbench:
I3C Controller (RTL) <-> I3C Target (RTL)

Intent:
Verify 5.1.9.3.1 Enable/Disable Target Events Command (ENEC/DISEC) from I3C Basic Spec. Using Broadcast mode.
The test first disables events from the target with the DISEC CCC and then enables them again with ENEC.

Stimulus:
- randomly create a regular or immediate 64b CMD descriptor. With:
    - CMD_ATTR = 0x4 or 0x5// RegularDataTransfer or ImmediateDataTransfer in Direct Format
    - CMD: 0x1 / 0x0 // DISEC / ENEC BCAST
    - CP = 0x1 // CMD field is valid
    - DEV_ADDRESS: random allowed I3C address 
    - DTT/DATA_LENGTH = 1 // One byte of Payload
    - RNW = 0x0 // Write transfer
    - WROC = random // randomly generate response descriptor
    - TOC = 0x1 // want to generate a stop signal after first transfer 
    - DATA_BYTE1 = 0x0b // Enable/Disable all Target Events (See Table 18 & Table 19 I3C Basic Spec)
- send CMD descriptor
- generate a second CMD descriptor with CMD = 0x0 (ENEC).

Check:
  - Initially the I3C_EC.TTI.CONTROL.IBI_EN and I3C_EC.TTI.CONTROL.HJ_EN CSRs should be set to 1 and I3C_EC.TTI.CONTROL.CRR_EN should be set to 0.
  - After sending the first CCC (DISEC) all CSRs should be set to 0.
  - After sending the second CCC (ENEC) all CSRs should be set to 1.

### `controller_ccc_enec_disec_direct_one_target`

Test: [controller_ccc_enec_disec_direct_one_target](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/i3c_axi_controller/test_controller_ccc.py)

Testbench:
I3C Controller (RTL) <-> I3C Target (RTL)

Intent:
Verify 5.1.9.3.1 Enable/Disable Target Events Command (ENEC/DISEC) from I3C Basic Spec. Using Direct mode.
The test first disables events from the target with the DISEC CCC and then enables them again with ENEC.

Stimulus:
- randomly create a regular or immediate 64b CMD descriptor. With:
    - CMD_ATTR = 0x4 or 0x5// RegularDataTransfer or ImmediateDataTransfer in Direct Format
    - CMD: 0x81 / 0x80 // DISEC / ENEC DIRECT
    - CP = 0x1 // CMD field is valid
    - DEV_ADDRESS = Target Address
    - DTT/DATA_LENGTH = 1 // One byte of Payload
    - RNW = 0x0 // Write transfer
    - WROC = random // randomly generate response descriptor
    - TOC = 0x1 // want to generate a stop signal after first transfer 
    - DATA_BYTE1 = 0x0b // Enable/Disable all Target Events (See Table 18 & Table 19 I3C Basic Spec)
- send CMD descriptor
- generate a second CMD descriptor with CMD = 0x80 (ENEC).

Check:
  - Initially the I3C_EC.TTI.CONTROL.IBI_EN, I3C_EC.TTI.CONTROL.CRR_EN and I3C_EC.TTI.CONTROL.HJ_EN CSRs should all be set to one.
  - After sending the first CCC (DISEC) the CSRs should be set to 0.
  - After sending the second CCC (ENEC) the CSRs should again all be set to 1.

### `controller_ccc_enec_disec_direct_multiple_targets`

Test: [controller_ccc_enec_disec_direct_multiple_targets](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/i3c_axi_controller/test_controller_ccc.py)

Testbench:
I3C Controller (RTL) <-> I3C Target (RTL)

Intent:
Verify 5.1.9.3.1 Enable/Disable Target Events Command (ENEC/DISEC) from I3C Basic Spec. Using Direct mode.
The test first disables events from the targets with the DISEC CCC and then enables them again with ENEC.
The goal is to see if the Direct Frame is correctly generated for multiple cmd descriptors where the CCC stays the same. (Figure 31 I3C Basic Spec)

Stimulus:
- randomly create num_targets regular or immediate 64b CMD descriptor. With:
    - CMD_ATTR = 0x4 or 0x5// RegularDataTransfer or ImmediateDataTransfer in Direct Format
    - CMD: 0x81 / 0x80 // DISEC / ENEC DIRECT
    - CP = 0x1 // CMD field is valid
    - DEV_ADDRESS = Target Address (For now the target address is kept constant since we only have one target to test on the I3C Bus)
    - DTT/DATA_LENGTH = 1 // One byte of Payload
    - RNW = 0x0 // Write transfer
    - WROC = random // randomly generate response descriptor
    - TOC = 0x1 // want to generate a stop signal after first transfer 
    - DATA_BYTE1 = 0x0b // Enable/Disable all Target Events (See Table 18 & Table 19 I3C Basic Spec)
- send CMD descriptor
- generate a second CMD descriptor with CMD = 0x80 (ENEC).

Check:
  - Initially the I3C_EC.TTI.CONTROL.IBI_EN, I3C_EC.TTI.CONTROL.CRR_EN and I3C_EC.TTI.CONTROL.HJ_EN CSRs should all be set to one.
  - After sending the first CCC (DISEC) the CSRs should be set to 0.
  - After sending the second CCC (ENEC) the CSRs should again all be set to 1.

### `controller_ccc_rstdaa`

Test: [controller_ccc_rstdaa](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/i3c_axi_controller/test_controller_ccc.py)

Testbench:
I3C Controller (RTL) <-> I3C Target (RTL)

Intent:
Verify 5.1.9.3.3 Reset Dynamic Address Assignment (RSTDAA) from I3C Basic Spec. Using Broadcast mode.
The test resets the dynamic addresses of the target and virtual target device.

Stimulus:
- assign DYNAMIC_ADDR and VIRT_DYNAMIC_ADDR during boot by writing to the I3C_EC.STDBYCTRLMODE.STBY_CR_DEVICE_ADDR.DYNAMIC_ADDR and I3C_EC.STDBYCTRLMODE.STBY_CR_VIRT_DEVICE_ADDR.VIRT_DYNAMIC_ADDR CSRs
- randomly create a regular or immediate 64b CMD descriptor. With:
    - CMD_ATTR = 0x4 or 0x5// RegularDataTransfer or ImmediateDataTransfer in Direct Format
    - CMD: 0x06 // RSTDAA BCAST
    - CP = 0x1 // CMD field is valid
    - DTT/DATA_LENGTH = 0 // No Payload
- send CMD descriptor

Check:
- Verify that I3C_EC.STDBYCTRLMODE.STBY_CR_DEVICE_ADDR.DYNAMIC_ADDR_VALID is 0x0 after RSTDAA
- Verify that I3C_EC.STDBYCTRLMODE.STBY_CR_VIRT_DEVICE_ADDR.VIRT_DYNAMIC_ADDR_VALID is 0x0 after RSTDAA

### `controller_ccc_entdaa`

Test: [controller_ccc_entdaa](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/i3c_axi_controller/test_controller_ccc.py)

Testbench:
I3C Controller (RTL) <-> I3C Target (RTL)

Intent:
Verify 5.1.4.2 Bus Initialization Sequence with Dynamic Address Assignment from I3C Basic Spec. Using ENTDAA CCC in Broadcast mode.
The test sets the dynamic address of the i3c target as well as the dynamic address of the virtual target to predefined values in the DAT.

Stimulus:
- Create a valid DYNAMIC_ADDR and VIRTUAL_DYNAMIC_ADDR to be assigned to the target by the controller.
- Write DAT entries including the (VIRTUAL) DYNAMIC_ADDR
- Generate ENTDAA CCC to enter the dynamic address assignment mode and assign the DYNAMIC_ADDR and VIRTUAL_DYNAMIC_ADDR respectively (simulates ENTDAA for multiple targets).
- create a address assignment 64b CMD descriptor. With:
    - CMD_ATTR = 0x2 // Address Assignment Command
    - CMD: 0x07 // ENTDAA BCAST
    - DEV_INDEX: DAT Table Entry Containing the STATIC_ADDR and DYNAMIC_ADDR
- send CMD descriptor

Check:
  - After sending the ENTDAA CCC the response descriptor returns SUCCESS
  - After sending the ENTDAA CCC verify that the I3C_EC.STDBYCTRLMODE.STBY_CR_DEVICE_ADDR.DYNAMIC_ADDR holds the dynamic addresses specified in the DAT.
  - Verify that the DCT entries (starting at the index specified in the TABLE_INDEX field of the DCT_SECTION_OFFSET register) contain the PID, BCR, DCR and dynamic address of the (Virtual) target.

### `controller_ccc_setaasa`

Test: [controller_ccc_setaasa](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/i3c_axi_controller/test_controller_ccc.py)

Testbench:
I3C Controller (RTL) <-> I3C Target (RTL)

Intent:
Verify 5.1.9.3.23 Set All Addresses to Static Address (SETAASA) from I3C Basic Spec. Using Broadcast mode.
The test sets the dynamic address of the i3c target to the static target address.

Stimulus:
- randomly create a regular or immediate 64b CMD descriptor. With:
    - CMD_ATTR = 0x4 or 0x5// RegularDataTransfer or ImmediateDataTransfer in Direct Format
    - CMD: 0x29 // SETAASA BCAST
    - CP = 0x1 // CMD field is valid
    - DEV_ADDRESS: random allowed I3C address 
    - DTT/DATA_LENGTH = 0 // No Payload
    - RNW = 0x0 // Write transfer
    - WROC = random // randomly generate response descriptor
    - TOC = 0x1 // want to generate a stop signal after first transfer 
    - DATA_BYTE1 = 0x0 // is ignored
- send CMD descriptor

Check:
  - Read the I3C_EC.STDBYCTRLMODE.STBY_CR_DEVICE_ADDR.STATIC_ADDR CSR to get the target's static address.
  - Read the I3C_EC.STDBYCTRLMODE.STBY_CR_DEVICE_ADDR.DYNAMIC_ADDR CSR to get the target's dynamic address.
  - After sending the SETAASA CCC verify that the I3C_EC.STDBYCTRLMODE.STBY_CR_DEVICE_ADDR.DYNAMIC_ADDR holds the target's static address.

### `controller_ccc_setdasa`

Test: [controller_ccc_setdasa_direct](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/i3c_axi_controller/test_controller_ccc.py)

Testbench:
I3C Controller (RTL) <-> I3C Target (RTL)

Intent:
Verify 5.1.9.3.10 Set Dynamic Address from Static Address (SETDASA) from I3C Basic Spec. Using Direct mode.
The test sets the dynamic address of the i3c target using the I2C static target address.

Stimulus:
- Randomly generate a STATIC_ADDR and VIRTUAL_STATIC_ADDR and write them to the i3c target CSR.
- Create a valid DYNAMIC_ADDR and VIRTUAL_DYNAMIC_ADDR to be assigned to the target by the controller.
- Write DAT entries including the (VIRTUAL) STATIC_ADDR and (VIRTUAL) DYNAMIC_ADDR
- Generate 2 SETDASA CCCs to assign the DYNAMIC_ADDR and VIRTUAL_DYNAMIC_ADDR using STATIC_ADDR and VIRTUAL_STATIC_ADDR respectively (simulates SETDASA for multiple targets).
- create a address assignment 64b CMD descriptor. With:
    - CMD_ATTR = 0x2 // Address Assignment Command
    - CMD: 0x87 // SETDASA Direct
    - DEV_INDEX: DAT Table Entry Containing the STATIC_ADDR and DYNAMIC_ADDR
- send CMD descriptor

Check:
  - Read the I3C_EC.STDBYCTRLMODE.STBY_CR_DEVICE_ADDR.STATIC_ADDR CSR to get the target's static address.
  - Read the I3C_EC.STDBYCTRLMODE.STBY_CR_DEVICE_ADDR.DYNAMIC_ADDR CSR to get the target's dynamic address.
  - After sending the SETDASA CCC verify that the I3C_EC.STDBYCTRLMODE.STBY_CR_DEVICE_ADDR.DYNAMIC_ADDR holds the dynamic address that was sent.

### `controller_ccc_setnewda`

Test: [controller_ccc_setnewda](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/i3c_axi_controller/test_controller_ccc.py)

Testbench:
I3C Controller (RTL) <-> I3C Target (RTL)

Intent:
Verify 5.1.9.3.11 Set New Dynamic Address (SETNEWDA) from I3C Basic Spec. Using Direct mode.
The test sets a new dynamic address, using the old target dynamic address of the I3C target.

Stimulus:
- Initialize the target and virtual target with valid dynamic addressses.
- Create new valid DYNAMIC_ADDR and VIRTUAL_DYNAMIC_ADDR to be assigned to the target by the controller.
- Generate 2 SETNEWDA CCCs using the old DYNAMIC_ADDR and old VIRTUAL_DYNAMIC_ADDR and the new DYNAMIC_ADDR and VIRT_DYNAMIC_ADDR as payload.

Check:
  - Read the I3C_EC.STDBYCTRLMODE.STBY_CR_DEVICE_ADDR.DYNAMIC_ADDR CSR to get the target's dynamic address.
  - After sending the SETNEWDA CCC verify that the I3C_EC.STDBYCTRLMODE.STBY_CR_DEVICE_ADDR.DYNAMIC_ADDR holds the new dynamic address that was sent.

### `controller_ccc_getpid`

Test: [controller_ccc_getpid](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/i3c_axi_controller/test_controller_ccc.py)

Testbench:
I3C Controller (RTL) <-> I3C Target (RTL)

Intent:
Verify 5.1.9.3.12 Get Provisioned ID (GETPID) from I3C Basic Spec. Using Direct mode.
The test reads the targets PID.

Stimulus:
- Issue a GETPID CCC to the targets dynamic address.

Check:
  - Read the targets I3C_EC.STDBYCTRLMODE.STBY_CR_DEVICE_CHAR.PID_HI and I3C_EC.STDBYCTRLMODE.STBY_CR_DEVICE_PID_LO.PID_LO CSRs to get the full PID
  - Read the RX_PORT and verify that the data received by the controller matches the PID from the targets PID CSRs.

### `controller_ccc_getbcr`

Test: [controller_ccc_getbcr](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/i3c_axi_controller/test_controller_ccc.py)

Testbench:
I3C Controller (RTL) <-> I3C Target (RTL)

Intent:
Verify 5.1.9.3.13 Get Bus Characteristics Register (GETBCR) from I3C Basic Spec. Using Direct mode.
The test reads the targets BCR.

Stimulus:
- Issue a GETBCR CCC to the targets dynamic address.

Check:
  - Read the targets I3C_EC.STDBYCTRLMODE.STBY_CR_DEVICE_CHAR.BCR_VAR and I3C_EC.STDBYCTRLMODE.STBY_CR_DEVICE_CHAR.BCR_FIXED CSRs to get the full BCR
  - Read the RX_PORT and verify that the data received by the controller matches the BCR from the targets BCR CSRs.

### `controller_ccc_getdcr`

Test: [controller_ccc_getdcr](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/i3c_axi_controller/test_controller_ccc.py)

Testbench:
I3C Controller (RTL) <-> I3C Target (RTL)

Intent:
Verify 5.1.9.3.14 Get Device Characteristics Register (GETDCR) from I3C Basic Spec. Using Direct mode.
The test reads the targets DCR.

Stimulus:
- Issue a GETDCR CCC to the targets dynamic address.

Check:
  - Read the targets I3C_EC.STDBYCTRLMODE.STBY_CR_DEVICE_CHAR.DCR CSR to get the DCR
  - Read the RX_PORT and verify that the data received by the controller matches the DCR from the targets DCR CSR.


# Controller-specific CSR access check

## Testpoints

### `Test controller-specific CSR accesses`

Tests:
- [dat_csr_access](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_csr_access.py)- [dct_csr_access](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_csr_access.py)- [base_csr_access](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_csr_access.py)- [pio_csr_access](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_csr_access.py)

Walks over all CSRs, write random value using AHB/AXI, reads it back,
and compares with expected output.

### `Write to configuration register`

Test: [ec_stdby_cr_enable_init](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_csr_access.py)

Writes to the I3C_EC.StdbyCtrlMode.STBY_CR_CONTROL.STBY_CR_ENABLE_INIT register to enable controller mode or target mode. The DUT has 3 AXI ports for its 3 instantiations of the i3c core. Port 0 is for the expected target. Port 1 is for the actual controller and Port 2 is for the actual target. This test writes only to the above mentioned CSR for each of the ports. This will be used to configure the i3c cores in their operation mode. To verify the test reads the ports back and checks if it matches.

### `Configure Target and Controller`

Test: [configure_target_and_controller](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_csr_access.py)

Writes to the I3C_EC.StdbyCtrlMode.STBY_CR_CONTROL.STBY_CR_ENABLE_INIT register to enable controller mode or target mode. The DUT has 3 AXI ports for its 3 instantiations of the i3c core. Port 0 is for the expected target. Port 1 is for the actual controller and Port 2 is for the actual target. This test writes only to the above mentioned CSR for each of the ports. This will be used to configure the i3c cores in their operation mode. To verify the test reads the ports back and checks if it matches. Write 0'b10 to Port 0 and Port 2. Write 0'b11 to Port 1.

### `Timing CSR checks`

Test: [check_timing_csr](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_csr_access.py)

Testbench:
I3C Controller (RTL)

Intent:
Read the CSRs holding the timing values specified in 6.2 Timing Specification (I3C Basic Spec) and check that they are in the limits of the Spec.

Stimulus:
- Provide the I3C controller clk frequency.
- Write timing parameters into the I3C_EC.SOCMGMTIF.T_* CSRs.

Check:
- Read each timing CSR and verify that the time adheres to the limits in the spec.


# Controller error generation

## Testpoints

### `Controller Error 2: No response to Broadcast Address (7'h7E)`

Test: [controller_error_nack_on_bcast](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/i3c_axi_controller_err/test_controller_error.py)

Testbench:
I3C Controller (RTL) <-> I3C Target (Cocotbext)

Intent:
Handle 5.1.10.2.3 Error Type CE2 I3C Basic Spec.

Stimulus:
- send a SETDASA CCC to assign a dynamic address to the i3c target
- enable bcast nack error injection on the Cocotbext Target
- send an ENEC CCC (this will get NACKed)
- Clear HC_CONTROL.RESUME and PIO_INTR_STATUS.TRANSFER_ERR_STAT to resume normal operation.
- send an ENEC CCC

Check:
  - Observe a NACK for the ENEC CCC.
  - After NACK the Controller should generate a HDR Exit Pattern.
  - Check if the target recognizes the HDR Exit Pattern by monitoring the cocotbext targets `hdr_exit_detected` variable.
  - After the Broadcast Address NACK the controller should return a response descriptor with Error Status: ADDRESS_HEADER.
  - Check if subsequent ENEC CCC finishes as expected.

### `Controller TX Queue Underflow`

Test: [controller_tx_queue_underflow](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/i3c_axi_controller_err/test_controller_error.py)

Testbench:
I3C Controller (RTL) <-> I3C Target (Cocotbext)

Intent:
Handle 6.13.1.2 Underflow Error I3C HCI Spec.

Stimulus:
- send a SETDASA CCC to assign a dynamic address to the i3c target
- Write an I3C Write CMD desc specifying the write length to be i3c_target_len
- generate act_len < i3c_target_len bytes of data and write into TX Queue
- Clear HC_CONTROL.RESUME and PIO_INTR_STATUS.TRANSFER_ERR_STAT to resume normal operation.
- send a regular I3C Write

Check:
  - After the TX Queue underflow the controller should return a response descriptor with Error Status: OVL.
  - After the regular I3C Write the controller should return a response descriptor with Error Status: SUCCESS.

### `Controller RX Queue Overflow`

Test: [controller_rx_queue_overflow](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/i3c_axi_controller_err/test_controller_error.py)

Testbench:
I3C Controller (RTL) <-> I3C Target (Cocotbext)

Intent:
Handle 6.13.1.2 Overflow Error I3C HCI Spec.

Stimulus:
- send a SETDASA CCC to assign a dynamic address to the i3c target
- Write an I3C Read CMD desc specifying the write length to be i3c_target_len > RX_QUEUE_DEPTH * 4
- don't read any data from the RX Queue 
- Clear HC_CONTROL.RESUME and PIO_INTR_STATUS.TRANSFER_ERR_STAT to resume normal operation.
- Flush the RX Queue by setting the I3CBASE.RESET_CONTROL.RX_FIFO_RST CSR
- send a regular I3C Read

Check:
  - After the RX Queue overflow the controller should return a response descriptor with Error Status: OVL.
  - After the regular I3C Read the controller should return a response descriptor with Error Status: SUCCESS.

### `Controller CE0 Handling (illegally formatted CCC)`

Test: [controller_error_short_ccc_ce0](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/i3c_axi_controller_err/test_controller_error.py)

Testbench:
I3C Controller (RTL) <-> I3C Target (Cocotbext)

Intent:
Handle 5.1.10.2.1 Error Type CE0 I3C Basic Spec (illegally formatted CCC).

Stimulus:
- send a SETDASA CCC to assign a dynamic address to the i3c target
- send a GETPID CCC with the data length field set to 6 bytes.
- target returns less than 6 bytes. After the controller retries the CCC, the target should return the correct PID (6 bytes).
- send another GETPID CCC with the data length field set to 6 bytes.
- target returns less than 6 bytes. After the controller retries the CCC, the target should still return less than 6 bytes.
- Clear HC_CONTROL.RESUME and PIO_INTR_STATUS.TRANSFER_ERR_STAT to resume normal operation.
- send another GETPID CCC with the data length field set to 6 bytes.
- target returns the correct PID (6 bytes).
- send a private i3c Write.

Check:
- after the first GETPID CCC the response descriptor should report SUCCESS (the controller should automatically recover the error by retrying, this is transparent to SW).
- after the second GETPID CCC the response descriptor should report I3C_SHORT_READ.
- after the third GETPID CCC the response descriptor should report SUCCESS.
- after the private i3c write the response descriptor should report SUCCESS.

### `Controller Abort Transaction`

Test: [hc_abort](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/i3c_axi_controller_err/test_controller_error.py)

Testbench:
I3C Controller (RTL) <-> I3C Target (Cocotbext)

Intent:
Handle 6.8.4 Host Controller Abort Operation I3C HCI Spec.

Stimulus:
- send a SETDASA CCC to assign a dynamic address to the i3c target
- set PIO_CONTROL.RS CSR field to 1'b0
- enqueue 2 private i3c write command descriptors with their respective TX data into the CMD/TX Queues.
- set PIO_CONTROL.RS CSR field to 1'b1 to start execution.
- set HC_CONTROL.ABORT CSR field to 1'b1 to abort current transaction.
- set HC_CONTROL.ABORT and PIO_CONTROL.ABORT CSR fields to 1'b0 and HC_CONTROL.RESUME CSR field to 1'b1 to resume operation.
- set RESET_CONTROL.TX_FIFO_RST CSR field to 1'b1 to flush TX Queue.
- requeue the data for the 2nd i3c write into the TX Queue.

Check:
- the response descriptor for the first private write cmd should report HC_ABORTED as an error status.
- the response descriptor for the second private write cmd should report SUCCESS and the data received by the target should match the data sent by the controller.

### `Command Sequence Timeout (no halt)`

Test: [cmd_seq_timeout_no_halt](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/i3c_axi_controller_err/test_controller_error.py)

Testbench:
I3C Controller (RTL) <-> I3C Target (Cocotbext)

Intent:
Handle 6.13.2 Errors Due to Command Sequence Stall or Timeout I3C HCI Spec without halting execution.

Stimulus:
- send a SETDASA CCC to assign a dynamic address to the i3c target.
- set HC_CONTROL.HALT_ON_CMD_SEQ_TIMEOUT CSR field to 1'b0 to enable auto-resume on cmd seq timeout.
- send a private write cmd descriptor with the TOC field set to 1'b0.
- read the INTR_STATUS.HC_ERR_CMD_SEQ_TIMEOUT_STAT & INTR_STATUS.HC_SEQ_CANCEL_STAT interrupt CSRs.
- clear the interrupts by writing 1'b1 to INTR_STATUS.HC_ERR_CMD_SEQ_TIMEOUT_STAT & INTR_STATUS.HC_SEQ_CANCEL_STAT CSR fields.
- send a second private write cmd descriptor with the TOC field set to 1'b1.

Check:
- the response descriptor for the first private write cmd should report SUCCESS and the data received by the target should match the data sent by the controller.
- the INTR_STATUS.HC_ERR_CMD_SEQ_TIMEOUT_STAT & INTR_STATUS.HC_SEQ_CANCEL_STAT interrupt CSRs should both be set to 1'b1.
- the response descriptor for the second private write cmd should report SUCCESS and the data received by the target should match the data sent by the controller.

### `Command Sequence Timeout (halt)`

Test: [cmd_seq_timeout_halt](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/i3c_axi_controller_err/test_controller_error.py)

Testbench:
I3C Controller (RTL) <-> I3C Target (Cocotbext)

Intent:
Handle 6.13.2 Errors Due to Command Sequence Stall or Timeout I3C HCI Spec with halting the execution.

Stimulus:
- send a SETDASA CCC to assign a dynamic address to the i3c target.
- set HC_CONTROL.HALT_ON_CMD_SEQ_TIMEOUT CSR field to 1'b1 to enable halting on cmd seq timeout.
- send a private write cmd descriptor with the TOC field set to 1'b0.
- read the INTR_STATUS.HC_ERR_CMD_SEQ_TIMEOUT_STAT & INTR_STATUS.HC_SEQ_CANCEL_STAT interrupt CSRs.
- clear the interrupts by writing 1'b1 to INTR_STATUS.HC_ERR_CMD_SEQ_TIMEOUT_STAT & INTR_STATUS.HC_SEQ_CANCEL_STAT CSR fields.
- resume operation by writing 1'b1 to the HC_CONTROL.RESUME CSR field.
- send a second private write cmd descriptor with the TOC field set to 1'b1.

Check:
- the response descriptor for the first private write cmd should report SUCCESS and the data received by the target should match the data sent by the controller.
- the INTR_STATUS.HC_ERR_CMD_SEQ_TIMEOUT_STAT & INTR_STATUS.HC_SEQ_CANCEL_STAT interrupt CSRs should both be set to 1'b1.
- the response descriptor for the second private write cmd should report SUCCESS and the data received by the target should match the data sent by the controller.

### `Interrupt Routing and Masking`

Test: [interrupt_routing_and_masking](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/i3c_axi_controller_err/test_controller_error.py)

Testbench:
I3C Controller (RTL) <-> I3C Target (Cocotbext)

Intent:
Systematically verify the two-tier interrupt masking architecture (STATUS_ENABLE and SIGNAL_ENABLE) 6.14 Interrupts I3C HCI Spec.

Stimulus:
Loop through a predefined list of all interrupt fields. For each field:
- Write 1'b0 to both the STATUS_ENABLE and SIGNAL_ENABLE CSR fields.
- Write 1'b1 to the corresponding FORCE CSR field.
- Write 1'b1 to the STATUS_ENABLE CSR field, then write 1'b1 to the FORCE CSR field again.
- Write 1'b1 to the SIGNAL_ENABLE CSR field.
- Write 1'b1 to the STATUS CSR field to clear the interrupt.

Check:
For each interrupt field in the loop:
- After the first force, the STATUS CSR field should remain 1'b0 (verifies STATUS_ENABLE masking).
- After the second force, the STATUS CSR field should be 1'b1, but the physical `irq_o` pin should remain 1'b0 (verifies SIGNAL_ENABLE masking).
- After setting SIGNAL_ENABLE, the physical `irq_o` pin should assert to 1'b1 (verifies hardware signal routing).
- After writing to the STATUS CSR field, both the STATUS CSR field and the physical `irq_o` pin should de-assert to 1'b0 (verifies W1C clearing).


# Controller Generate HDR Exit Pattern

## Testpoints

### `Controller Generate HDR Exit Pattern`

Test: [controller_gen_hdr_exit_pattern](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/i3c_axi_controller/test_controller_hdr_exit.py)

Testbench:
I3C Controller (RTL) <-> I3C Target (RTL)

Intent:
Generate HDR exit pattern, as per 5.2.1.1.1 I3C Basic Spec.

Stimulus:
- Send an Internal Control Command (Table 140 I3C HCI Spec) with:
  - MIPI_CMD: 0x5 // Controller SDA Recovery or Bus Reset Procedure
  - REC_RESET_PROC: 0x5 // Use CE2 error handling for a non-responsive I3C Target, by sending HDR Exit Pattern after NACK of Private read/write.
- Send an I3C private read or private write to an unassigned target address.
- Send an I3C private private write to the correct target address.

Check:
  - Observe a NACK for the I3C private Read or Write.
  - After NACK the Controller should generate a HDR Exit Pattern.
  - Check if the target recognizes the HDR Exit Pattern by monitoring the cocotbext targets `hdr_exit_detected` variable.
  - Check if subsequent private write finishes as expected.


# Controller Hot-Join procedure for a new target

## Testpoints

### `Controller Handle a Hot-Join Request from the target`

Test: controller_hot_join

Recognize the Hot-Join pattern as specified in 5.1.5 I3C Basic Spec and eventually initiate a ENTDAA CCC to assign a dynamic address to the new target. Perform simple write/read to from target to verify target has joined correctly.


# Controller I2C Transaction

## Testpoints

### `i2c_private_write`

Test: i2c_private_write

Testbench:
I3C Controller (RTL) <-> I2C Target (Cocotbext)

Intent:
Verify Private Write with Immediate Data Transfer Command Descriptor (7.2.2.1 TCRI Spec) or Regular Data Transfer Command Descriptor (7.2.2.2 TCRI Spec) to an individual I2C Target Device with known address

Stimulus:
 - create a CMD descriptor setting the I2C field to 0x1. The first data byte is the internal memory address (from which the monitor will read the data received by the target) the remaining data bytes are randomized.
Check:
    - Read data from the I2C target memory by reading from the memory address specified in the first data byte. 
    - Assert that the received data matches the sent data.
    - Assert that the response descriptor returns the correct data length (including first memory address byte) and a SUCCESS status.

### `i2c_private_read`

Test: i2c_private_read

Testbench:
I3C Controller (RTL) <-> I2C Target (Cocotbext)

Intent:
Verify Private Read with Immediate Data Transfer Command Descriptor (7.2.2.1 TCRI Spec) or Regular Data Transfer Command Descriptor (7.2.2.2 TCRI Spec) to an individual I2C Target Device with known address

Stimulus:
 - Write `target_len` random bytes to the cocotbext I2C memory.
 - create a CMD descriptor setting the I2C field to 0x1. Write a data byte for the internal memory address (from which the target will send the data), set the TOC field to 0x0 to issue a repeated Start.
 - create a second CMD descriptor setting the I2C field to 0x1. Set the data_length to `target_len` and the RnW field to 0x1 for a Read transaction.
Check:
    - Read received data from the Controller RX Queue and verify it matches the data written to the I2C target.
    - Assert that the response descriptors return the correct data length (including first memory address byte) and a SUCCESS status.

### `i2c_handle_nack`

Test: i2c_handle_nack

Testbench:
I3C Controller (RTL) <-> I2C Target (Cocotbext)

Intent:
Handle a NACK by the I2C target during a private write.

Stimulus:
 - set the I2C target memory length to be less than the data length to be written (such that we can generate a NACK condition)
 - create a CMD descriptor setting the I2C field to 0x1. The first data byte is the internal memory address (from which the monitor will read the data received by the target) the remaining data bytes are randomized.
Check:
    - Assert that the response descriptor returns a NACK Error State.


# Controller IBI Handling

## Testpoints

### `controller_ibi_accepted`

Test: [controller_ibi_accepted](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/i3c_axi_controller/test_controller_ibi.py)

Testbench:
I3C Controller (RTL) <-> I3C Target (RTL)

Intent:
Verify 5.1.6 In-Band Interrupt from I3C Basic Spec. Using Broadcast mode.
The target sends an IBI request with a mandatory data byte as well as optional data bytes and the controller accepts the request and pushes the results to the IBI_PORT.

Stimulus:
  - write a Target IBI Descriptor to the Targets TTI.IBI_PORT register containing the MDB and optional IBI payload.
  - Enable generation of the I3C Broadcast Header before private reads and writes using the internal control command descriptor with the following fields set:
    - mipi_cmd=0x2 // Broadcast Address Enable/Disable
    - mipi_rsvd=0x1 // Broadcast Address Enable
  - send a private i3c write.

Check:
  - The private write should finish correctly. 
  - Read the PIOCONTROL.IBI_PORT CSR to retreive the IBI Status Descriptor as well as the IBI Payload.
  - IBI Status Descriptor Error should be 1'b0 (not aborted by controller).
  - The IBI Payload should match the MDB sent to the target as well as the optional IBI data bytes sent by the target.

### `controller_ibi_buffer_overflow`

Test: [controller_ibi_buffer_overflow](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/i3c_axi_controller/test_controller_ibi.py)

Testbench:
I3C Controller (RTL) <-> I3C Target (RTL)

Intent:
Verify 5.1.6 In-Band Interrupt from I3C Basic Spec. Using Broadcast mode.
The target sends an IBI request with a mandatory data byte as well as optional data bytes and the controller rejects the request (due to an internal buffer overflow) and pushes the results to the IBI_PORT.

Stimulus:
  - write a Target IBI Descriptor to the Targets TTI.IBI_PORT register containing the MDB and optional IBI payloads with total byte length larger than IBIDataBuffer.
  - Enable generation of the I3C Broadcast Header before private reads and writes using the internal control command descriptor with the following fields set:
    - mipi_cmd=0x2 // Broadcast Address Enable/Disable
    - mipi_rsvd=0x1 // Broadcast Address Enable
  - send a private i3c write.

Check:
  - The private write should finish correctly. 
  - Read the PIOCONTROL.IBI_PORT CSR to retreive the IBI Status Descriptor as well as the IBI Payload.
  - IBI Status Descriptor Error should be 1'b1 (aborted by controller).
  - The first IBIDataBuffer bytes of IBI Payload should match the MDB sent to the target as well as the optional IBI data bytes sent by the target.

### `controller_ibi_rejected`

Test: [controller_ibi_rejected](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/i3c_axi_controller/test_controller_ibi.py)

Testbench:
I3C Controller (RTL) <-> I3C Target (RTL)

Intent:
Verify rejecting IBI as per 5.1.6.2 I3C Target Interrupt Request from I3C Basic Spec.

Stimulus:
  - write a DAT entry for the target, setting the IBI_REJECT and IBI_PAYLOAD fields to 1'b1.
  - write a Target IBI Descriptor to the Targets TTI.IBI_PORT register containing the MDB and optional IBI payloads.
  - Enable generation of the I3C Broadcast Header before private reads and writes using the internal control command descriptor with the following fields set:
    - mipi_cmd=0x2 // Broadcast Address Enable/Disable
    - mipi_rsvd=0x1 // Broadcast Address Enable

Check:
  - Read the PIOCONTROL.IBI_PORT CSR to retreive the IBI Status Descriptor as well as the IBI Payload.
  - IBI Status Descriptor ID should contain the targets dynamic address.
  - IBI Status Descriptor Error should be 1'b0.
  - IBI Status Descriptor Status should be 1'b1 (NACK by Controller).


# Controller Private Read

## Testpoints

### `i3c_private_read_no_edge_case`

Test: [i3c_private_read_no_edge_case](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/i3c_axi_controller/test_i3c_controller_read_target_write.py)

Testbench:
I3C Controller (RTL) <-> I3C Target (RTL)

Intent:
Verify Private Read with Regular Data Transfer Command (7.2.2.2 TCRI Spec) from an individual I3C Target Device with known static address
Data Length should be between RX_STAT_THLD*4 and RX_QUEUE_DEPTH*4 and target provides exactly the requested amount of data.

Stimulus:
- create a 64b CMD descriptor as per Table 18 7.2.2.2 TCRI Spec. With:
    - CMD_ATTR = 0x4 // RegularDataTransfer in Direct Format
    - TID: random transaction ID
    - I2C = 0x0 // I3C device
    - CMD: random this field is disregarded
    - CP = 0x0 // CMD field is not valid
    - DEV_ADDRESS: random allowed I3C address 
    - DTT: number of bytes to be transferred
    - MODE = 0x0 // standard I3C SDR Speed
    - RNW = 0x1 // Read transfer
    - WROC = 0x1 // generate response descriptor
    - TOC = 0x1 // want to generate a stop signal after first transfer 
    - DATA_BYTES: random between RX_STAT_THLD*4 and RX_QUEUE_DEPTH*4 (no edge cases) 

- split the 64b descriptor into 2 32b words (DWORD) and first write the lower DWORD into the COMMAND_PORT PIO reg followed by the upper DWORD.
- Generate Random Data and send it via the TTI TX_DATA_PORT to the target. 
- Send a TTI_TX_DESC to the target specifying the data length.

Check:
  - data read from controller RX_DATA_PORT matches data sent to TX_DATA_PORT
  - if WROC = 1: response descriptor data length matches data bytes specified in CMD desc, and resp desc TID matches TID form CMD desc.

### `i3c_private_read_short_read`

Test: [i3c_private_read_short_read](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/i3c_axi_controller/test_i3c_controller_read_target_write.py)

Testbench:
I3C Controller (RTL) <-> I3C Target (RTL)

Intent:
Verify Private Read with Regular Data Transfer Command (7.2.2.2 TCRI Spec) from an individual I3C Target Device with known static address
Data Length should be between RX_STAT_THLD*4 and RX_QUEUE_DEPTH*4 and target provides less than the requested amount of data.

Stimulus:
- create a 64b CMD descriptor as per Table 18 7.2.2.2 TCRI Spec. With:
    - CMD_ATTR = 0x4 // RegularDataTransfer in Direct Format
    - TID: random transaction ID
    - I2C = 0x0 // I3C device
    - CMD: random this field is disregarded
    - CP = 0x0 // CMD field is not valid
    - DEV_ADDRESS: random allowed I3C address 
    - DTT: number of bytes to be transferred
    - SRE = 0x1 // should give an error when target aborts read too early
    - MODE = 0x0 // standard I3C SDR Speed
    - RNW = 0x1 // Read transfer
    - WROC = 0x1 // generate response descriptor
    - TOC = 0x1 // want to generate a stop signal after first transfer 
    - DATA_BYTES: random between RX_STAT_THLD*4 and RX_QUEUE_DEPTH*4 (no edge cases)

- split the 64b descriptor into 2 32b words (DWORD) and first write the lower DWORD into the COMMAND_PORT PIO reg followed by the upper DWORD.
- Generate Random Data and send it via the TTI TX_DATA_PORT to the target. 
- Send a TTI_TX_DESC to the target specifying the data length to be less than DATA_BYTES (still more than RX_STAT_THLD).

Check:
  - data read from controller RX_DATA_PORT matches data sent to TX_DATA_PORT
  - if WROC = 1: response descriptor data length matches data bytes specified in CMD desc, and resp desc TID matches TID form CMD desc.
  - response descriptor error should be I3C short read status.

### `i3c_private_read_repeated_start`

Test: [i3c_private_read_repeated_start](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/i3c_axi_controller/test_i3c_controller_read_target_write.py)

Testbench:
I3C Controller (RTL) <-> I3C Target (RTL)

Intent:
Verify Chaining multiple Private Reads with Regular Data Transfer Command (7.2.2.2 TCRI Spec) from an individual I3C Target Device with known static address using repeated start condition.
Data Length should be between RX_STAT_THLD*4 and RX_QUEUE_DEPTH*4.

Stimulus:
- create a 64b CMD descriptor as per Table 18 7.2.2.2 TCRI Spec. With:
    - CMD_ATTR = 0x4 // RegularDataTransfer in Direct Format
    - TID: random transaction ID
    - I2C = 0x0 // I3C device
    - CMD: random this field is disregarded
    - CP = 0x0 // CMD field is not valid
    - DEV_ADDRESS: random allowed I3C address 
    - DTT: number of bytes to be transferred
    - SRE: random // randomly either generate error on short read or not
    - MODE = 0x0 // standard I3C SDR Speed
    - RNW = 0x1 // Read transfer
    - WROC = random // randomly generate response descriptor
    - TOC = 0x0 // want to use repeated start 
    - DATA_BYTES: random between RX_STAT_THLD*4 and RX_QUEUE_DEPTH*4 (no edge cases)

- split the 64b descriptor into 2 32b words (DWORD) and first write the lower DWORD into the COMMAND_PORT PIO reg followed by the upper DWORD.
- Generate Random Data and send it via the TTI TX_DATA_PORT to the target. 

Check:
  - data read from controller RX_DATA_PORT matches data sent to TX_DATA_PORT


# Controller resets target

## Testpoints

### `Reset target`

Test: controller_resets_target

Reset a target according to 5.1.11 I3C Basic Spec. (using RSTACT CCC)


# Controller Private Write

## Testpoints

### `i3c_private_write_correct_bus_condition`

Test: [i3c_private_write_correct_bus_condition](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/i3c_axi_controller/test_i3c_controller_write_target_read.py)

Testbench:
I3C Controller (RTL) <-> I3C Target (RTL)

Intent:
Verify Private Write with Immediate Data Transfer Command Descriptor (7.2.2.1 TCRI Spec) to an individual I3C Target Device with known static address

Stimulus:
 - create a CMD 64b descriptor as per Table 16 7.2.2.1 TCRI Spec. With:
    - CMD_ATTR = 0x5 // ImmediateDataTransfer in Direct Format
    - TID: random transaction ID
    - I2C = 0x0 // I3C device
    - CMD: random this field is disregarded
    - CP = 0x0 // CMD field is not valid
    - DEV_ADDRESS: random allowed I3C address 
    - DTT: number of bytes to be transferred
    - MODE = 0x0 // standard I3C SDR Speed
    - RNW = 0x0 // Write transfer
    - WROC = 0x0 // no response  
    - TOC = 0x1 // want to generate a stop signal after first transfer 
    - DATA_BYTES: random data to be sent
- split the 64b descriptor into 2 32b words (DWORD) and first write the lower DWORD into the COMMAND_PORT PIO reg followed by the upper DWORD.

Check:
    - correct start/restart condition is generated 
    - check that following data bytes are correctly serialized (from MSB to LSB)
    - check that T bit is correctly generated
    - first byte is DEV_ADDRESS
    - following DTT bytes is DATA_BYTES
    - correct stop condition is generated

### `i3c_private_write_target_read`

Test: [i3c_private_write_target_read](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/i3c_axi_controller/test_i3c_controller_write_target_read.py)

Testbench:
I3C Controller (RTL) <-> I3C Target (RTL)

Intent:
Verify Private Write with Immediate Data Transfer Command Descriptor (7.2.2.1 TCRI Spec) to an individual I3C Target Device with known static address

Stimulus:
 - create a CMD 64b descriptor as per Table 16 7.2.2.1 TCRI Spec. With:
    - CMD_ATTR = 0x5 // ImmediateDataTransfer in Direct Format
    - TID: random transaction ID
    - I2C = 0x0 // I3C device
    - CMD: random this field is disregarded
    - CP = 0x0 // CMD field is not valid
    - DEV_ADDRESS: random allowed I3C address 
    - DTT: number of bytes to be transferred
    - MODE = 0x0 // standard I3C SDR Speed
    - RNW = 0x0 // Write transfer
    - WROC = 0x0 // no response  
    - TOC = 0x1 // want to generate a stop signal after first transfer 
    - DATA_BYTES: random data to be sent
- split the 64b descriptor into 2 32b words (DWORD) and first write the lower DWORD into the COMMAND_PORT PIO reg followed by the upper DWORD.

Check:
  - DATA_BYTES are equal to recv data from the target I3C_EC.TTI.RX_DATA_PORT CSR.

### `i3c_private_write_target_read_resp_desc`

Test: [i3c_private_write_target_read_resp_desc](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/i3c_axi_controller/test_i3c_controller_write_target_read.py)

Testbench:
I3C Controller (RTL) <-> I3C Target (RTL)

Intent:
Verify Private Write with Immediate Data Transfer Command Descriptor (7.2.2.1 TCRI Spec) to an individual I3C Target Device with known static address

Stimulus:
 - create a CMD 64b descriptor as per Table 16 7.2.2.1 TCRI Spec. With:
    - CMD_ATTR = 0x5 // ImmediateDataTransfer in Direct Format
    - TID: random transaction ID
    - I2C = 0x0 // I3C device
    - CMD: random this field is disregarded
    - CP = 0x0 // CMD field is not valid
    - DEV_ADDRESS: random allowed I3C address 
    - DTT: number of bytes to be transferred
    - MODE = 0x0 // standard I3C SDR Speed
    - RNW = 0x0 // Write transfer
    - WROC = 0x1 // write response descriptor
    - TOC = 0x1 // want to generate a stop signal after first transfer 
    - DATA_BYTES: random data to be sent
- split the 64b descriptor into 2 32b words (DWORD) and first write the lower DWORD into the COMMAND_PORT PIO reg followed by the upper DWORD.

Check:
  - DATA_BYTES are equal to recv data from the target I3C_EC.TTI.RX_DATA_PORT CSR.
  - Read Response Descriptor to verify TID and Data Length match the CMD Descriptor and Error Status is Success.

### `i3c_private_write_wrong_target_addr`

Test: [i3c_private_write_wrong_target_addr](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/i3c_axi_controller/test_i3c_controller_write_target_read.py)

Testbench:
I3C Controller (RTL) <-> I3C Target (RTL)

Intent:
Verify that Private Write to a non existing target address generates a NACK Response Descriptor.

Stimulus:
 - create a CMD 64b descriptor as per Table 16 7.2.2.1 TCRI Spec. With:
    - CMD_ATTR = 0x5 // ImmediateDataTransfer in Direct Format
    - TID: random transaction ID
    - I2C = 0x0 // I3C device
    - CMD: random this field is disregarded
    - CP = 0x0 // CMD field is not valid
    - DEV_ADDRESS: random allowed I3C address 
    - DTT: number of bytes to be transferred
    - MODE = 0x0 // standard I3C SDR Speed
    - RNW = 0x0 // Write transfer
    - WROC = 0x1 // write response descriptor
    - TOC = 0x1 // want to generate a stop signal after first transfer 
    - DATA_BYTES: random data to be sent
- split the 64b descriptor into 2 32b words (DWORD) and first write the lower DWORD into the COMMAND_PORT PIO reg followed by the upper DWORD.

Check:
  - DATA_BYTES are equal to recv data from the target I3C_EC.TTI.RX_DATA_PORT CSR.
  - Read Response Descriptor to verify TID matches the CMD Descriptor and Data Length is 0 and Error Status is NACK.

### `i3c_private_write_tx_queue_target_read`

Test: [i3c_private_write_tx_queue_target_read](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/i3c_axi_controller/test_i3c_controller_write_target_read.py)

Testbench:
I3C Controller (RTL) <-> I3C Target (RTL)

Intent:
Verify Private Write with Regular Data Transfer Command (7.2.2.2 TCRI Spec) to an individual I3C Target Device with known static address

Stimulus:
- create a 64b descriptor as per Table 18 7.2.2.2 TCRI Spec. With:
    - CMD_ATTR = 0x4 // RegularDataTransfer in Direct Format
    - TID: random transaction ID
    - I2C = 0x0 // I3C device
    - CMD: random this field is disregarded
    - CP = 0x0 // CMD field is not valid
    - DEV_ADDRESS: random allowed I3C address 
    - SHORT_READ_ERR = 0 // no read
    - DBP = 0 // no def byte
    - MODE = 0x0 // standard I3C SDR Speed
    - RNW = 0x0 // Write transfer
    - WROC: random // randomly generate response descriptor 
    - TOC = 0x1 // want to generate a stop signal after first transfer 
    - DEF_BYTE: random // this is disregarded
    - DATA_LENGTH: length of data transfer (1 < DATA_LENGTH < TX_QUEUE_DEPTH*4) // Indicates the number of bytes to be transferred
- split the 64b descriptor into 2 32b words (DWORD) and first write the lower DWORD into the COMMAND_PORT PIO reg followed by the upper DWORD.

Check:
  - data being sent via TX_DATA_PORT is equal to data on the target I3C_EC.TTI.RX_DATA_PORT CSR.

### `i3c_private_write_tx_queue_target_read_fifo_full`

Test: [i3c_private_write_tx_queue_target_read_fifo_full](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/i3c_axi_controller/test_i3c_controller_write_target_read.py)

Testbench:
I3C Controller (RTL) <-> I3C Target (RTL)

Intent:
Verify Private Write with Regular Data Transfer Command (7.2.2.2 TCRI Spec) to an individual I3C Target Device with known static address

Stimulus:
- create a 64b descriptor as per Table 18 7.2.2.2 TCRI Spec. With:
    - CMD_ATTR = 0x4 // RegularDataTransfer in Direct Format
    - TID: random transaction ID
    - I2C = 0x0 // I3C device
    - CMD: random this field is disregarded
    - CP = 0x0 // CMD field is not valid
    - DEV_ADDRESS: random allowed I3C address 
    - SHORT_READ_ERR = 0 // no read
    - DBP = 0 // no def byte
    - MODE = 0x0 // standard I3C SDR Speed
    - RNW = 0x0 // Write transfer
    - WROC = 0x1 // write response descriptor
    - TOC = 0x1 // want to generate a stop signal after first transfer 
    - DEF_BYTE: random // this is disregarded
    - DATA_LENGTH: length of data transfer (TX_QUEUE_DEPTH*4 < DATA_LENGTH < TX_QUEUE_DEPTH*4*3) // Indicates the number of bytes to be transferred
- split the 64b descriptor into 2 32b words (DWORD) and first write the lower DWORD into the COMMAND_PORT PIO reg followed by the upper DWORD.

Check:
  - data being sent via TX_DATA_PORT is equal to data on the target I3C_EC.TTI.RX_DATA_PORT CSR.

### `i3c_private_write_repeated_start`

Test: [i3c_private_write_repeated_start](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/i3c_axi_controller/test_i3c_controller_write_target_read.py)

Testbench:
I3C Controller (RTL) <-> I3C Target (RTL)

Intent:
Verify Chaining Private Writes with Regular Data Transfer Command (7.2.2.2 TCRI Spec) to an individual I3C Target Device with known static address using Sr condition.

Stimulus:
- create 5 64b CMD descriptors as per Table 18 7.2.2.2 TCRI Spec. With:
    - CMD_ATTR = 0x4 // RegularDataTransfer in Direct Format
    - TID: random transaction ID
    - I2C = 0x0 // I3C device
    - CMD: random this field is disregarded
    - CP = 0x0 // CMD field is not valid
    - DEV_ADDRESS: random allowed I3C address 
    - SHORT_READ_ERR = 0 // no read
    - DBP = 0 // no def byte
    - MODE = 0x0 // standard I3C SDR Speed
    - RNW = 0x0 // Write transfer
    - WROC: random // randomly generate response descriptor 
    - TOC = 0x0 // we want to test repeated start
    - DEF_BYTE: random // this is disregarded
    - DATA_LENGTH: length of data transfer (1 < DATA_LENGTH < TX_QUEUE_DEPTH*4*3) // Indicates the number of bytes to be transferred
- split the 64b descriptor into 2 32b words (DWORD) and first write the lower DWORD into the COMMAND_PORT PIO reg followed by the upper DWORD.

Check:
  - data being sent via TX_DATA_PORT is equal to data on the target I3C_EC.TTI.RX_DATA_PORT CSR.

### `i3c_private_write_dat`

Test: [i3c_private_write_dat](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/i3c_axi_controller/test_i3c_controller_write_target_read.py)

Testbench:
I3C Controller (RTL) <-> I3C Target (RTL)

Intent:
Verify Private Write as per 7.1.2.1 / 7.1.2.2 TCRI Spec to an individual I3C Target Device with known DAT index

Stimulus:
 - Assign dynamic address of device to DAT index 
 - create a CMD 64bit descriptor as per Table 7 7.1.2.1 TCRI Spec. With:
    - CMD_ATTR = 0x1 / 0x0 // ImmediateDataTransfer in DAT Format / Regular Transfer Command in DAT Format
    - DEV_INDEX: random 5 bit number 
    - RNW = 0x0 // Write transfer
    - DATA_BYTES: random data to be sent
- split the 64bit descriptor into 2 32bit words (DWORD) and first write the lower DWORD into the COMMAND_PORT PIO reg followed by the upper DWORD.

Check:
  - data being sent via TX_DATA_PORT is equal to data on the target I3C_EC.TTI.RX_DATA_PORT CSR. 
  - response descriptor data length matches data bytes specified in CMD desc, resp desc TID matches TID form CMD desc and resp error status is SUCCESS.



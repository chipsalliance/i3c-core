# bus_monitor

[Source file](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/block/ctrl_bus_monitor/test_bus_monitor.py)

[Test results](./sim-results/bus_monitor.html){.external}

## Testpoints

### `bus_monitor`

Test: [`bus_monitor`](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/block/ctrl_bus_monitor/test_bus_monitor.py#L47)

Tests operation of the bus_monitor module along with its sub-modules.
Performs a number of I3C transactions between a simulated controller
and a simulated target. Counts start, repeated start and stop events
reported by bus_monitor. Verifies that the counts match what's expected.


# bus_rx_flow

[Source file](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/block/bus_rx_flow/test_bus_rx_flow.py)

[Test results](./sim-results/bus_rx_flow.html){.external}

## Testpoints

### `multiple_bit_reads`

Test: [`multiple_bit_reads`](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/block/bus_rx_flow/test_bus_rx_flow.py#L57)

Drives SCL line with a steady clock, issues multiple bit read
requests, verifies that the module returns correct data sampled
from the SDA line.

### `multiple_byte_reads`

Test: [`multiple_byte_reads`](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/block/bus_rx_flow/test_bus_rx_flow.py#L88)

Drives SCL line with a steady clock, issues multiple byte read
requests, verifies that the module returns correct data sampled
from the SDA line.


# bus_timers

[Source file](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/block/ctrl_bus_timers/test_bus_timers.py)

[Test results](./sim-results/bus_timers.html){.external}

## Testpoints

### `get_status`

Test: [`bus_timers`](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/block/ctrl_bus_timers/test_bus_timers.py#L25)

Tests the bus_timers module responsible for tracking bus free,
idle and available states. Triggers the module and verifies if
the signals corresponding to bus states get asserted after the
required time period.


# bus_tx

[Source file](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/block/bus_tx/test_bus_tx.py)

[Test results](./sim-results/bus_tx.html){.external}

## Testpoints

### `bit_tx_negedge`

Test: `bit_tx_negedge`

Requests the bus_tx module to drive SDA right after SCL falling
edge. Checks if the requested bit value is driven correctly

### `bit_tx_pre_posedge`

Test: `bit_tx_pre_posedge`

Requests the bus_tx module to drive SDA just before SCL rising
edge. Checks if the requested bit value is driven correctly

### `bit_tx_high_level`

Test: `bit_tx_high_level`

Requests the bus_tx module to drive SDA just before SCL falling
edge. Checks if the requested bit value is driven correctly

### `bit_tx_low_level`

Test: `bit_tx_low_level`

Requests the bus_tx module to drive SDA when SCL in in stable
low state. Checks if the requested bit value is driven correctly

### `byte_tx`

Test: [`byte_tx`](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/block/bus_tx/test_bus_tx.py#L222)

Drives controls of the bus_tx module in a sequence which sends
a data byte plus T bit to the I3C bus. For each bit sent checks
if SDA is driven correctly and bus timings are met.


# bus_tx_flow

[Source file](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/block/bus_tx_flow/test_bus_tx_flow.py)

[Test results](./sim-results/bus_tx_flow.html){.external}

## Testpoints

### `bit_tx_negedge`

Test: `bit_tx_negedge`

Requests the bus_tx_flow module to drive SDA right after SCL falling
edge. Checks if the requested bit value is driven correctly

### `bit_tx_pre_posedge`

Test: `bit_tx_pre_posedge`

Requests the bus_tx_flow module to drive SDA just before SCL rising
edge. Checks if the requested bit value is driven correctly

### `bit_tx_high_level`

Test: `bit_tx_high_level`

Requests the bus_tx_flow module to drive SDA just before SCL falling
edge. Checks if the requested bit value is driven correctly

### `bit_tx_low_level`

Test: `bit_tx_low_level`

Requests the bus_tx_flow module to drive SDA when SCL in in stable
low state. Checks if the requested bit value is driven correctly

### `byte_tx`

Test: [`byte_tx`](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/block/bus_tx/test_bus_tx.py#L222)

Requests the bus_tx_flow module to transmitt a data byte along with
T-bit. While the transmission is in progress samples SDA on rising
edges of SCL. Once the transmission finishes compares sampled data
with what was requested to be sent.


# ccc

[Source file](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/block/ccc/test_ccc.py)

[Test results](./sim-results/ccc.html){.external}

## Testpoints

### `ccc`

Test: `ccc`

Instucts the ccc module to begin servicing GETSTATUS CCC. Feeds
data bytes and bits to the module via its bus_tx/bus_rx interfaces
to mimick actual I3C transaction. Checks if data bytes received
correspond to correct GETSTATUS CCC response.


# csr_sw_access

[Source file](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/block/lib_adapter/test_csr_sw_access.py)

[Test results](./sim-results/csr_sw_access.html){.external}

## Testpoints

### `read_hci_version_csr`

Test: [`read_hci_version_csr`](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/block/lib_adapter/test_csr_sw_access.py#L67)

Reads the HCI version CSR and verifies its content

### `read_pio_section_offset`

Test: [`read_pio_section_offset`](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/block/lib_adapter/test_csr_sw_access.py#L80)

Reads the PIO_SECTION_OFFSET CSR and verifies its content

### `write_to_controller_device_addr`

Test: [`write_to_controller_device_addr`](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/block/lib_adapter/test_csr_sw_access.py#L90)

Writes to the CONTROLLER_DEVICE_ADDR CSR and verifies if the write was successful

### `write_should_not_affect_ro_csr`

Test: [`write_should_not_affect_ro_csr`](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/block/lib_adapter/test_csr_sw_access.py#L104)

Writes to the HC_CAPABILITIES CSR which is read-only for software
Verifies that the write did not succeed.

### `sequence_csr_read`

Test: [`sequence_csr_read`](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/block/lib_adapter/test_csr_sw_access.py#L120)

Performs a sequence of CSR reads. Verifies that each one succeeds

### `sequence_csr_write`

Test: [`sequence_csr_write`](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/block/lib_adapter/test_csr_sw_access.py#L154)

Performs a sequence of CSR writes. Verifies that each one succeeds


# descriptor_rx

[Source file](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/block/ctrl_descriptor_rx/test_descriptor_rx.py)

[Test results](./sim-results/descriptor_rx.html){.external}

## Testpoints

### `descriptor_rx`

Test: `descriptor_rx`

Tests the descriptor_rx module responsible for generating TTI RX
descriptors. The test sends N bytes to the module and verifies
that it emits a valid descriptor with data length set to N.


# descriptor_tx

[Source file](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/block/ctrl_descriptor_tx/test_descriptor_tx.py)

[Test results](./sim-results/descriptor_tx.html){.external}

## Testpoints

### `descriptor_tx`

Test: `descriptor_tx`

Tests the descriptor_tx module responsible for processing TTI TX
descriptors and controlling TTI data flow during I3C private
reads. Sends a descriptor to the module followed with the right
amount of data. Verifies that the module accepted the descriptor
and allowed the right amount of data bytes to pass through it.


# drivers

[Source file](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/block/i3c_phy_io/test_drivers.py)

[Test results](./sim-results/drivers.html){.external}

## Testpoints

### `test_drivers`

Test: [`drivers`](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/block/i3c_phy_io/test_drivers.py#L44)

Tests the I3C PHY module. Loops through all possible states of
SDA/SCL for OD and PP mode. Checks if driven data matches the
bus state.


# edge_detector

[Source file](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/block/ctrl_edge_detector/test_edge_detector.py)

[Test results](./sim-results/edge_detector.html){.external}

## Testpoints

### `pretrigger_with_delay`

Test: [`pretrigger_with_delay`](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/block/ctrl_edge_detector/test_edge_detector.py#L49)

Triggers the edge_detector module before an edge on a bus line,
emits the edge and counts clock cycles it takes the detector
to report the presence of the edge. Verifies that the count is
equal to the programmed delay.

### `posttrigger_with_delay`

Test: [`posttrigger_with_delay`](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/block/ctrl_edge_detector/test_edge_detector.py#L72)

Emits an edge on the bus, triggers the edge_detector module after
the edge when the bus line is high. Counts clock cycles it takes
the detector to report the edge event. The output detect signal
is asserted only if the bus line signal is stable for the
programmed delay time since the assertion of the trigger signal.
Verifies that the number of counted cycles is equal the programmed
delay.

### `trigger_with_delay`

Test: [`trigger_with_delay`](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/block/ctrl_edge_detector/test_edge_detector.py#L97)

Triggers the edge detector and emits a rising edge on a bus line
simultaneously. Counts clock cycles it takes the detector
to report the presence of the edge. Verifies that the count is
equal to the programmed delay.

### `pretrigger_no_delay`

Test: [`pretrigger_no_delay`](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/block/ctrl_edge_detector/test_edge_detector.py#L121)

Triggers the edge_detector module before an edge on a bus line,
emits the edge and counts clock cycles it takes the detector
to report the presence of the edge. Verifies that the count is
zero as the configured delay is also set to 0.

### `posttrigger_no_delay`

Test: [`posttrigger_no_delay`](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/block/ctrl_edge_detector/test_edge_detector.py#L144)

Triggers the edge_detector module when a bus line is high which
is after an edge. Counts clock cycles it takes the detector
to report the presence of the edge. Verifies that the count is
zero as the configured delay is also set to 0.

### `trigger_no_delay`

Test: [`trigger_no_delay`](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/block/ctrl_edge_detector/test_edge_detector.py#L170)

Triggers the edge detector and emits a rising edge on a bus line
simultaneously. Counts clock cycles it takes the detector
to report the presence of the edge. Verifies that the count is
zero as the configured delay is also set to 0.


# flow_standby_i3c

[Source file](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/block/flow_standby_i3c/test_flow_standby_i3c.py)

[Test results](./sim-results/flow_standby_i3c.html){.external}

## Testpoints

### `rx`

Test: `rx`

Tests basic operation of the flow_standby_i3c module. The test
instantiates two tasks serving as BFMs for RX and TX queues.
Then it simulates bus start condition followed by data reception
ended by bus stop condition.


# hci_queues

[Source file](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/block/lib_hci_queues/hci_queues.py)

[Test results](./sim-results/hci_queues.html){.external}

## Testpoints

### `clear_on_nonempty_resp_queue`

Test: [`clear_on_nonempty_resp_queue`](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/block/lib_hci_queues/test_clear.py#L13)

Writes to the HCI queue RESET_CONTROL CSR bit which causes HCI
command response queue to be cleared. Then, polls the CSR until the
bit gets cleared by the hardware. To check if the queue has been
cleared puts a descriptor to the queue and reads it back. It
should be the same descriptor.

### `clear_on_nonempty_cmd_queue`

Test: [`clear_on_nonempty_cmd_queue`](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/block/lib_hci_queues/test_clear.py#L41)

Puts a command descriptor to the HCI command queue. Writes to the
RESET_CONTROL CSR to the bit responsible for clearing the queue,
polls the CSR until the bit gets cleared by hardware. Verifies that
the queue got cleared by pushing and retrieving another descriptor
from the queue.

### `clear_on_nonempty_rx_queue`

Test: [`clear_on_nonempty_rx_queue`](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/block/lib_hci_queues/test_clear.py#L68)

Puts 10 data words to the HCI RX data queue. Writes to the
RESET_CONTROL CSR to the bit responsible for clearing the queue,
polls the CSR until the bit gets cleared by hardware. Puts and
gets another data word from the queue to check if it was cleared

### `clear_on_nonempty_tx_queue`

Test: [`clear_on_nonempty_tx_queue`](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/block/lib_hci_queues/test_clear.py#L93)

Puts 10 data words to the HCI TX data queue. Writes to the
RESET_CONTROL CSR to the bit responsible for clearing the queue,
polls the CSR until the bit gets cleared by hardware. Puts and
gets another data word from the queue to check if it was cleared

### `clear_on_nonempty_ibi_queue`

Test: [`clear_on_nonempty_ibi_queue`](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/block/lib_hci_queues/test_clear.py#L118)

Puts 10 data words to the HCI IBI queue. Writes to the
RESET_CONTROL CSR to the bit responsible for clearing the queue,
polls the CSR until the bit gets cleared by hardware. Puts and
gets another data word from the queue to check if it was cleared

### `cmd_capacity_status`

Test: [`cmd_capacity_status`](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/block/lib_hci_queues/test_empty.py#L22)

Resets the HCI command queue and verifies that it is empty
afterwards

### `resp_capacity_status`

Test: [`resp_capacity_status`](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/block/lib_hci_queues/test_empty.py#L32)

Resets the HCI response queue and verifies that it is empty
afterwards

### `rx_capacity_status`

Test: [`rx_capacity_status`](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/block/lib_hci_queues/test_empty.py#L27)

Resets the HCI RX queue and verifies that it is empty
afterwards

### `tx_capacity_status`

Test: [`tx_capacity_status`](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/block/lib_hci_queues/test_empty.py#L37)

Resets the HCI TX queue and verifies that it is empty
afterwards

### `ibi_capacity_status`

Test: [`ibi_capacity_status`](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/block/lib_hci_queues/test_empty.py#L42)

Resets the HCI IBI queue and verifies that it is empty
afterwards

### `cmd_setup_threshold`

Test: [`cmd_setup_threshold`](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/block/lib_hci_queues/test_threshold.py#L419)

Writes the threshold to appropriate register for the HCI command
queue (QUEUE_THLD_CTRL or DATA_BUFFER_THLD_CTRL).
Verifies that an appropriate value has been written to the CSR.
Verifies the threshold signal assumes the correct value.

### `resp_setup_threshold`

Test: [`resp_setup_threshold`](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/block/lib_hci_queues/test_threshold.py#L439)

Writes the threshold to appropriate register for the HCI response
queue (QUEUE_THLD_CTRL or DATA_BUFFER_THLD_CTRL).
Verifies that an appropriate value has been written to the CSR.
Verifies the threshold signal assumes the correct value.

### `rx_setup_threshold`

Test: [`rx_setup_threshold`](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/block/lib_hci_queues/test_threshold.py#L425)

Writes the threshold to appropriate register for the HCI data RX
queue (QUEUE_THLD_CTRL or DATA_BUFFER_THLD_CTRL).
Verifies that an appropriate value has been written to the CSR.
Verifies the threshold signal assumes the correct value.

### `tx_setup_threshold`

Test: [`tx_setup_threshold`](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/block/lib_hci_queues/test_threshold.py#L432)

Writes the threshold to appropriate register for the HCI data TX
queue (QUEUE_THLD_CTRL or DATA_BUFFER_THLD_CTRL).
Verifies that an appropriate value has been written to the CSR.
Verifies the threshold signal assumes the correct value.

### `ibi_setup_threshold`

Test: [`ibi_setup_threshold`](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/block/lib_hci_queues/test_threshold.py#L445)

Writes the threshold to appropriate register for the HCI IBI
queue (QUEUE_THLD_CTRL or DATA_BUFFER_THLD_CTRL).
Verifies that an appropriate value has been written to the CSR.
Verifies the threshold signal assumes the correct value.

### `resp_should_raise_thld_trig`

Test: [`resp_should_raise_thld_trig`](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/block/lib_hci_queues/test_threshold.py#L598)

Sets up a ready threshold of the read queue and checks whether the
trigger signal is properly asserted at different levels of the
queue fill.

### `rx_should_raise_thld_trig`

Test: [`rx_should_raise_thld_trig`](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/block/lib_hci_queues/test_threshold.py#L604)

Sets up a ready and start thresholds of the read queue and checks
whether the trigger signals are properly asserted at different
levels of the queue fill.

### `ibi_should_raise_thld_trig`

Test: [`ibi_should_raise_thld_trig`](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/block/lib_hci_queues/test_threshold.py#L611)

Sets up a ready threshold of the read queue and checks whether the
trigger signal is properly asserted at different levels of the
queue fill.

### `cmd_should_raise_thld_trig`

Test: [`cmd_should_raise_thld_trig`](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/block/lib_hci_queues/test_threshold.py#L747)

Sets up a ready threshold of the write queue and checks whether
the trigger is properly asserted at different levels of the queue
fill.

### `tx_should_raise_thld_trig`

Test: [`tx_should_raise_thld_trig`](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/block/lib_hci_queues/test_threshold.py#L753)

Sets up a ready and start threshold of the write queue and checks
whether the trigger is properly asserted at different levels of
the queue fill.


# i3c_bus_monitor

[Source file](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/block/ctrl_i3c_bus_monitor/test_i3c_bus_monitor.py)

[Test results](./sim-results/i3c_bus_monitor.html){.external}

## Testpoints

### `bus_monitor_hdr_exit`

Test: [`bus_monitor_hdr_exit`](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/block/ctrl_i3c_bus_monitor/test_i3c_bus_monitor.py#L49)

Verifies that the i3c_bus_monitor module correctly detects HDR
exit pattern. Sends the HDR exit pattern and verifies that the
module does not react - initially the bus is in SDR mode. Instructs
the module that the bus has entered HDR mode, issues the HDR exit
pattern and counts the number of times the module reported HDR
exit. Checks if it reported exactly one HDR exit event.

### `target_reset_detection`

Test: [`target_reset_detection`](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/block/ctrl_i3c_bus_monitor/test_i3c_bus_monitor.py#L95)

Issues a target reset patterin to the I3C bus, verifies that the
i3c_bus_monitor correctly report it detected.


# pec

[Source file](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/block/recovery_pec/test_pec.py)

[Test results](./sim-results/pec.html){.external}

## Testpoints

### `pec`

Test: [`pec`](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/block/recovery_pec/test_pec.py#L13)

Pushes random bytes through the recovery_pec module, compares
its computed checksum with its correspondent computed in software.


# tti_queues

[Source file](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/block/lib_hci_queues/tti_queues.py)

[Test results](./sim-results/tti_queues.html){.external}

## Testpoints

### `tti_tx_capacity_status`

Test: [`tti_tx_capacity_status`](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/block/lib_hci_queues/test_empty.py#L62)

Resets the TTI TX queue and verifies that it is empty
afterwards

### `tti_tx_desc_capacity_status`

Test: [`tti_tx_desc_capacity_status`](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/block/lib_hci_queues/test_empty.py#L47)

Resets the TTI TX descriptor queue and verifies that it is empty
afterwards

### `tti_rx_capacity_status`

Test: [`tti_rx_capacity_status`](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/block/lib_hci_queues/test_empty.py#L52)

Resets the TTI RX queue and verifies that it is empty
afterwards

### `tti_rx_desc_capacity_status`

Test: [`tti_rx_desc_capacity_status`](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/block/lib_hci_queues/test_empty.py#L57)

Resets the TTI RX descriptor queue and verifies that it is empty
afterwards

### `tti_tx_setup_threshold`

Test: [`tti_tx_setup_threshold`](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/block/lib_hci_queues/test_threshold.py#L465)

Writes the threshold to appropriate register for the TTI data TX
queue (QUEUE_THLD_CTRL or DATA_BUFFER_THLD_CTRL).
Verifies that an appropriate value has been written to the CSR.
Verifies the threshold signal assumes the correct value.

### `tti_tx_desc_setup_threshold`

Test: [`tti_tx_desc_setup_threshold`](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/block/lib_hci_queues/test_threshold.py#L451)

Writes the threshold to appropriate register for the TTI descriptor TX
queue (QUEUE_THLD_CTRL or DATA_BUFFER_THLD_CTRL).
Verifies that an appropriate value has been written to the CSR.
Verifies the threshold signal assumes the correct value.

### `tti_rx_setup_threshold`

Test: [`tti_rx_setup_threshold`](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/block/lib_hci_queues/test_threshold.py#L457)

Writes the threshold to appropriate register for the TTI data RX
queue (QUEUE_THLD_CTRL or DATA_BUFFER_THLD_CTRL).
Verifies that an appropriate value has been written to the CSR.
Verifies the threshold signal assumes the correct value.

### `tti_rx_desc_setup_threshold`

Test: [`tti_rx_desc_setup_threshold`](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/block/lib_hci_queues/test_threshold.py#L473)

Writes the threshold to appropriate register for the TTI descriptor RX
queue (QUEUE_THLD_CTRL or DATA_BUFFER_THLD_CTRL).
Verifies that an appropriate value has been written to the CSR.
Verifies the threshold signal assumes the correct value.

### `tti_ibi_setup_threshold`

Test: [`tti_ibi_setup_threshold`](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/block/lib_hci_queues/test_threshold.py#L479)

Writes the threshold to appropriate register for the TTI IBI
queue (QUEUE_THLD_CTRL or DATA_BUFFER_THLD_CTRL).
Verifies that an appropriate value has been written to the CSR.
Verifies the threshold signal assumes the correct value.

### `tti_ibi_should_raise_thld_trig`

Test: [`tti_ibi_should_raise_thld_trig`](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/block/lib_hci_queues/test_threshold.py#L778)

Sets up a ready threshold of the TTI queue and checks whether the
trigger signal is properly asserted at different levels of the
queue fill.

### `tti_rx_desc_should_raise_thld_trig`

Test: [`tti_rx_desc_should_raise_thld_trig`](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/block/lib_hci_queues/test_threshold.py#L617)

Sets up a ready threshold of the read queue and checks whether the
trigger signal is properly asserted at different levels of the
queue fill.

### `rx_should_raise_thld_trig`

Test: [`rx_should_raise_thld_trig`](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/block/lib_hci_queues/test_threshold.py#L604)

Sets up a ready and start thresholds of the read queue and checks
whether the trigger signals are properly asserted at different
levels of the queue fill.

### `tx_desc_should_raise_thld_trig`

Test: [`tti_tx_desc_should_raise_thld_trig`](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/block/lib_hci_queues/test_threshold.py#L760)

Sets up a ready and start threshold of the write queue and checks
whether the trigger is properly asserted at different levels of
the queue fill.

### `tx_should_raise_thld_trig`

Test: [`tx_should_raise_thld_trig`](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/block/lib_hci_queues/test_threshold.py#L753)

Sets up a ready and start threshold of the write queue and checks
whether the trigger is properly asserted at different levels of
the queue fill.

### `ibi_should_raise_thld_trig`

Test: [`ibi_should_raise_thld_trig`](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/block/lib_hci_queues/test_threshold.py#L611)

Sets up a ready and start threshold of the write queue and checks
whether the trigger is properly asserted at different levels of
the queue fill.

### `tti_ibi_capacity_status`

Test: [`tti_ibi_capacity_status`](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/block/lib_hci_queues/test_empty.py#L67)

Resets the TTI TX IBI queue and verifies that it is empty
afterwards


# width_converter_8toN

[Source file](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/block/width_converter_8toN/test_converter.py)

[Test results](./sim-results/width_converter_8toN.html){.external}

## Testpoints

### `converter`

Test: [`width_converter_8ton_converter`](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/block/width_converter_8toN/test_converter.py#L56)

Pushes random byte stream to the converter module. After each
byte waits at random. Simultaneously receives N-bit data words
and generates pushback (deasserts ready) at random. Verifies if
the output data matches the input.

### `flush`

Test: [`width_converter_8ton_flush`](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/block/width_converter_8toN/test_flush.py#L59)

Feeds M bytes to the module where M is in [1, 2, 3]. Asserts the
sink_flush_i signal, receives the output word and checks if it
matches the input data.


# width_converter_Nto8

[Source file](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/block/width_converter_Nto8/test_converter.py)

[Test results](./sim-results/width_converter_Nto8.html){.external}

## Testpoints

### `converter`

Test: [`width_converter_nto8_converter`](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/block/width_converter_Nto8/test_converter.py#L56)

Pushes random N-bit word stream to the converter module. After each
word waits at random. Simultaneously receives bytes and generates
pushback (deasserts ready) at random. Verifies if the output data
matches the input.

### `flush`

Test: [`width_converter_nto8_flush`](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/block/width_converter_Nto8/test_flush.py#L53)

Feeds an N-bit word to the module. Receives M bytes where M is in
[1, 2, 3] and asserts source_flush_i. Verifies that the module
ceases to output data as expected.



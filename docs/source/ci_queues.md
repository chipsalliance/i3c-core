# Controller Interface Queues

Controller Interface queues consist of:
* Command queue
  * The commands are fetched by the `hci` module from the `COMMAND_PORT`.
* TX data queue
  * Data is fetched by the `hci` module from the `XFER_DATA_PORT`.
* RX data queue
  * Data is put to the `XFER_DATA_PORT` by the `hci` module.
* Response queue
  * Responses are retrieved from `i3c_ctrl` and put to the `XFER_DATA_PORT` by the `hci` module.

Controller Interface queues are depth-configurable with the [I3C Configuration](config.md#configuring-the-i3c-core).

Queues generate several status indicators that will be used to trigger appropriate interrupts:
  * `*_fifo_empty_` - no elements are enqueued in the corresponding FIFO.
  * `*_fifo_full_` - `*_FIFO_DEPTH` are enqueued in the corresponding FIFO.
  * `*_fifo_apch_thld_` - the user-defined threshold has been reached. <!-- TODO: name will be changed -->

## Queue threshold
Command and response queue thresholds are controlled via the [QUEUE_THLD_CTRL](https://github.com/chipsalliance/i3c-core-rdl/blob/4028ed29254aefdbe9c805e8bfaa275e200994ba/src/rdl/pio_registers.rdl#L44) register.
RX and TX data queue thresholds are controlled via [DATA_BUFFER_THLD_CTRL](https://github.com/chipsalliance/i3c-core-rdl/blob/4028ed29254aefdbe9c805e8bfaa275e200994ba/src/rdl/pio_registers.rdl#L75).

### Command queue threshold
* The threshold for command queue is set by a write to the 8-bit `CMD_EMPTY_BUF_THLD` field of the `QUEUE_THLD_CTRL` register.
* The `N` threshold of `<1, 255>` range (inclusive) will cause an `CMD_QUEUE_READY_STAT` interrupt when there's `N` or more remaining empty entries in the command queue.
* If the `N` value is greater than the size of the command queue (`CMD_FIFO_DEPTH`), the full depth will be considered (the threshold will be set to `CMD_FIFO_DEPTH`).

### Response queue threshold
* The threshold for response queue is set by a write to the 8-bit `RESP_BUF_THLD` field of the `QUEUE_THLD_CTRL` register.
* The `N` threshold of `<1, 255>` range (inclusive) will cause an `RESP_READY_STAT` interrupt when there's `N` or more responses enqueued in the response queue.
* If the `N` value is greater or equal than the size of the response queue (`RESP_FIFO_DEPTH`), the full depth will be considered (the threshold will be set to `RESP_FIFO_DEPTH - 1`)

### TX queue threshold
* The threshold for the TX queue is set by a write to the 3-bit `TX_BUF_THLD` field of the `DATA_BUFFER_THLD_CTRL` register.
* The `N` threshold of `<0, 7>` range (inclusive) will trigger an `TX_THLD_STAT` interrupt when `2^(N+1)` (`2` to the power of `N+1`) empty `DWORD` entries are available in the TX queue.
* The software must provide an `N` value that corresponds to the threshold less or equal than `TX_FIFO_DEPTH`, otherwise `clog2(TX_FIFO_DEPTH) - 1` will be applied.

### RX queue threshold
* The threshold for the RX queue is set by a write to the 3-bit `RX_BUF_THLD` field of the `DATA_BUFFER_THLD_CTRL` register.
* The `N` threshold of `<0, 7>` range (inclusive) will trigger an `RX_THLD_STAT` interrupt when `2^(N+1)` (`2` to the power of `N+1`) `DWORD` entries are enqueued in the RX queue.
* The software must provide an `N` value that corresponds to the threshold less than `RX_FIFO_DEPTH`, otherwise `clog2(RX_FIFO_DEPTH) - 2` will be applied.

All queues utilize the [caliptra_prim_fifo_sync.sv](https://github.com/chipsalliance/caliptra-rtl/blob/9c815c335a92901b27458271a885b2128e51e687/src/caliptra_prim/rtl/caliptra_prim_fifo_sync.sv#L9) FIFO implementation.
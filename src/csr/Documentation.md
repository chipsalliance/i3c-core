<!---
Markdown description for SystemRDL register map.

Don't override. Generated from: I3CCSR
  - src/rdl/registers.rdl
-->

## I3CCSR address map

- Absolute Address: 0x0
- Base Offset: 0x0
- Size: 0x1000

|Offset|Identifier|Name|
|------|----------|----|
| 0x000|  I3CBase |  — |
| 0x100|PIOControl|  — |
| 0x400|    DAT   |  — |
| 0x800|    DCT   |  — |

## I3CBase register file

- Absolute Address: 0x0
- Base Offset: 0x0
- Size: 0x6C

|Offset|         Identifier        |                    Name                    |
|------|---------------------------|--------------------------------------------|
| 0x00 |        HCI_VERSION        |                 HCI Version                |
| 0x04 |         HC_CONTROL        |                   Control                  |
| 0x08 |   CONTROLLER_DEVICE_ADDR  |               Dynamic address              |
| 0x0C |      HC_CAPABILITIES      |                Capabilities                |
| 0x10 |       RESET_CONTROL       |               Reset controls               |
| 0x14 |       PRESENT_STATE       |              Active controller             |
| 0x20 |        INTR_STATUS        |                   Status                   |
| 0x24 |     INTR_STATUS_ENABLE    |           Enable status reporting          |
| 0x28 |     INTR_SIGNAL_ENABLE    |          Enable status interrupts          |
| 0x2C |         INTR_FORCE        |         Force status and interrupt         |
| 0x30 |     DAT_SECTION_OFFSET    |             DAT section offset             |
| 0x34 |     DCT_SECTION_OFFSET    |             DCT section offset             |
| 0x38 |RING_HEADERS_SECTION_OFFSET|             Ring section offset            |
| 0x3C |     PIO_SECTION_OFFSET    |             PIO section offset             |
| 0x40 |  EXT_CAPS_SECTION_OFFSET  |    Extended capabilities section offset    |
| 0x4C |      INT_CTRL_CMDS_EN     |                MIPI commands               |
| 0x58 |      IBI_NOTIFY_CTRL      |         I3C interrupts notification        |
| 0x5C |    IBI_DATA_ABORT_CTRL    |              IBI data control              |
| 0x60 |      DEV_CTX_BASE_LO      | Device context memory address lower 32 bits|
| 0x64 |      DEV_CTX_BASE_HI      |Device context memory address higher 32 bits|
| 0x68 |         DEV_CTX_SG        |                 SG control                 |

### HCI_VERSION register

- Absolute Address: 0x0
- Base Offset: 0x0
- Size: 0x4

|Bits|Identifier|Access|Reset|Name|
|----|----------|------|-----|----|
|31:0|   value  |   r  |0x120|  — |

### HC_CONTROL register

- Absolute Address: 0x4
- Base Offset: 0x4
- Size: 0x4

|Bits|       Identifier      |  Access |Reset|          Name         |
|----|-----------------------|---------|-----|-----------------------|
|  0 |      iba_include      |    rw   | 0x0 |      IBA_INCLUDE      |
|  3 |    autocmd_data_rpt   |    r    | 0x0 |    AUTOCMD_DATA_RPT   |
|  4 |       byte_order      |    r    | 0x0 |  DATA_BYTE_ORDER_MODE |
|  6 |          mode         |    r    | 0x1 |     MODE_SELECTOR     |
|  7 |        i2c_devs       |    rw   | 0x0 |    I2C_DEV_PRESENT    |
|  8 |        hot_join       |    rw   | 0x0 |     HOT_JOIN_CTRL     |
| 12 |halt_on_cmd_seq_timeout|    rw   | 0x0 |HALT_ON_CMD_SEQ_TIMEOUT|
| 29 |         abort         |    rw   | 0x0 |         ABORT         |
| 30 |         resume        |rw, woclr| 0x0 |         RESUME        |
| 31 |       bus_enable      |    rw   | 0x0 |       BUS_ENABLE      |

#### iba_include field

<p>Include I3C Broadcast Address:
0 - skips I3C Broadcast Address for private transfers,
1 - includes I3C Broadcast Address for private transfers.</p>

#### autocmd_data_rpt field

<p>Auto-Command Data Report:
0 - coalesced reporting,
1 - separated reporting.</p>

#### byte_order field

<p>Data Byte Ordering Mode:
0 - Little Endian
1 - Big Endian</p>

#### mode field

<p>DMA/PIO Mode Selector:
0 - DMA,
1 - PIO.</p>

#### i2c_devs field

<p>I2C Device Present on Bus:
0 - pure I3C bus,
1 - legacy I2C devices on the bus.</p>

#### hot_join field

<p>Hot-Join ACK/NACK Control:
0 - ACK Hot-Join request,
1 - NACK Hot-Join request and send Broadcast CCC to disable Hot-Join.</p>

#### halt_on_cmd_seq_timeout field

<p>Halt on Command Sequence Timeout when set to 1</p>

#### abort field

<p>Host Controller Abort when set to 1</p>

#### resume field

<p>Host Controller Resume:
0 - Controller is running,
1 - Controller is suspended.
Write 1 to resume Controller operations.</p>

#### bus_enable field

<p>Host Controller Bus Enable</p>

### CONTROLLER_DEVICE_ADDR register

- Absolute Address: 0x8
- Base Offset: 0x8
- Size: 0x4

| Bits|    Identifier    |Access|Reset|       Name       |
|-----|------------------|------|-----|------------------|
|22:16|   dynamic_addr   |  rw  | 0x0 |   DYNAMIC_ADDR   |
|  31 |dynamic_addr_valid|  rw  | 0x0 |DYNAMIC_ADDR_VALID|

#### dynamic_addr field

<p>Device Dynamic Address</p>

#### dynamic_addr_valid field

<p>Dynamic Address is Valid:
0 - dynamic address is invalid,
1 - dynamic address is valid</p>

### HC_CAPABILITIES register

- Absolute Address: 0xC
- Base Offset: 0xC
- Size: 0x4

| Bits|    Identifier    |Access|Reset|         Name        |
|-----|------------------|------|-----|---------------------|
|  2  |     comb_cmd     |   r  | 0x0 |    COMBO_COMMAND    |
|  3  |     auto_cmd     |   r  | 0x0 |     AUTO_COMMAND    |
|  5  |    standby_cr    |   r  | 0x0 |    STANDBY_CR_CAP   |
|  6  |      hdr_ddr     |   r  | 0x0 |      HDR_DDR_EN     |
|  7  |      hdr_ts      |   r  | 0x0 |      HDR_TS_EN      |
|  10 |  cmd_ccc_defbyte |   r  | 0x1 |   CMD_CCC_DEFBYTE   |
|  11 |  ibi_data_abort  |   r  | 0x0 |  IBI_DATA_ABORT_EN  |
|  12 | ibi_credit_count |   r  | 0x0 | IBI_CREDIT_COUNT_EN |
|  13 |scheduled_commands|   r  | 0x0 |SCHEDULED_COMMANDS_EN|
|21:20|     cmd_size     |   r  | 0x0 |       CMD_SIZE      |
|  28 |     sc_cr_en     |   r  | 0x0 | SG_CAPABILITY_CR_EN |
|  29 |     sc_ibi_en    |   r  | 0x0 | SG_CAPABILITY_IBI_EN|
|  30 |     sg_dc_en     |   r  | 0x0 | SG_CAPABILITY_DC_EN |

#### comb_cmd field

<p>Controller combined command:
0 - not supported,
1 - supported.</p>

#### auto_cmd field

<p>Automatic read command on IBI:
0 - not supported,
1 - supported.</p>

#### standby_cr field

<p>Switching from active to standby mode:
0 - not supported, this controller is always active on I3C,
1- supported, this controller can hand off I3C to secondary controller.</p>

#### hdr_ddr field

<p>HDR-DDR transfers:
0 - not supported,
1 - supported.</p>

#### hdr_ts field

<p>HDR-Ternary transfers:
0 - not supported,
1 - supported.</p>

#### cmd_ccc_defbyte field

<p>CCC with defining byte:
0 - not supported,
1 - supported.</p>

#### ibi_data_abort field

<p>Controller IBI data abort:
0 - not supported,
1 - supported.</p>

#### ibi_credit_count field

<p>Controller IBI credit count:
0 - not supported,
1 - supported.</p>

#### scheduled_commands field

<p>Controller command scheduling:
0 - not supported,
1 - supported.</p>

#### cmd_size field

<p>Size and structure of the Command Descriptor:
2'b0: 2 DWORDs,
all other reserved.</p>

#### sc_cr_en field

<p>DMA only: Command and Response rings memory:
0 - must be physically continuous,
1 - controller supports scatter-gather.</p>

#### sc_ibi_en field

<p>DMA only: IBI status and IBI Data rings memory:
0 - must be physically continuous,
1 - controller supports scatter-gather.</p>

#### sg_dc_en field

<p>Device context memory:
0 - must be physically continuous,
1 - controller supports scatter-gather.</p>

### RESET_CONTROL register

- Absolute Address: 0x10
- Base Offset: 0x10
- Size: 0x4

|Bits|Identifier|Access|Reset|     Name     |
|----|----------|------|-----|--------------|
|  0 | soft_rst |  rw  | 0x0 |   SOFT_RST   |
|  1 | cmd_queue|  rw  | 0x0 | CMD_QUEUE_RST|
|  2 |resp_queue|  rw  | 0x0 |RESP_QUEUE_RST|
|  3 |  tx_fifo |  rw  | 0x0 |  TX_FIFO_RST |
|  4 |  rx_fifo |  rw  | 0x0 |  RX_FIFO_RST |
|  5 | ibi_queue|  rw  | 0x0 | IBI_QUEUE_RST|

#### soft_rst field

<p>Reset controller from software.</p>

#### cmd_queue field

<p>Clear command queue from software. Valid only in PIO mode.</p>

#### resp_queue field

<p>Clear response queue from software. Valid only in PIO mode.</p>

#### tx_fifo field

<p>Clear TX FIFO from software. Valid only in PIO mode.</p>

#### rx_fifo field

<p>Clear RX FIFO from software. Valid only in PIO mode.</p>

#### ibi_queue field

<p>Clear IBI queue from software. Valid only in PIO mode.</p>

### PRESENT_STATE register

- Absolute Address: 0x14
- Base Offset: 0x14
- Size: 0x4

|Bits|  Identifier  |Access|Reset|     Name     |
|----|--------------|------|-----|--------------|
|  2 |ac_current_own|   r  | 0x1 |AC_CURRENT_OWN|

#### ac_current_own field

<p>Controller I3C state:
0 - not bus owner,
1 - bus owner.</p>

### INTR_STATUS register

- Absolute Address: 0x20
- Base Offset: 0x20
- Size: 0x4

|Bits|      Identifier      |  Access |Reset|            Name           |
|----|----------------------|---------|-----|---------------------------|
| 10 |    hc_internal_err   |rw, woclr| 0x0 |    HC_INTERNAL_ERR_STAT   |
| 11 |  hc_seq_cancel_stat  |rw, woclr| 0x0 |     HC_SEQ_CANCEL_STAT    |
| 12 | hc_warn_cmd_seq_stall|rw, woclr| 0x0 | HC_WARN_CMD_SEQ_STALL_STAT|
| 13 |hc_err_cmd_seq_timeout|rw, woclr| 0x0 |HC_ERR_CMD_SEQ_TIMEOUT_STAT|
| 14 | sched_cmd_missed_tick|rw, woclr| 0x0 | SCHED_CMD_MISSED_TICK_STAT|

#### hc_internal_err field

<p>Controller internal unrecoverable error.</p>

#### hc_seq_cancel_stat field

<p>Controller had to cancel command sequence.</p>

#### hc_warn_cmd_seq_stall field

<p>Clock stalled due to lack of commands.</p>

#### hc_err_cmd_seq_timeout field

<p>Command timeout after prolonged stall.</p>

#### sched_cmd_missed_tick field

<p>Scheduled commands could be executed due to controller being busy.</p>

### INTR_STATUS_ENABLE register

- Absolute Address: 0x24
- Base Offset: 0x24
- Size: 0x4

|Bits|        Identifier       |Access|Reset|             Name             |
|----|-------------------------|------|-----|------------------------------|
| 10 |    hc_internal_err_en   |  rw  | 0x0 |    HC_INTERNAL_ERR_STAT_EN   |
| 11 |  hc_seq_cancel_stat_en  |  rw  | 0x0 |     HC_SEQ_CANCEL_STAT_EN    |
| 12 | hc_warn_cmd_seq_stall_en|  rw  | 0x0 | HC_WARN_CMD_SEQ_STALL_STAT_EN|
| 13 |hc_err_cmd_seq_timeout_en|  rw  | 0x0 |HC_ERR_CMD_SEQ_TIMEOUT_STAT_EN|
| 14 | sched_cmd_missed_tick_en|  rw  | 0x0 | SCHED_CMD_MISSED_TICK_STAT_EN|

#### hc_internal_err_en field

<p>Enable HC_INTERNAL_ERR_STAT monitoring.</p>

#### hc_seq_cancel_stat_en field

<p>Enable HC_SEQ_CANCEL_STAT monitoring.</p>

#### hc_warn_cmd_seq_stall_en field

<p>Enable HC_WARN_CMD_SEQ_STALL_STAT monitoring.</p>

#### hc_err_cmd_seq_timeout_en field

<p>Enable HC_ERR_CMD_SEQ_TIMEOUT_STAT monitoring.</p>

#### sched_cmd_missed_tick_en field

<p>Enable SCHED_CMD_MISSED_TICK_STAT monitoring.</p>

### INTR_SIGNAL_ENABLE register

- Absolute Address: 0x28
- Base Offset: 0x28
- Size: 0x4

|Bits|          Identifier          |Access|Reset|              Name              |
|----|------------------------------|------|-----|--------------------------------|
| 10 |    hc_internal_err_intr_en   |  rw  | 0x0 |    HC_INTERNAL_ERR_SIGNAL_EN   |
| 11 |  hc_seq_cancel_stat_intr_en  |  rw  | 0x0 |     HC_SEQ_CANCEL_SIGNAL_EN    |
| 12 | hc_warn_cmd_seq_stall_intr_en|  rw  | 0x0 | HC_WARN_CMD_SEQ_STALL_SIGNAL_EN|
| 13 |hc_err_cmd_seq_timeout_intr_en|  rw  | 0x0 |HC_ERR_CMD_SEQ_TIMEOUT_SIGNAL_EN|
| 14 | sched_cmd_missed_tick_intr_en|  rw  | 0x0 | SCHED_CMD_MISSED_TICK_SIGNAL_EN|

#### hc_internal_err_intr_en field

<p>Enable HC_INTERNAL_ERR_STAT interrupt.</p>

#### hc_seq_cancel_stat_intr_en field

<p>Enable HC_SEQ_CANCEL_STAT interrupt.</p>

#### hc_warn_cmd_seq_stall_intr_en field

<p>Enable HC_WARN_CMD_SEQ_STALL_STAT interrupt.</p>

#### hc_err_cmd_seq_timeout_intr_en field

<p>Enable HC_ERR_CMD_SEQ_TIMEOUT_STAT interrupt.</p>

#### sched_cmd_missed_tick_intr_en field

<p>Enable SCHED_CMD_MISSED_TICK_STAT interrupt.</p>

### INTR_FORCE register

- Absolute Address: 0x2C
- Base Offset: 0x2C
- Size: 0x4

|Bits|         Identifier         |Access|Reset|            Name            |
|----|----------------------------|------|-----|----------------------------|
| 10 |    force_hc_internal_err   |   w  | 0x0 |    HC_INTERNAL_ERR_FORCE   |
| 11 |  force_hc_seq_cancel_stat  |   w  | 0x0 |     HC_SEQ_CANCEL_FORCE    |
| 12 | force_hc_warn_cmd_seq_stall|   w  | 0x0 | HC_WARN_CMD_SEQ_STALL_FORCE|
| 13 |force_hc_err_cmd_seq_timeout|   w  | 0x0 |HC_ERR_CMD_SEQ_TIMEOUT_FORCE|
| 14 | force_sched_cmd_missed_tick|   w  | 0x0 | SCHED_CMD_MISSED_TICK_FORCE|

#### force_hc_internal_err field

<p>Force HC_INTERNAL_ERR_STAT interrupt.</p>

#### force_hc_seq_cancel_stat field

<p>Force HC_SEQ_CANCEL_STAT interrupt.</p>

#### force_hc_warn_cmd_seq_stall field

<p>Force HC_WARN_CMD_SEQ_STALL_STAT interrupt.</p>

#### force_hc_err_cmd_seq_timeout field

<p>Force HC_ERR_CMD_SEQ_TIMEOUT_STAT interrupt.</p>

#### force_sched_cmd_missed_tick field

<p>Force SCHED_CMD_MISSED_TICK_STAT interrupt.</p>

### DAT_SECTION_OFFSET register

- Absolute Address: 0x30
- Base Offset: 0x30
- Size: 0x4

| Bits| Identifier |Access|Reset|    Name    |
|-----|------------|------|-----|------------|
| 11:0|table_offset|   r  |0x400|TABLE_OFFSET|
|18:12| dat_entires|   r  | 0x7F| TABLE_SIZE |
|31:28| entry_size |   r  | 0x0 | ENTRY_SIZE |

#### table_offset field

<p>DAT entry offset in respect to BASE address.</p>

#### dat_entires field

<p>Max number of DAT entries.</p>

#### entry_size field

<p>Individual DAT entry size.
0 - 2 DWRODs,
1:15 - reserved.</p>

### DCT_SECTION_OFFSET register

- Absolute Address: 0x34
- Base Offset: 0x34
- Size: 0x4

| Bits| Identifier |Access|Reset|    Name    |
|-----|------------|------|-----|------------|
| 11:0|table_offset|   r  |0x800|TABLE_OFFSET|
|18:12|  dct_size  |   r  | 0x7F| TABLE_SIZE |
|23:19|  table_idx |  rw  | 0x0 | TABLE_INDEX|
|31:28| entry_size |   r  | 0x0 | ENTRY_SIZE |

#### table_offset field

<p>DCT entry offset in respect to BASE address.</p>

#### dct_size field

<p>Max number of DCT entries.</p>

#### table_idx field

<p>Index to DCT used during ENTDAA.</p>

#### entry_size field

<p>Individual DCT entry size.
0 - 4 DWORDs,
1:15 - Reserved.</p>

### RING_HEADERS_SECTION_OFFSET register

- Absolute Address: 0x38
- Base Offset: 0x38
- Size: 0x4

|Bits| Identifier|Access|Reset|     Name     |
|----|-----------|------|-----|--------------|
|15:0|ring_offset|   r  | 0x0 |SECTION_OFFSET|

#### ring_offset field

<p>DMA ring headers section offset. Invalid if 0.</p>

### PIO_SECTION_OFFSET register

- Absolute Address: 0x3C
- Base Offset: 0x3C
- Size: 0x4

|Bits|Identifier|Access|Reset|     Name     |
|----|----------|------|-----|--------------|
|15:0|pio_offset|   r  |0x100|SECTION_OFFSET|

#### pio_offset field

<p>PIO section offset. Invalid if 0.</p>

### EXT_CAPS_SECTION_OFFSET register

- Absolute Address: 0x40
- Base Offset: 0x40
- Size: 0x4

|Bits|Identifier|Access|Reset|     Name     |
|----|----------|------|-----|--------------|
|15:0|ext_offset|   r  | 0x0 |SECTION_OFFSET|

#### ext_offset field

<p>Extended Capabilities section offset. Invalid if 0.</p>

### INT_CTRL_CMDS_EN register

- Absolute Address: 0x4C
- Base Offset: 0x4C
- Size: 0x4

|Bits| Identifier |Access|Reset|        Name       |
|----|------------|------|-----|-------------------|
|  0 | ICC_SUPPORT|   r  | 0x1 |    ICC_SUPPORT    |
|15:1|MIPI_SUPPORT|   r  | 0x35|MIPI_CMDS_SUPPORTED|

#### ICC_SUPPORT field

<p>Internal Control Commands:
1 - some or all internals commands sub-commands are supported,
0 - illegal.</p>

#### MIPI_SUPPORT field

<p>Bitmask of supported MIPI commands.</p>

### IBI_NOTIFY_CTRL register

- Absolute Address: 0x58
- Base Offset: 0x58
- Size: 0x4

|Bits| Identifier |Access|Reset|        Name       |
|----|------------|------|-----|-------------------|
|  0 | hj_rejected|  rw  | 0x0 | NOTIFY_HJ_REJECTED|
|  1 |crr_rejected|  rw  | 0x0 |NOTIFY_CRR_REJECTED|
|  3 |ibi_rejected|  rw  | 0x0 |NOTIFY_IBI_REJECTED|

#### hj_rejected field

<p>Notify about rejected hot-join:
0 - do not enqueue rejected HJ,
1 = enqueue rejected HJ on IBI queue/ring.</p>

#### crr_rejected field

<p>Notify about rejected controller role request:
0 - do not enqueue rejected CRR,
1 = enqueue rejected CRR on IBI queue/ring.</p>

#### ibi_rejected field

<p>Notify about rejected IBI:
0 - do not enqueue rejected IBI,
1 = enqueue rejected IBI on IBI queue/ring.</p>

### IBI_DATA_ABORT_CTRL register

- Absolute Address: 0x5C
- Base Offset: 0x5C
- Size: 0x4

| Bits|    Identifier    |Access|Reset|       Name       |
|-----|------------------|------|-----|------------------|
| 15:8|     match_id     |  rw  | 0x0 |   MATCH_IBI_ID   |
|17:16|  max_data_length |  rw  | 0x0 |  AFTER_N_CHUNKS  |
|20:18| ibi_match_statsus|  rw  | 0x0 | MATCH_STATUS_TYPE|
|  31 |data_abort_monitor|  rw  | 0x0 |IBI_DATA_ABORT_MON|

#### match_id field

<p>IBI target address:
[15:9] - device address,
[8] - must always be set to 1'b1</p>

#### max_data_length field

<p>Number of data chunks to be allowed before forced termination:
0 - immediate,
1:3 - delay by 1-3 data chunks.</p>

#### ibi_match_statsus field

<p>Define which IBI should be aborted:
3'b000 - Regular IBI,
3'b100 - Autocmd IBI,
other values - not supported.</p>

#### data_abort_monitor field

<p>Enable/disable IBI monitoring logic.</p>

### DEV_CTX_BASE_LO register

- Absolute Address: 0x60
- Base Offset: 0x60
- Size: 0x4

|Bits|Identifier|Access|Reset|Name|
|----|----------|------|-----|----|
|  0 |  base_lo |  rw  | 0x0 |  — |

### DEV_CTX_BASE_HI register

- Absolute Address: 0x64
- Base Offset: 0x64
- Size: 0x4

|Bits|Identifier|Access|Reset|Name|
|----|----------|------|-----|----|
|  0 |  base_hi |  rw  | 0x0 |  — |

### DEV_CTX_SG register

- Absolute Address: 0x68
- Base Offset: 0x68
- Size: 0x4

|Bits|Identifier|Access|Reset|   Name  |
|----|----------|------|-----|---------|
|15:0| list_size|   r  | 0x0 |LIST_SIZE|
| 31 |    blp   |   r  | 0x0 |   BLP   |

#### list_size field

<p>Number of SG entries.</p>

#### blp field

<p>Buffer vs list pointer in device context:
0 - continuous physical memory region,
1 - pointer to SG descriptor list.</p>

## PIOControl register file

- Absolute Address: 0x100
- Base Offset: 0x100
- Size: 0x34

|Offset|      Identifier      |             Name            |
|------|----------------------|-----------------------------|
| 0x00 |     COMMAND_PORT     |      Command issue port     |
| 0x04 |     RESPONSE_PORT    |    Command response port    |
| 0x08 |    XFER_DATA_PORT    |       Data access port      |
| 0x0C |       IBI_PORT       |  IBI descriptor access port |
| 0x10 |    QUEUE_THLD_CTRL   | IBI queue threshold control |
| 0x14 | DATA_BUFFER_THLD_CTRL|RX/TX queue threshold control|
| 0x18 |      QUEUE_SIZE      |         Queue sizes         |
| 0x1C |    ALT_QUEUE_SIZE    |    Alternate queue sizes    |
| 0x20 |    PIO_INTR_STATUS   |     PIO interrupt status    |
| 0x24 |PIO_INTR_STATUS_ENABLE|              —              |
| 0x28 |PIO_INTR_SIGNAL_ENABLE|   Interrupt Signal Enable   |
| 0x2C |    PIO_INTR_FORCE    |  PIO force interrupt status |
| 0x30 |      PIO_CONTROL     |         PIO control         |

### COMMAND_PORT register

- Absolute Address: 0x100
- Base Offset: 0x0
- Size: 0x4

|Bits|Identifier|Access|Reset|       Name       |
|----|----------|------|-----|------------------|
|  0 |    cmd   |   w  |  —  |COMMAND_QUEUE_PORT|

### RESPONSE_PORT register

- Absolute Address: 0x104
- Base Offset: 0x4
- Size: 0x4

|Bits|Identifier|Access|Reset|        Name       |
|----|----------|------|-----|-------------------|
|  0 |   resp   |   r  |  —  |RESPONSE_QUEUE_PORT|

### XFER_DATA_PORT register

- Absolute Address: 0x108
- Base Offset: 0x8
- Size: 0x4

|Bits|Identifier|Access|Reset|  Name |
|----|----------|------|-----|-------|
|31:0|  tx_data |   w  |  —  |TX_DATA|
|31:0|  rx_data |   r  |  —  |RX_DATA|

### IBI_PORT register

- Absolute Address: 0x10C
- Base Offset: 0xC
- Size: 0x4

|Bits|Identifier|Access|Reset|  Name  |
|----|----------|------|-----|--------|
|  0 | ibi_port |   r  |  —  |IBI_DATA|

### QUEUE_THLD_CTRL register

- Absolute Address: 0x110
- Base Offset: 0x10
- Size: 0x4

| Bits|  Identifier |Access|Reset|         Name        |
|-----|-------------|------|-----|---------------------|
| 7:0 |  cmd_empty  |  rw  | 0x1 |  CMD_EMPTY_BUF_THLD |
| 15:8|   resp_buf  |  rw  | 0x1 |    RESP_BUF_THLD    |
|23:16|ibi_data_size|  rw  | 0x1 |IBI_DATA_SEGMENT_SIZE|
|31:24|  ibi_status |  rw  | 0x1 |   IBI_STATUS_THLD   |

#### cmd_empty field

<p>Triggers CMD_QUEUE_READY_STAT interrupt when CMD queue has N or more free entries. Accepted values are 1:255</p>

#### resp_buf field

<p>Triggers RESP_READY_STAT interrupt when RESP queue has N or more entries. Accepted values are 1:255</p>

#### ibi_data_size field

<p>IBI Queue data segment size. Valida values are 1:63</p>

#### ibi_status field

<p>Triggers IBI_STATUS_THLD_STAT interrupt when IBI queue has N or more entries. Accepted values are 1:255</p>

### DATA_BUFFER_THLD_CTRL register

- Absolute Address: 0x114
- Base Offset: 0x14
- Size: 0x4

| Bits| Identifier |Access|Reset|     Name    |
|-----|------------|------|-----|-------------|
| 2:0 |   tx_bux   |  rw  | 0x1 | TX_BUF_THLD |
| 10:8|   rx_buf   |  rw  | 0x1 | RX_BUF_THLD |
|18:16|tx_start_log|  rw  | 0x1 |TX_START_THLD|
|26:24|rx_start_log|  rw  | 0x1 |RX_START_THLD|

#### tx_bux field

<p>Trigger TX_THLD_STAT interrupt when TX queue has 2^(N+1) or more free entries</p>

#### rx_buf field

<p>Trigger RX_THLD_STAT interrupt when RX queue has 2^(N+1) or more entries</p>

#### tx_start_log field

<p>Postpone write command until TX queue has 2^(N+1) entries</p>

#### rx_start_log field

<p>Postpone read command until RX queue has 2^(N+1) free entries</p>

### QUEUE_SIZE register

- Absolute Address: 0x118
- Base Offset: 0x18
- Size: 0x4

| Bits|  Identifier  |Access|Reset|        Name       |
|-----|--------------|------|-----|-------------------|
| 7:0 | cr_queue_size|   r  | 0xFF|   CR_QUEUE_SIZE   |
| 15:8|ibi_queue_size|   r  | 0xFF|  IBI_STATUS_SIZE  |
|23:16| rx_queue_size|   r  | 0x7 |RX_DATA_BUFFER_SIZE|
|31:24| tx_queue_size|   r  | 0x7 |TX_DATA_BUFFER_SIZE|

#### cr_queue_size field

<p>Command/Response queue size is equal to N</p>

#### ibi_queue_size field

<p>IBI Queue size is equal to N</p>

#### rx_queue_size field

<p>RX queue size is equal to 2^(N+1), where N is this field value</p>

#### tx_queue_size field

<p>TX queue size is equal to 2^(N+1), where N is this field value</p>

### ALT_QUEUE_SIZE register

- Absolute Address: 0x11C
- Base Offset: 0x1C
- Size: 0x4

|Bits|     Identifier    |Access|Reset|        Name       |
|----|-------------------|------|-----|-------------------|
| 7:0|alt_resp_queue_size|   r  | 0x0 |ALT_RESP_QUEUE_SIZE|
| 24 | alt_resp_queue_en |   r  | 0x0 | ALT_RESP_QUEUE_EN |
| 28 | ext_ibi_queue_size|   r  | 0x0 |  EXT_IBI_QUEUE_EN |

#### alt_resp_queue_size field

<p>Response queue size</p>

#### alt_resp_queue_en field

<p>If set, response and command queues are equal lengths.
ALT_RESP_QUEUE_SIZE contains response queue size</p>

#### ext_ibi_queue_size field

<p>1 indicates that IBI queue size is equal to 8*IBI_STATUS_SIZE</p>

### PIO_INTR_STATUS register

- Absolute Address: 0x120
- Base Offset: 0x20
- Size: 0x4

|Bits|   Identifier  |  Access |Reset|        Name        |
|----|---------------|---------|-----|--------------------|
|  0 |  tx_threshold |    r    | 0x0 |    TX_THLD_STAT    |
|  1 |  rx_threshold |    r    | 0x0 |    RX_THLD_STAT    |
|  2 |   ibi_status  |    r    | 0x0 |IBI_STATUS_THLD_STAT|
|  3 |cmd_queue_ready|    r    | 0x0 |CMD_QUEUE_READY_STAT|
|  4 |   resp_ready  |    r    | 0x0 |   RESP_READY_STAT  |
|  5 | transfer_abort|rw, woclr| 0x0 | TRANSFER_ABORT_STAT|
|  9 |  transfer_err |rw, woclr| 0x0 |  TRANSFER_ERR_STAT |

#### tx_threshold field

<p>TX queue fulfils TX_BUF_THLD</p>

#### rx_threshold field

<p>RX queue fulfils RX_BUF_THLD</p>

#### ibi_status field

<p>IBI queue fulfils IBI_STATUS_THLD</p>

#### cmd_queue_ready field

<p>Command queue fulfils CMD_EMPTY_BUF_THLD</p>

#### resp_ready field

<p>Response queue fulfils RESP_BUF_THLD</p>

#### transfer_abort field

<p>Transfer aborted</p>

#### transfer_err field

<p>Transfer error</p>

### PIO_INTR_STATUS_ENABLE register

- Absolute Address: 0x124
- Base Offset: 0x24
- Size: 0x4

|Bits|    Identifier    |Access|Reset|          Name         |
|----|------------------|------|-----|-----------------------|
|  0 |  tx_threshold_en |  rw  | 0x0 |    TX_THLD_STAT_EN    |
|  1 |  rx_threshold_en |  rw  | 0x0 |    RX_THLD_STAT_EN    |
|  2 |   ibi_status_en  |  rw  | 0x0 |IBI_STATUS_THLD_STAT_EN|
|  3 |cmd_queue_ready_en|  rw  | 0x0 |CMD_QUEUE_READY_STAT_EN|
|  4 |   resp_ready_en  |  rw  | 0x0 |   RESP_READY_STAT_EN  |
|  5 | transfer_abort_en|  rw  | 0x0 | TRANSFER_ABORT_STAT_EN|
|  9 |  transfer_err_en |  rw  | 0x0 |  TRANSFER_ERR_STAT_EN |

#### tx_threshold_en field

<p>Enable TX queue monitoring</p>

#### rx_threshold_en field

<p>Enable RX queue monitoring</p>

#### ibi_status_en field

<p>Enable IBI queue monitoring</p>

#### cmd_queue_ready_en field

<p>Enable command queue monitoring</p>

#### resp_ready_en field

<p>Enable response queue monitoring</p>

#### transfer_abort_en field

<p>Enable transfer abort monitoring</p>

#### transfer_err_en field

<p>Enable transfer error monitoring</p>

### PIO_INTR_SIGNAL_ENABLE register

- Absolute Address: 0x128
- Base Offset: 0x28
- Size: 0x4

|Bits|       Identifier      |Access|Reset|           Name          |
|----|-----------------------|------|-----|-------------------------|
|  0 |  tx_threshold_intr_en |  rw  | 0x0 |    TX_THLD_SIGNAL_EN    |
|  1 |  rx_threshold_intr_en |  rw  | 0x0 |    RX_THLD_SIGNAL_EN    |
|  2 |   ibi_status_intr_en  |  rw  | 0x0 |IBI_STATUS_THLD_SIGNAL_EN|
|  3 |cmd_queue_ready_intr_en|  rw  | 0x0 |CMD_QUEUE_READY_SIGNAL_EN|
|  4 |   resp_ready_intr_en  |  rw  | 0x0 |   RESP_READY_SIGNAL_EN  |
|  5 | transfer_abort_intr_en|  rw  | 0x0 | TRANSFER_ABORT_SIGNAL_EN|
|  9 |  transfer_err_intr_en |  rw  | 0x0 |  TRANSFER_ERR_SIGNAL_EN |

#### tx_threshold_intr_en field

<p>Enable TX queue interrupt</p>

#### rx_threshold_intr_en field

<p>Enable RX queue interrupt</p>

#### ibi_status_intr_en field

<p>Enable IBI queue interrupt</p>

#### cmd_queue_ready_intr_en field

<p>Enable command queue interrupt</p>

#### resp_ready_intr_en field

<p>Enable response ready interrupt</p>

#### transfer_abort_intr_en field

<p>Enable transfer abort interrupt</p>

#### transfer_err_intr_en field

<p>Enable transfer error interrupt</p>

### PIO_INTR_FORCE register

- Absolute Address: 0x12C
- Base Offset: 0x2C
- Size: 0x4

|Bits|      Identifier     |Access|Reset|         Name        |
|----|---------------------|------|-----|---------------------|
|  0 |  force_tx_threshold |   w  | 0x0 |    TX_THLD_FORCE    |
|  1 |  force_rx_threshold |   w  | 0x0 |    RX_THLD_FORCE    |
|  2 |   force_ibi_status  |   w  | 0x0 |    IBI_THLD_FORCE   |
|  3 |force_cmd_queue_ready|   w  | 0x0 |CMD_QUEUE_READY_FORCE|
|  4 |   force_resp_ready  |   w  | 0x0 |   RESP_READY_FORCE  |
|  5 | force_transfer_abort|   w  | 0x0 | TRANSFER_ABORT_FORCE|
|  9 |  force_transfer_err |   w  | 0x0 |  TRANSFER_ERR_FORCE |

#### force_tx_threshold field

<p>Force TX queue interrupt</p>

#### force_rx_threshold field

<p>Force RX queue interrupt</p>

#### force_ibi_status field

<p>Force IBI queue interrupt</p>

#### force_cmd_queue_ready field

<p>Force command queue interrupt</p>

#### force_resp_ready field

<p>Force response queue interrupt</p>

#### force_transfer_abort field

<p>Force transfer aborted</p>

#### force_transfer_err field

<p>Force transfer error</p>

### PIO_CONTROL register

- Absolute Address: 0x130
- Base Offset: 0x30
- Size: 0x4

|Bits|Identifier|Access|Reset| Name |
|----|----------|------|-----|------|
|  0 |enable_req|  rw  | 0x1 |ENABLE|
|  1 |  rs_req  |  rw  | 0x0 |  RS  |
|  2 | abort_req|  rw  | 0x0 | ABORT|

#### enable_req field

<p>Enables PIO queues. When disabled, SW may not read from/write to PIO queues.
1 - PIO queue enable request,
0 - PIO queue disable request</p>

#### rs_req field

<p>Run/Stop execution of enqueued commands.
When set to 0, it holds execution of enqueued commands and runs current command to completion.
1 - PIO Queue start request,
0 - PIO Queue stop request.</p>

#### abort_req field

<p>Stop current command descriptor execution forcefully and hold remaining commands.
1 - Request PIO Abort,
0 - Resume PIO execution</p>

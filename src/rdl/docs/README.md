<!---
Markdown description for SystemRDL register map.

Don't override. Generated from: I3CCSR
-->

## I3CCSR address map

- Absolute Address: 0x0
- Base Offset: 0x0
- Size: 0x1000

|Offset|Identifier|Name|
|------|----------|----|
| 0x000|  I3CBase |  — |
| 0x080|PIOControl|  — |
| 0x100|  I3C_EC  |  — |
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
|31:0|  VERSION |   r  |0x120|  — |

### HC_CONTROL register

- Absolute Address: 0x4
- Base Offset: 0x4
- Size: 0x4

|Bits|       Identifier      |  Access |Reset|          Name         |
|----|-----------------------|---------|-----|-----------------------|
|  0 |      IBA_INCLUDE      |    rw   | 0x0 |      IBA_INCLUDE      |
|  3 |    AUTOCMD_DATA_RPT   |    r    | 0x0 |    AUTOCMD_DATA_RPT   |
|  4 |  DATA_BYTE_ORDER_MODE |    r    | 0x0 |  DATA_BYTE_ORDER_MODE |
|  6 |     MODE_SELECTOR     |    r    | 0x1 |     MODE_SELECTOR     |
|  7 |    I2C_DEV_PRESENT    |    rw   | 0x0 |    I2C_DEV_PRESENT    |
|  8 |     HOT_JOIN_CTRL     |    rw   | 0x0 |     HOT_JOIN_CTRL     |
| 12 |HALT_ON_CMD_SEQ_TIMEOUT|    rw   | 0x0 |HALT_ON_CMD_SEQ_TIMEOUT|
| 29 |         ABORT         |    rw   | 0x0 |         ABORT         |
| 30 |         RESUME        |rw, woclr| 0x0 |         RESUME        |
| 31 |       BUS_ENABLE      |    rw   | 0x0 |       BUS_ENABLE      |

#### IBA_INCLUDE field

<p>Include I3C Broadcast Address:
0 - skips I3C Broadcast Address for private transfers,
1 - includes I3C Broadcast Address for private transfers.</p>

#### AUTOCMD_DATA_RPT field

<p>Auto-Command Data Report:
0 - coalesced reporting,
1 - separated reporting.</p>

#### DATA_BYTE_ORDER_MODE field

<p>Data Byte Ordering Mode:
0 - Little Endian
1 - Big Endian</p>

#### MODE_SELECTOR field

<p>DMA/PIO Mode Selector:
0 - DMA,
1 - PIO.</p>

#### I2C_DEV_PRESENT field

<p>I2C Device Present on Bus:
0 - pure I3C bus,
1 - legacy I2C devices on the bus.</p>

#### HOT_JOIN_CTRL field

<p>Hot-Join ACK/NACK Control:
0 - ACK Hot-Join request,
1 - NACK Hot-Join request and send Broadcast CCC to disable Hot-Join.</p>

#### HALT_ON_CMD_SEQ_TIMEOUT field

<p>Halt on Command Sequence Timeout when set to 1</p>

#### ABORT field

<p>Host Controller Abort when set to 1</p>

#### RESUME field

<p>Host Controller Resume:
0 - Controller is running,
1 - Controller is suspended.
Write 1 to resume Controller operations.</p>

#### BUS_ENABLE field

<p>Host Controller Bus Enable</p>

### CONTROLLER_DEVICE_ADDR register

- Absolute Address: 0x8
- Base Offset: 0x8
- Size: 0x4

| Bits|    Identifier    |Access|Reset|       Name       |
|-----|------------------|------|-----|------------------|
|22:16|   DYNAMIC_ADDR   |  rw  | 0x0 |   DYNAMIC_ADDR   |
|  31 |DYNAMIC_ADDR_VALID|  rw  | 0x0 |DYNAMIC_ADDR_VALID|

#### DYNAMIC_ADDR field

<p>Device Dynamic Address</p>

#### DYNAMIC_ADDR_VALID field

<p>Dynamic Address is Valid:
0 - dynamic address is invalid,
1 - dynamic address is valid</p>

### HC_CAPABILITIES register

- Absolute Address: 0xC
- Base Offset: 0xC
- Size: 0x4

| Bits|      Identifier     |Access|Reset|         Name        |
|-----|---------------------|------|-----|---------------------|
|  2  |    COMBO_COMMAND    |   r  | 0x0 |    COMBO_COMMAND    |
|  3  |     AUTO_COMMAND    |   r  | 0x0 |     AUTO_COMMAND    |
|  5  |    STANDBY_CR_CAP   |   r  | 0x0 |    STANDBY_CR_CAP   |
|  6  |      HDR_DDR_EN     |   r  | 0x0 |      HDR_DDR_EN     |
|  7  |      HDR_TS_EN      |   r  | 0x0 |      HDR_TS_EN      |
|  10 |   CMD_CCC_DEFBYTE   |   r  | 0x1 |   CMD_CCC_DEFBYTE   |
|  11 |  IBI_DATA_ABORT_EN  |   r  | 0x0 |  IBI_DATA_ABORT_EN  |
|  12 | IBI_CREDIT_COUNT_EN |   r  | 0x0 | IBI_CREDIT_COUNT_EN |
|  13 |SCHEDULED_COMMANDS_EN|   r  | 0x0 |SCHEDULED_COMMANDS_EN|
|21:20|       CMD_SIZE      |   r  | 0x0 |       CMD_SIZE      |
|  28 | SG_CAPABILITY_CR_EN |   r  | 0x0 | SG_CAPABILITY_CR_EN |
|  29 | SG_CAPABILITY_IBI_EN|   r  | 0x0 | SG_CAPABILITY_IBI_EN|
|  30 | SG_CAPABILITY_DC_EN |   r  | 0x0 | SG_CAPABILITY_DC_EN |

#### COMBO_COMMAND field

<p>Controller combined command:
0 - not supported,
1 - supported.</p>

#### AUTO_COMMAND field

<p>Automatic read command on IBI:
0 - not supported,
1 - supported.</p>

#### STANDBY_CR_CAP field

<p>Switching from active to standby mode:
0 - not supported, this controller is always active on I3C,
1- supported, this controller can hand off I3C to secondary controller.</p>

#### HDR_DDR_EN field

<p>HDR-DDR transfers:
0 - not supported,
1 - supported.</p>

#### HDR_TS_EN field

<p>HDR-Ternary transfers:
0 - not supported,
1 - supported.</p>

#### CMD_CCC_DEFBYTE field

<p>CCC with defining byte:
0 - not supported,
1 - supported.</p>

#### IBI_DATA_ABORT_EN field

<p>Controller IBI data abort:
0 - not supported,
1 - supported.</p>

#### IBI_CREDIT_COUNT_EN field

<p>Controller IBI credit count:
0 - not supported,
1 - supported.</p>

#### SCHEDULED_COMMANDS_EN field

<p>Controller command scheduling:
0 - not supported,
1 - supported.</p>

#### CMD_SIZE field

<p>Size and structure of the Command Descriptor:
2'b0: 2 DWORDs,
all other reserved.</p>

#### SG_CAPABILITY_CR_EN field

<p>DMA only: Command and Response rings memory:
0 - must be physically continuous,
1 - controller supports scatter-gather.</p>

#### SG_CAPABILITY_IBI_EN field

<p>DMA only: IBI status and IBI Data rings memory:
0 - must be physically continuous,
1 - controller supports scatter-gather.</p>

#### SG_CAPABILITY_DC_EN field

<p>Device context memory:
0 - must be physically continuous,
1 - controller supports scatter-gather.</p>

### RESET_CONTROL register

- Absolute Address: 0x10
- Base Offset: 0x10
- Size: 0x4

|Bits|  Identifier  |Access|Reset|     Name     |
|----|--------------|------|-----|--------------|
|  0 |   SOFT_RST   |  rw  | 0x0 |   SOFT_RST   |
|  1 | CMD_QUEUE_RST|  rw  | 0x0 | CMD_QUEUE_RST|
|  2 |RESP_QUEUE_RST|  rw  | 0x0 |RESP_QUEUE_RST|
|  3 |  TX_FIFO_RST |  rw  | 0x0 |  TX_FIFO_RST |
|  4 |  RX_FIFO_RST |  rw  | 0x0 |  RX_FIFO_RST |
|  5 | IBI_QUEUE_RST|  rw  | 0x0 | IBI_QUEUE_RST|

#### SOFT_RST field

<p>Reset controller from software.</p>

#### CMD_QUEUE_RST field

<p>Clear command queue from software. Valid only in PIO mode.</p>

#### RESP_QUEUE_RST field

<p>Clear response queue from software. Valid only in PIO mode.</p>

#### TX_FIFO_RST field

<p>Clear TX FIFO from software. Valid only in PIO mode.</p>

#### RX_FIFO_RST field

<p>Clear RX FIFO from software. Valid only in PIO mode.</p>

#### IBI_QUEUE_RST field

<p>Clear IBI queue from software. Valid only in PIO mode.</p>

### PRESENT_STATE register

- Absolute Address: 0x14
- Base Offset: 0x14
- Size: 0x4

|Bits|  Identifier  |Access|Reset|     Name     |
|----|--------------|------|-----|--------------|
|  2 |AC_CURRENT_OWN|   r  | 0x1 |AC_CURRENT_OWN|

#### AC_CURRENT_OWN field

<p>Controller I3C state:
0 - not bus owner,
1 - bus owner.</p>

### INTR_STATUS register

- Absolute Address: 0x20
- Base Offset: 0x20
- Size: 0x4

|Bits|         Identifier        |  Access |Reset|            Name           |
|----|---------------------------|---------|-----|---------------------------|
| 10 |    HC_INTERNAL_ERR_STAT   |rw, woclr| 0x0 |    HC_INTERNAL_ERR_STAT   |
| 11 |     HC_SEQ_CANCEL_STAT    |rw, woclr| 0x0 |     HC_SEQ_CANCEL_STAT    |
| 12 | HC_WARN_CMD_SEQ_STALL_STAT|rw, woclr| 0x0 | HC_WARN_CMD_SEQ_STALL_STAT|
| 13 |HC_ERR_CMD_SEQ_TIMEOUT_STAT|rw, woclr| 0x0 |HC_ERR_CMD_SEQ_TIMEOUT_STAT|
| 14 | SCHED_CMD_MISSED_TICK_STAT|rw, woclr| 0x0 | SCHED_CMD_MISSED_TICK_STAT|

#### HC_INTERNAL_ERR_STAT field

<p>Controller internal unrecoverable error.</p>

#### HC_SEQ_CANCEL_STAT field

<p>Controller had to cancel command sequence.</p>

#### HC_WARN_CMD_SEQ_STALL_STAT field

<p>Clock stalled due to lack of commands.</p>

#### HC_ERR_CMD_SEQ_TIMEOUT_STAT field

<p>Command timeout after prolonged stall.</p>

#### SCHED_CMD_MISSED_TICK_STAT field

<p>Scheduled commands could be executed due to controller being busy.</p>

### INTR_STATUS_ENABLE register

- Absolute Address: 0x24
- Base Offset: 0x24
- Size: 0x4

|Bits|          Identifier          |Access|Reset|             Name             |
|----|------------------------------|------|-----|------------------------------|
| 10 |    HC_INTERNAL_ERR_STAT_EN   |  rw  | 0x0 |    HC_INTERNAL_ERR_STAT_EN   |
| 11 |     HC_SEQ_CANCEL_STAT_EN    |  rw  | 0x0 |     HC_SEQ_CANCEL_STAT_EN    |
| 12 | HC_WARN_CMD_SEQ_STALL_STAT_EN|  rw  | 0x0 | HC_WARN_CMD_SEQ_STALL_STAT_EN|
| 13 |HC_ERR_CMD_SEQ_TIMEOUT_STAT_EN|  rw  | 0x0 |HC_ERR_CMD_SEQ_TIMEOUT_STAT_EN|
| 14 | SCHED_CMD_MISSED_TICK_STAT_EN|  rw  | 0x0 | SCHED_CMD_MISSED_TICK_STAT_EN|

#### HC_INTERNAL_ERR_STAT_EN field

<p>Enable HC_INTERNAL_ERR_STAT monitoring.</p>

#### HC_SEQ_CANCEL_STAT_EN field

<p>Enable HC_SEQ_CANCEL_STAT monitoring.</p>

#### HC_WARN_CMD_SEQ_STALL_STAT_EN field

<p>Enable HC_WARN_CMD_SEQ_STALL_STAT monitoring.</p>

#### HC_ERR_CMD_SEQ_TIMEOUT_STAT_EN field

<p>Enable HC_ERR_CMD_SEQ_TIMEOUT_STAT monitoring.</p>

#### SCHED_CMD_MISSED_TICK_STAT_EN field

<p>Enable SCHED_CMD_MISSED_TICK_STAT monitoring.</p>

### INTR_SIGNAL_ENABLE register

- Absolute Address: 0x28
- Base Offset: 0x28
- Size: 0x4

|Bits|           Identifier           |Access|Reset|              Name              |
|----|--------------------------------|------|-----|--------------------------------|
| 10 |    HC_INTERNAL_ERR_SIGNAL_EN   |  rw  | 0x0 |    HC_INTERNAL_ERR_SIGNAL_EN   |
| 11 |     HC_SEQ_CANCEL_SIGNAL_EN    |  rw  | 0x0 |     HC_SEQ_CANCEL_SIGNAL_EN    |
| 12 | HC_WARN_CMD_SEQ_STALL_SIGNAL_EN|  rw  | 0x0 | HC_WARN_CMD_SEQ_STALL_SIGNAL_EN|
| 13 |HC_ERR_CMD_SEQ_TIMEOUT_SIGNAL_EN|  rw  | 0x0 |HC_ERR_CMD_SEQ_TIMEOUT_SIGNAL_EN|
| 14 | SCHED_CMD_MISSED_TICK_SIGNAL_EN|  rw  | 0x0 | SCHED_CMD_MISSED_TICK_SIGNAL_EN|

#### HC_INTERNAL_ERR_SIGNAL_EN field

<p>Enable HC_INTERNAL_ERR_STAT interrupt.</p>

#### HC_SEQ_CANCEL_SIGNAL_EN field

<p>Enable HC_SEQ_CANCEL_STAT interrupt.</p>

#### HC_WARN_CMD_SEQ_STALL_SIGNAL_EN field

<p>Enable HC_WARN_CMD_SEQ_STALL_STAT interrupt.</p>

#### HC_ERR_CMD_SEQ_TIMEOUT_SIGNAL_EN field

<p>Enable HC_ERR_CMD_SEQ_TIMEOUT_STAT interrupt.</p>

#### SCHED_CMD_MISSED_TICK_SIGNAL_EN field

<p>Enable SCHED_CMD_MISSED_TICK_STAT interrupt.</p>

### INTR_FORCE register

- Absolute Address: 0x2C
- Base Offset: 0x2C
- Size: 0x4

|Bits|         Identifier         |Access|Reset|            Name            |
|----|----------------------------|------|-----|----------------------------|
| 10 |    HC_INTERNAL_ERR_FORCE   |   w  | 0x0 |    HC_INTERNAL_ERR_FORCE   |
| 11 |     HC_SEQ_CANCEL_FORCE    |   w  | 0x0 |     HC_SEQ_CANCEL_FORCE    |
| 12 | HC_WARN_CMD_SEQ_STALL_FORCE|   w  | 0x0 | HC_WARN_CMD_SEQ_STALL_FORCE|
| 13 |HC_ERR_CMD_SEQ_TIMEOUT_FORCE|   w  | 0x0 |HC_ERR_CMD_SEQ_TIMEOUT_FORCE|
| 14 | SCHED_CMD_MISSED_TICK_FORCE|   w  | 0x0 | SCHED_CMD_MISSED_TICK_FORCE|

#### HC_INTERNAL_ERR_FORCE field

<p>Force HC_INTERNAL_ERR_STAT interrupt.</p>

#### HC_SEQ_CANCEL_FORCE field

<p>Force HC_SEQ_CANCEL_STAT interrupt.</p>

#### HC_WARN_CMD_SEQ_STALL_FORCE field

<p>Force HC_WARN_CMD_SEQ_STALL_STAT interrupt.</p>

#### HC_ERR_CMD_SEQ_TIMEOUT_FORCE field

<p>Force HC_ERR_CMD_SEQ_TIMEOUT_STAT interrupt.</p>

#### SCHED_CMD_MISSED_TICK_FORCE field

<p>Force SCHED_CMD_MISSED_TICK_STAT interrupt.</p>

### DAT_SECTION_OFFSET register

- Absolute Address: 0x30
- Base Offset: 0x30
- Size: 0x4

| Bits| Identifier |Access|Reset|    Name    |
|-----|------------|------|-----|------------|
| 11:0|TABLE_OFFSET|   r  |0x400|TABLE_OFFSET|
|18:12| TABLE_SIZE |   r  | 0x7F| TABLE_SIZE |
|31:28| ENTRY_SIZE |   r  | 0x0 | ENTRY_SIZE |

#### TABLE_OFFSET field

<p>DAT entry offset in respect to BASE address.</p>

#### TABLE_SIZE field

<p>Max number of DAT entries.</p>

#### ENTRY_SIZE field

<p>Individual DAT entry size.
0 - 2 DWRODs,
1:15 - reserved.</p>

### DCT_SECTION_OFFSET register

- Absolute Address: 0x34
- Base Offset: 0x34
- Size: 0x4

| Bits| Identifier |Access|Reset|    Name    |
|-----|------------|------|-----|------------|
| 11:0|TABLE_OFFSET|   r  |0x800|TABLE_OFFSET|
|18:12| TABLE_SIZE |   r  | 0x7F| TABLE_SIZE |
|23:19| TABLE_INDEX|  rw  | 0x0 | TABLE_INDEX|
|31:28| ENTRY_SIZE |   r  | 0x0 | ENTRY_SIZE |

#### TABLE_OFFSET field

<p>DCT entry offset in respect to BASE address.</p>

#### TABLE_SIZE field

<p>Max number of DCT entries.</p>

#### TABLE_INDEX field

<p>Index to DCT used during ENTDAA.</p>

#### ENTRY_SIZE field

<p>Individual DCT entry size.
0 - 4 DWORDs,
1:15 - Reserved.</p>

### RING_HEADERS_SECTION_OFFSET register

- Absolute Address: 0x38
- Base Offset: 0x38
- Size: 0x4

|Bits|  Identifier  |Access|Reset|     Name     |
|----|--------------|------|-----|--------------|
|15:0|SECTION_OFFSET|   r  | 0x0 |SECTION_OFFSET|

#### SECTION_OFFSET field

<p>DMA ring headers section offset. Invalid if 0.</p>

### PIO_SECTION_OFFSET register

- Absolute Address: 0x3C
- Base Offset: 0x3C
- Size: 0x4

|Bits|  Identifier  |Access|Reset|     Name     |
|----|--------------|------|-----|--------------|
|15:0|SECTION_OFFSET|   r  | 0x80|SECTION_OFFSET|

#### SECTION_OFFSET field

<p>PIO section offset. Invalid if 0.</p>

### EXT_CAPS_SECTION_OFFSET register

- Absolute Address: 0x40
- Base Offset: 0x40
- Size: 0x4

|Bits|  Identifier  |Access|Reset|     Name     |
|----|--------------|------|-----|--------------|
|15:0|SECTION_OFFSET|   r  | 0x0 |SECTION_OFFSET|

#### SECTION_OFFSET field

<p>Extended Capabilities section offset. Invalid if 0.</p>

### INT_CTRL_CMDS_EN register

- Absolute Address: 0x4C
- Base Offset: 0x4C
- Size: 0x4

|Bits|     Identifier    |Access|Reset|        Name       |
|----|-------------------|------|-----|-------------------|
|  0 |    ICC_SUPPORT    |   r  | 0x1 |    ICC_SUPPORT    |
|15:1|MIPI_CMDS_SUPPORTED|   r  | 0x35|MIPI_CMDS_SUPPORTED|

#### ICC_SUPPORT field

<p>Internal Control Commands:
1 - some or all internals commands sub-commands are supported,
0 - illegal.</p>

#### MIPI_CMDS_SUPPORTED field

<p>Bitmask of supported MIPI commands.</p>

### IBI_NOTIFY_CTRL register

- Absolute Address: 0x58
- Base Offset: 0x58
- Size: 0x4

|Bits|     Identifier    |Access|Reset|        Name       |
|----|-------------------|------|-----|-------------------|
|  0 | NOTIFY_HJ_REJECTED|  rw  | 0x0 | NOTIFY_HJ_REJECTED|
|  1 |NOTIFY_CRR_REJECTED|  rw  | 0x0 |NOTIFY_CRR_REJECTED|
|  3 |NOTIFY_IBI_REJECTED|  rw  | 0x0 |NOTIFY_IBI_REJECTED|

#### NOTIFY_HJ_REJECTED field

<p>Notify about rejected hot-join:
0 - do not enqueue rejected HJ,
1 = enqueue rejected HJ on IBI queue/ring.</p>

#### NOTIFY_CRR_REJECTED field

<p>Notify about rejected controller role request:
0 - do not enqueue rejected CRR,
1 = enqueue rejected CRR on IBI queue/ring.</p>

#### NOTIFY_IBI_REJECTED field

<p>Notify about rejected IBI:
0 - do not enqueue rejected IBI,
1 = enqueue rejected IBI on IBI queue/ring.</p>

### IBI_DATA_ABORT_CTRL register

- Absolute Address: 0x5C
- Base Offset: 0x5C
- Size: 0x4

| Bits|    Identifier    |Access|Reset|       Name       |
|-----|------------------|------|-----|------------------|
| 15:8|   MATCH_IBI_ID   |  rw  | 0x0 |   MATCH_IBI_ID   |
|17:16|  AFTER_N_CHUNKS  |  rw  | 0x0 |  AFTER_N_CHUNKS  |
|20:18| MATCH_STATUS_TYPE|  rw  | 0x0 | MATCH_STATUS_TYPE|
|  31 |IBI_DATA_ABORT_MON|  rw  | 0x0 |IBI_DATA_ABORT_MON|

#### MATCH_IBI_ID field

<p>IBI target address:
[15:9] - device address,
[8] - must always be set to 1'b1</p>

#### AFTER_N_CHUNKS field

<p>Number of data chunks to be allowed before forced termination:
0 - immediate,
1:3 - delay by 1-3 data chunks.</p>

#### MATCH_STATUS_TYPE field

<p>Define which IBI should be aborted:
3'b000 - Regular IBI,
3'b100 - Autocmd IBI,
other values - not supported.</p>

#### IBI_DATA_ABORT_MON field

<p>Enable/disable IBI monitoring logic.</p>

### DEV_CTX_BASE_LO register

- Absolute Address: 0x60
- Base Offset: 0x60
- Size: 0x4

|Bits|Identifier|Access|Reset|Name|
|----|----------|------|-----|----|
|  0 |  BASE_LO |  rw  | 0x0 |  — |

### DEV_CTX_BASE_HI register

- Absolute Address: 0x64
- Base Offset: 0x64
- Size: 0x4

|Bits|Identifier|Access|Reset|Name|
|----|----------|------|-----|----|
|  0 |  BASE_HI |  rw  | 0x0 |  — |

### DEV_CTX_SG register

- Absolute Address: 0x68
- Base Offset: 0x68
- Size: 0x4

|Bits|Identifier|Access|Reset|   Name  |
|----|----------|------|-----|---------|
|15:0| LIST_SIZE|   r  | 0x0 |LIST_SIZE|
| 31 |    BLP   |   r  | 0x0 |   BLP   |

#### LIST_SIZE field

<p>Number of SG entries.</p>

#### BLP field

<p>Buffer vs list pointer in device context:
0 - continuous physical memory region,
1 - pointer to SG descriptor list.</p>

## PIOControl register file

- Absolute Address: 0x80
- Base Offset: 0x80
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

- Absolute Address: 0x80
- Base Offset: 0x0
- Size: 0x4

|Bits| Identifier |Access|Reset|       Name       |
|----|------------|------|-----|------------------|
|  0 |COMMAND_DATA|   w  |  —  |COMMAND_QUEUE_PORT|

### RESPONSE_PORT register

- Absolute Address: 0x84
- Base Offset: 0x4
- Size: 0x4

|Bits|  Identifier |Access|Reset|        Name       |
|----|-------------|------|-----|-------------------|
|  0 |RESPONSE_DATA|   r  |  —  |RESPONSE_QUEUE_PORT|

### XFER_DATA_PORT register

- Absolute Address: 0x88
- Base Offset: 0x8
- Size: 0x4

|Bits|Identifier|Access|Reset|  Name |
|----|----------|------|-----|-------|
|31:0|  TX_DATA |   w  |  —  |TX_DATA|
|31:0|  RX_DATA |   r  |  —  |RX_DATA|

### IBI_PORT register

- Absolute Address: 0x8C
- Base Offset: 0xC
- Size: 0x4

|Bits|Identifier|Access|Reset|  Name  |
|----|----------|------|-----|--------|
|  0 | IBI_DATA |   r  |  —  |IBI_DATA|

### QUEUE_THLD_CTRL register

- Absolute Address: 0x90
- Base Offset: 0x10
- Size: 0x4

| Bits|      Identifier     |Access|Reset|         Name        |
|-----|---------------------|------|-----|---------------------|
| 7:0 |  CMD_EMPTY_BUF_THLD |  rw  | 0x1 |  CMD_EMPTY_BUF_THLD |
| 15:8|    RESP_BUF_THLD    |  rw  | 0x1 |    RESP_BUF_THLD    |
|23:16|IBI_DATA_SEGMENT_SIZE|  rw  | 0x1 |IBI_DATA_SEGMENT_SIZE|
|31:24|   IBI_STATUS_THLD   |  rw  | 0x1 |   IBI_STATUS_THLD   |

#### CMD_EMPTY_BUF_THLD field

<p>Triggers CMD_QUEUE_READY_STAT interrupt when CMD queue has N or more free entries. Accepted values are 1:255</p>

#### RESP_BUF_THLD field

<p>Triggers RESP_READY_STAT interrupt when RESP queue has N or more entries. Accepted values are 1:255</p>

#### IBI_DATA_SEGMENT_SIZE field

<p>IBI Queue data segment size. Valida values are 1:63</p>

#### IBI_STATUS_THLD field

<p>Triggers IBI_STATUS_THLD_STAT interrupt when IBI queue has N or more entries. Accepted values are 1:255</p>

### DATA_BUFFER_THLD_CTRL register

- Absolute Address: 0x94
- Base Offset: 0x14
- Size: 0x4

| Bits|  Identifier |Access|Reset|     Name    |
|-----|-------------|------|-----|-------------|
| 2:0 | TX_BUF_THLD |  rw  | 0x1 | TX_BUF_THLD |
| 10:8| RX_BUF_THLD |  rw  | 0x1 | RX_BUF_THLD |
|18:16|TX_START_THLD|  rw  | 0x1 |TX_START_THLD|
|26:24|RX_START_THLD|  rw  | 0x1 |RX_START_THLD|

#### TX_BUF_THLD field

<p>Trigger TX_THLD_STAT interrupt when TX queue has 2^(N+1) or more free entries</p>

#### RX_BUF_THLD field

<p>Trigger RX_THLD_STAT interrupt when RX queue has 2^(N+1) or more entries</p>

#### TX_START_THLD field

<p>Postpone write command until TX queue has 2^(N+1) entries</p>

#### RX_START_THLD field

<p>Postpone read command until RX queue has 2^(N+1) free entries</p>

### QUEUE_SIZE register

- Absolute Address: 0x98
- Base Offset: 0x18
- Size: 0x4

| Bits|     Identifier    |Access|Reset|        Name       |
|-----|-------------------|------|-----|-------------------|
| 7:0 |   CR_QUEUE_SIZE   |   r  | 0x40|   CR_QUEUE_SIZE   |
| 15:8|  IBI_STATUS_SIZE  |   r  | 0x40|  IBI_STATUS_SIZE  |
|23:16|RX_DATA_BUFFER_SIZE|   r  | 0x5 |RX_DATA_BUFFER_SIZE|
|31:24|TX_DATA_BUFFER_SIZE|   r  | 0x5 |TX_DATA_BUFFER_SIZE|

#### CR_QUEUE_SIZE field

<p>Command/Response queue size is equal to N</p>

#### IBI_STATUS_SIZE field

<p>IBI Queue size is equal to N</p>

#### RX_DATA_BUFFER_SIZE field

<p>RX queue size is equal to 2^(N+1), where N is this field value</p>

#### TX_DATA_BUFFER_SIZE field

<p>TX queue size is equal to 2^(N+1), where N is this field value</p>

### ALT_QUEUE_SIZE register

- Absolute Address: 0x9C
- Base Offset: 0x1C
- Size: 0x4

|Bits|     Identifier    |Access|Reset|        Name       |
|----|-------------------|------|-----|-------------------|
| 7:0|ALT_RESP_QUEUE_SIZE|   r  | 0x40|ALT_RESP_QUEUE_SIZE|
| 24 | ALT_RESP_QUEUE_EN |   r  | 0x0 | ALT_RESP_QUEUE_EN |
| 28 |  EXT_IBI_QUEUE_EN |   r  | 0x0 |  EXT_IBI_QUEUE_EN |

#### ALT_RESP_QUEUE_SIZE field

<p>Valid only if ALT_RESP_QUEUE_EN is set. Contains response queue size</p>

#### ALT_RESP_QUEUE_EN field

<p>If set, response and command queues are not equal lengths, then
ALT_RESP_QUEUE_SIZE contains response queue size</p>

#### EXT_IBI_QUEUE_EN field

<p>1 indicates that IBI queue size is equal to 8*IBI_STATUS_SIZE</p>

### PIO_INTR_STATUS register

- Absolute Address: 0xA0
- Base Offset: 0x20
- Size: 0x4

|Bits|     Identifier     |  Access |Reset|        Name        |
|----|--------------------|---------|-----|--------------------|
|  0 |    TX_THLD_STAT    |    r    | 0x0 |    TX_THLD_STAT    |
|  1 |    RX_THLD_STAT    |    r    | 0x0 |    RX_THLD_STAT    |
|  2 |IBI_STATUS_THLD_STAT|    r    | 0x0 |IBI_STATUS_THLD_STAT|
|  3 |CMD_QUEUE_READY_STAT|    r    | 0x0 |CMD_QUEUE_READY_STAT|
|  4 |   RESP_READY_STAT  |    r    | 0x0 |   RESP_READY_STAT  |
|  5 | TRANSFER_ABORT_STAT|rw, woclr| 0x0 | TRANSFER_ABORT_STAT|
|  9 |  TRANSFER_ERR_STAT |rw, woclr| 0x0 |  TRANSFER_ERR_STAT |

#### TX_THLD_STAT field

<p>TX queue fulfils TX_BUF_THLD</p>

#### RX_THLD_STAT field

<p>RX queue fulfils RX_BUF_THLD</p>

#### IBI_STATUS_THLD_STAT field

<p>IBI queue fulfils IBI_STATUS_THLD</p>

#### CMD_QUEUE_READY_STAT field

<p>Command queue fulfils CMD_EMPTY_BUF_THLD</p>

#### RESP_READY_STAT field

<p>Response queue fulfils RESP_BUF_THLD</p>

#### TRANSFER_ABORT_STAT field

<p>Transfer aborted</p>

#### TRANSFER_ERR_STAT field

<p>Transfer error</p>

### PIO_INTR_STATUS_ENABLE register

- Absolute Address: 0xA4
- Base Offset: 0x24
- Size: 0x4

|Bits|       Identifier      |Access|Reset|          Name         |
|----|-----------------------|------|-----|-----------------------|
|  0 |    TX_THLD_STAT_EN    |  rw  | 0x0 |    TX_THLD_STAT_EN    |
|  1 |    RX_THLD_STAT_EN    |  rw  | 0x0 |    RX_THLD_STAT_EN    |
|  2 |IBI_STATUS_THLD_STAT_EN|  rw  | 0x0 |IBI_STATUS_THLD_STAT_EN|
|  3 |CMD_QUEUE_READY_STAT_EN|  rw  | 0x0 |CMD_QUEUE_READY_STAT_EN|
|  4 |   RESP_READY_STAT_EN  |  rw  | 0x0 |   RESP_READY_STAT_EN  |
|  5 | TRANSFER_ABORT_STAT_EN|  rw  | 0x0 | TRANSFER_ABORT_STAT_EN|
|  9 |  TRANSFER_ERR_STAT_EN |  rw  | 0x0 |  TRANSFER_ERR_STAT_EN |

#### TX_THLD_STAT_EN field

<p>Enable TX queue monitoring</p>

#### RX_THLD_STAT_EN field

<p>Enable RX queue monitoring</p>

#### IBI_STATUS_THLD_STAT_EN field

<p>Enable IBI queue monitoring</p>

#### CMD_QUEUE_READY_STAT_EN field

<p>Enable command queue monitoring</p>

#### RESP_READY_STAT_EN field

<p>Enable response queue monitoring</p>

#### TRANSFER_ABORT_STAT_EN field

<p>Enable transfer abort monitoring</p>

#### TRANSFER_ERR_STAT_EN field

<p>Enable transfer error monitoring</p>

### PIO_INTR_SIGNAL_ENABLE register

- Absolute Address: 0xA8
- Base Offset: 0x28
- Size: 0x4

|Bits|        Identifier       |Access|Reset|           Name          |
|----|-------------------------|------|-----|-------------------------|
|  0 |    TX_THLD_SIGNAL_EN    |  rw  | 0x0 |    TX_THLD_SIGNAL_EN    |
|  1 |    RX_THLD_SIGNAL_EN    |  rw  | 0x0 |    RX_THLD_SIGNAL_EN    |
|  2 |IBI_STATUS_THLD_SIGNAL_EN|  rw  | 0x0 |IBI_STATUS_THLD_SIGNAL_EN|
|  3 |CMD_QUEUE_READY_SIGNAL_EN|  rw  | 0x0 |CMD_QUEUE_READY_SIGNAL_EN|
|  4 |   RESP_READY_SIGNAL_EN  |  rw  | 0x0 |   RESP_READY_SIGNAL_EN  |
|  5 | TRANSFER_ABORT_SIGNAL_EN|  rw  | 0x0 | TRANSFER_ABORT_SIGNAL_EN|
|  9 |  TRANSFER_ERR_SIGNAL_EN |  rw  | 0x0 |  TRANSFER_ERR_SIGNAL_EN |

#### TX_THLD_SIGNAL_EN field

<p>Enable TX queue interrupt</p>

#### RX_THLD_SIGNAL_EN field

<p>Enable RX queue interrupt</p>

#### IBI_STATUS_THLD_SIGNAL_EN field

<p>Enable IBI queue interrupt</p>

#### CMD_QUEUE_READY_SIGNAL_EN field

<p>Enable command queue interrupt</p>

#### RESP_READY_SIGNAL_EN field

<p>Enable response ready interrupt</p>

#### TRANSFER_ABORT_SIGNAL_EN field

<p>Enable transfer abort interrupt</p>

#### TRANSFER_ERR_SIGNAL_EN field

<p>Enable transfer error interrupt</p>

### PIO_INTR_FORCE register

- Absolute Address: 0xAC
- Base Offset: 0x2C
- Size: 0x4

|Bits|      Identifier     |Access|Reset|         Name        |
|----|---------------------|------|-----|---------------------|
|  0 |    TX_THLD_FORCE    |   w  | 0x0 |    TX_THLD_FORCE    |
|  1 |    RX_THLD_FORCE    |   w  | 0x0 |    RX_THLD_FORCE    |
|  2 |    IBI_THLD_FORCE   |   w  | 0x0 |    IBI_THLD_FORCE   |
|  3 |CMD_QUEUE_READY_FORCE|   w  | 0x0 |CMD_QUEUE_READY_FORCE|
|  4 |   RESP_READY_FORCE  |   w  | 0x0 |   RESP_READY_FORCE  |
|  5 | TRANSFER_ABORT_FORCE|   w  | 0x0 | TRANSFER_ABORT_FORCE|
|  9 |  TRANSFER_ERR_FORCE |   w  | 0x0 |  TRANSFER_ERR_FORCE |

#### TX_THLD_FORCE field

<p>Force TX queue interrupt</p>

#### RX_THLD_FORCE field

<p>Force RX queue interrupt</p>

#### IBI_THLD_FORCE field

<p>Force IBI queue interrupt</p>

#### CMD_QUEUE_READY_FORCE field

<p>Force command queue interrupt</p>

#### RESP_READY_FORCE field

<p>Force response queue interrupt</p>

#### TRANSFER_ABORT_FORCE field

<p>Force transfer aborted</p>

#### TRANSFER_ERR_FORCE field

<p>Force transfer error</p>

### PIO_CONTROL register

- Absolute Address: 0xB0
- Base Offset: 0x30
- Size: 0x4

|Bits|Identifier|Access|Reset| Name |
|----|----------|------|-----|------|
|  0 |  ENABLE  |  rw  | 0x1 |ENABLE|
|  1 |    RS    |  rw  | 0x0 |  RS  |
|  2 |   ABORT  |  rw  | 0x0 | ABORT|

#### ENABLE field

<p>Enables PIO queues. When disabled, SW may not read from/write to PIO queues.
1 - PIO queue enable request,
0 - PIO queue disable request</p>

#### RS field

<p>Run/Stop execution of enqueued commands.
When set to 0, it holds execution of enqueued commands and runs current command to completion.
1 - PIO Queue start request,
0 - PIO Queue stop request.</p>

#### ABORT field

<p>Stop current command descriptor execution forcefully and hold remaining commands.
1 - Request PIO Abort,
0 - Resume PIO execution</p>

## I3C_EC register file

- Absolute Address: 0x100
- Base Offset: 0x100
- Size: 0xC0

|Offset|               Identifier               |Name|
|------|----------------------------------------|----|
| 0x00 |SecureFirmwareRecoveryInterfaceRegisters|  — |
| 0x80 |   TargetTransactionInterfaceRegisters  |  — |
| 0xB0 |     SoCManagementInterfaceRegisters    |  — |
| 0xB8 |        ControllerConfigRegisters       |  — |

## SecureFirmwareRecoveryInterfaceRegisters register file

- Absolute Address: 0x100
- Base Offset: 0x0
- Size: 0x6C

|Offset|      Identifier      |         Name         |
|------|----------------------|----------------------|
| 0x00 |     EXTCAP_HEADER    |           —          |
| 0x04 |      PROT_CAP_0      |      PROT_CAP_0      |
| 0x08 |      PROT_CAP_1      |      PROT_CAP_1      |
| 0x0C |      PROT_CAP_2      |      PROT_CAP_2      |
| 0x10 |      PROT_CAP_3      |      PROT_CAP_3      |
| 0x14 |      DEVICE_ID_0     |      DEVICE_ID_0     |
| 0x18 |      DEVICE_ID_1     |      DEVICE_ID_1     |
| 0x1C |      DEVICE_ID_2     |      DEVICE_ID_2     |
| 0x20 |      DEVICE_ID_3     |      DEVICE_ID_3     |
| 0x24 |      DEVICE_ID_4     |      DEVICE_ID_4     |
| 0x28 |      DEVICE_ID_5     |      DEVICE_ID_5     |
| 0x2C |      DEVICE_ID_6     |      DEVICE_ID_6     |
| 0x30 |    DEVICE_STATUS_0   |    DEVICE_STATUS_0   |
| 0x34 |    DEVICE_STATUS_1   |    DEVICE_STATUS_1   |
| 0x38 |     DEVICE_RESET     |     DEVICE_RESET     |
| 0x3C |     RECOVERY_CTRL    |     RECOVERY_CTRL    |
| 0x40 |    RECOVERY_STATUS   |    RECOVERY_STATUS   |
| 0x44 |       HW_STATUS      |       HW_STATUS      |
| 0x48 | INDIRECT_FIFO_CTRL_0 | INDIRECT_FIFO_CTRL_0 |
| 0x4C | INDIRECT_FIFO_CTRL_1 | INDIRECT_FIFO_CTRL_1 |
| 0x50 |INDIRECT_FIFO_STATUS_0|INDIRECT_FIFO_STATUS_0|
| 0x54 |INDIRECT_FIFO_STATUS_1|INDIRECT_FIFO_STATUS_1|
| 0x58 |INDIRECT_FIFO_STATUS_2|INDIRECT_FIFO_STATUS_2|
| 0x5C |INDIRECT_FIFO_STATUS_3|INDIRECT_FIFO_STATUS_3|
| 0x60 |INDIRECT_FIFO_STATUS_4|INDIRECT_FIFO_STATUS_4|
| 0x64 |INDIRECT_FIFO_STATUS_5|INDIRECT_FIFO_STATUS_5|
| 0x68 |  INDIRECT_FIFO_DATA  |  INDIRECT_FIFO_DATA  |

### EXTCAP_HEADER register

- Absolute Address: 0x100
- Base Offset: 0x0
- Size: 0x4

|Bits|Identifier|Access|Reset|   Name   |
|----|----------|------|-----|----------|
| 7:0|  CAP_ID  |   r  | 0x0 |  CAP_ID  |
|23:8|CAP_LENGTH|   r  | 0x0 |CAP_LENGTH|

#### CAP_ID field

<p>Extended Capability ID</p>

#### CAP_LENGTH field

<p>Capability Structure Length in DWORDs</p>

### PROT_CAP_0 register

- Absolute Address: 0x104
- Base Offset: 0x4
- Size: 0x4

|Bits| Identifier|Access|Reset|Name|
|----|-----------|------|-----|----|
|31:0|PLACEHOLDER|  rw  | 0x0 |    |

#### PLACEHOLDER field



### PROT_CAP_1 register

- Absolute Address: 0x108
- Base Offset: 0x8
- Size: 0x4

|Bits| Identifier|Access|Reset|Name|
|----|-----------|------|-----|----|
|31:0|PLACEHOLDER|  rw  | 0x0 |    |

#### PLACEHOLDER field



### PROT_CAP_2 register

- Absolute Address: 0x10C
- Base Offset: 0xC
- Size: 0x4

|Bits| Identifier|Access|Reset|Name|
|----|-----------|------|-----|----|
|31:0|PLACEHOLDER|  rw  | 0x0 |    |

#### PLACEHOLDER field



### PROT_CAP_3 register

- Absolute Address: 0x110
- Base Offset: 0x10
- Size: 0x4

|Bits| Identifier|Access|Reset|Name|
|----|-----------|------|-----|----|
|31:0|PLACEHOLDER|  rw  | 0x0 |    |

#### PLACEHOLDER field



### DEVICE_ID_0 register

- Absolute Address: 0x114
- Base Offset: 0x14
- Size: 0x4

|Bits| Identifier|Access|Reset|Name|
|----|-----------|------|-----|----|
|31:0|PLACEHOLDER|  rw  | 0x0 |    |

#### PLACEHOLDER field



### DEVICE_ID_1 register

- Absolute Address: 0x118
- Base Offset: 0x18
- Size: 0x4

|Bits| Identifier|Access|Reset|Name|
|----|-----------|------|-----|----|
|31:0|PLACEHOLDER|  rw  | 0x0 |    |

#### PLACEHOLDER field



### DEVICE_ID_2 register

- Absolute Address: 0x11C
- Base Offset: 0x1C
- Size: 0x4

|Bits| Identifier|Access|Reset|Name|
|----|-----------|------|-----|----|
|31:0|PLACEHOLDER|  rw  | 0x0 |    |

#### PLACEHOLDER field



### DEVICE_ID_3 register

- Absolute Address: 0x120
- Base Offset: 0x20
- Size: 0x4

|Bits| Identifier|Access|Reset|Name|
|----|-----------|------|-----|----|
|31:0|PLACEHOLDER|  rw  | 0x0 |    |

#### PLACEHOLDER field



### DEVICE_ID_4 register

- Absolute Address: 0x124
- Base Offset: 0x24
- Size: 0x4

|Bits| Identifier|Access|Reset|Name|
|----|-----------|------|-----|----|
|31:0|PLACEHOLDER|  rw  | 0x0 |    |

#### PLACEHOLDER field



### DEVICE_ID_5 register

- Absolute Address: 0x128
- Base Offset: 0x28
- Size: 0x4

|Bits| Identifier|Access|Reset|Name|
|----|-----------|------|-----|----|
|31:0|PLACEHOLDER|  rw  | 0x0 |    |

#### PLACEHOLDER field



### DEVICE_ID_6 register

- Absolute Address: 0x12C
- Base Offset: 0x2C
- Size: 0x4

|Bits| Identifier|Access|Reset|Name|
|----|-----------|------|-----|----|
|31:0|PLACEHOLDER|  rw  | 0x0 |    |

#### PLACEHOLDER field



### DEVICE_STATUS_0 register

- Absolute Address: 0x130
- Base Offset: 0x30
- Size: 0x4

|Bits| Identifier|Access|Reset|Name|
|----|-----------|------|-----|----|
|31:0|PLACEHOLDER|  rw  | 0x0 |    |

#### PLACEHOLDER field



### DEVICE_STATUS_1 register

- Absolute Address: 0x134
- Base Offset: 0x34
- Size: 0x4

|Bits| Identifier|Access|Reset|Name|
|----|-----------|------|-----|----|
|31:0|PLACEHOLDER|  rw  | 0x0 |    |

#### PLACEHOLDER field



### DEVICE_RESET register

- Absolute Address: 0x138
- Base Offset: 0x38
- Size: 0x4

|Bits| Identifier|Access|Reset|Name|
|----|-----------|------|-----|----|
|31:0|PLACEHOLDER|  rw  | 0x0 |    |

#### PLACEHOLDER field



### RECOVERY_CTRL register

- Absolute Address: 0x13C
- Base Offset: 0x3C
- Size: 0x4

|Bits| Identifier|Access|Reset|Name|
|----|-----------|------|-----|----|
|31:0|PLACEHOLDER|  rw  | 0x0 |    |

#### PLACEHOLDER field



### RECOVERY_STATUS register

- Absolute Address: 0x140
- Base Offset: 0x40
- Size: 0x4

|Bits| Identifier|Access|Reset|Name|
|----|-----------|------|-----|----|
|31:0|PLACEHOLDER|  rw  | 0x0 |    |

#### PLACEHOLDER field



### HW_STATUS register

- Absolute Address: 0x144
- Base Offset: 0x44
- Size: 0x4

|Bits| Identifier|Access|Reset|Name|
|----|-----------|------|-----|----|
|31:0|PLACEHOLDER|  rw  | 0x0 |    |

#### PLACEHOLDER field



### INDIRECT_FIFO_CTRL_0 register

- Absolute Address: 0x148
- Base Offset: 0x48
- Size: 0x4

|Bits| Identifier|Access|Reset|Name|
|----|-----------|------|-----|----|
|31:0|PLACEHOLDER|  rw  | 0x0 |    |

#### PLACEHOLDER field



### INDIRECT_FIFO_CTRL_1 register

- Absolute Address: 0x14C
- Base Offset: 0x4C
- Size: 0x4

|Bits| Identifier|Access|Reset|Name|
|----|-----------|------|-----|----|
|31:0|PLACEHOLDER|  rw  | 0x0 |    |

#### PLACEHOLDER field



### INDIRECT_FIFO_STATUS_0 register

- Absolute Address: 0x150
- Base Offset: 0x50
- Size: 0x4

|Bits| Identifier|Access|Reset|Name|
|----|-----------|------|-----|----|
|31:0|PLACEHOLDER|  rw  | 0x0 |    |

#### PLACEHOLDER field



### INDIRECT_FIFO_STATUS_1 register

- Absolute Address: 0x154
- Base Offset: 0x54
- Size: 0x4

|Bits| Identifier|Access|Reset|Name|
|----|-----------|------|-----|----|
|31:0|PLACEHOLDER|  rw  | 0x0 |    |

#### PLACEHOLDER field



### INDIRECT_FIFO_STATUS_2 register

- Absolute Address: 0x158
- Base Offset: 0x58
- Size: 0x4

|Bits| Identifier|Access|Reset|Name|
|----|-----------|------|-----|----|
|31:0|PLACEHOLDER|  rw  | 0x0 |    |

#### PLACEHOLDER field



### INDIRECT_FIFO_STATUS_3 register

- Absolute Address: 0x15C
- Base Offset: 0x5C
- Size: 0x4

|Bits| Identifier|Access|Reset|Name|
|----|-----------|------|-----|----|
|31:0|PLACEHOLDER|  rw  | 0x0 |    |

#### PLACEHOLDER field



### INDIRECT_FIFO_STATUS_4 register

- Absolute Address: 0x160
- Base Offset: 0x60
- Size: 0x4

|Bits| Identifier|Access|Reset|Name|
|----|-----------|------|-----|----|
|31:0|PLACEHOLDER|  rw  | 0x0 |    |

#### PLACEHOLDER field



### INDIRECT_FIFO_STATUS_5 register

- Absolute Address: 0x164
- Base Offset: 0x64
- Size: 0x4

|Bits| Identifier|Access|Reset|Name|
|----|-----------|------|-----|----|
|31:0|PLACEHOLDER|  rw  | 0x0 |    |

#### PLACEHOLDER field



### INDIRECT_FIFO_DATA register

- Absolute Address: 0x168
- Base Offset: 0x68
- Size: 0x4

|Bits| Identifier|Access|Reset|Name|
|----|-----------|------|-----|----|
|31:0|PLACEHOLDER|  rw  | 0x0 |    |

#### PLACEHOLDER field



## TargetTransactionInterfaceRegisters register file

- Absolute Address: 0x180
- Base Offset: 0x80
- Size: 0x30

|Offset|         Identifier         |            Name            |
|------|----------------------------|----------------------------|
| 0x00 |        EXTCAP_HEADER       |              —             |
| 0x04 |         TTI_CONTROL        |         TTI Control        |
| 0x08 |         TTI_STATUS         |         TTI Status         |
| 0x0C |    TTI_INTERRUPT_STATUS    |    TTI Interrupt Status    |
| 0x10 |    TTI_INTERRUPT_ENABLE    |    TTI Interrupt Enable    |
| 0x14 |     TTI_INTERRUPT_FORCE    |     TTI Interrupt Force    |
| 0x18 |TTI_RX_DESCRIPTOR_QUEUE_PORT|TTI RX Descriptor Queue Port|
| 0x1C |      TTI_RX_DATA_PORT      |      TTI RX Data Port      |
| 0x20 |TTI_TX_DESCRIPTOR_QUEUE_PORT|TTI TX Descriptor Queue Port|
| 0x24 |      TTI_TX_DATA_PORT      |      TTI TX Data Port      |
| 0x28 |       TTI_QUEUE_SIZE       |       TTI Queue Size       |
| 0x2C | TTI_QUEUE_THRESHOLD_CONTROL| TTI Queue Threshold Control|

### EXTCAP_HEADER register

- Absolute Address: 0x180
- Base Offset: 0x0
- Size: 0x4

|Bits|Identifier|Access|Reset|   Name   |
|----|----------|------|-----|----------|
| 7:0|  CAP_ID  |   r  | 0x0 |  CAP_ID  |
|23:8|CAP_LENGTH|   r  | 0x0 |CAP_LENGTH|

#### CAP_ID field

<p>Extended Capability ID</p>

#### CAP_LENGTH field

<p>Capability Structure Length in DWORDs</p>

### TTI_CONTROL register

- Absolute Address: 0x184
- Base Offset: 0x4
- Size: 0x4

<p>Control Register</p>

|Bits| Identifier|Access|Reset|Name|
|----|-----------|------|-----|----|
|31:0|PLACEHOLDER|  rw  | 0x0 |    |

#### PLACEHOLDER field



### TTI_STATUS register

- Absolute Address: 0x188
- Base Offset: 0x8
- Size: 0x4

<p>Status Register</p>

|Bits| Identifier|Access|Reset|Name|
|----|-----------|------|-----|----|
|31:0|PLACEHOLDER|  rw  | 0x0 |    |

#### PLACEHOLDER field



### TTI_INTERRUPT_STATUS register

- Absolute Address: 0x18C
- Base Offset: 0xC
- Size: 0x4

<p>Interrupt Status</p>

|Bits| Identifier|Access|Reset|Name|
|----|-----------|------|-----|----|
|31:0|PLACEHOLDER|  rw  | 0x0 |    |

#### PLACEHOLDER field



### TTI_INTERRUPT_ENABLE register

- Absolute Address: 0x190
- Base Offset: 0x10
- Size: 0x4

<p>Interrupt Enable</p>

|Bits| Identifier|Access|Reset|Name|
|----|-----------|------|-----|----|
|31:0|PLACEHOLDER|  rw  | 0x0 |    |

#### PLACEHOLDER field



### TTI_INTERRUPT_FORCE register

- Absolute Address: 0x194
- Base Offset: 0x14
- Size: 0x4

<p>Interrupt Force</p>

|Bits| Identifier|Access|Reset|Name|
|----|-----------|------|-----|----|
|31:0|PLACEHOLDER|  rw  | 0x0 |    |

#### PLACEHOLDER field



### TTI_RX_DESCRIPTOR_QUEUE_PORT register

- Absolute Address: 0x198
- Base Offset: 0x18
- Size: 0x4

<p>RX Descriptor Queue Port</p>

|Bits|    Identifier   |Access|Reset|       Name      |
|----|-----------------|------|-----|-----------------|
|31:0|TTI_RX_DESCRIPTOR|  rw  | 0x0 |TTI_RX_DESCRIPTOR|

#### TTI_RX_DESCRIPTOR field

<p>RX Data</p>

### TTI_RX_DATA_PORT register

- Absolute Address: 0x19C
- Base Offset: 0x1C
- Size: 0x4

<p>RX Data Port</p>

|Bits| Identifier|Access|Reset|    Name   |
|----|-----------|------|-----|-----------|
|31:0|TTI_RX_DATA|  rw  | 0x0 |TTI_RX_DATA|

#### TTI_RX_DATA field

<p>RX Data</p>

### TTI_TX_DESCRIPTOR_QUEUE_PORT register

- Absolute Address: 0x1A0
- Base Offset: 0x20
- Size: 0x4

<p>TX Descriptor Queue Port</p>

|Bits|    Identifier   |Access|Reset|       Name      |
|----|-----------------|------|-----|-----------------|
|31:0|TTI_TX_DESCRIPTOR|  rw  | 0x0 |TTI_TX_DESCRIPTOR|

#### TTI_TX_DESCRIPTOR field

<p>TX Data</p>

### TTI_TX_DATA_PORT register

- Absolute Address: 0x1A4
- Base Offset: 0x24
- Size: 0x4

<p>TX Data Port</p>

|Bits| Identifier|Access|Reset|    Name   |
|----|-----------|------|-----|-----------|
|31:0|TTI_TX_DATA|  rw  | 0x0 |TTI_TX_DATA|

#### TTI_TX_DATA field

<p>TX Data</p>

### TTI_QUEUE_SIZE register

- Absolute Address: 0x1A8
- Base Offset: 0x28
- Size: 0x4

<p>Queue Size</p>

| Bits|          Identifier         |Access|Reset|             Name            |
|-----|-----------------------------|------|-----|-----------------------------|
| 7:0 |TTI_RX_DESCRIPTOR_BUFFER_SIZE|   r  | 0x7 |TTI_RX_DESCRIPTOR_BUFFER_SIZE|
| 15:8|TTI_TX_DESCRIPTOR_BUFFER_SIZE|   r  | 0x7 |TTI_TX_DESCRIPTOR_BUFFER_SIZE|
|23:16|   TTI_RX_DATA_BUFFER_SIZE   |   r  | 0x7 |   TTI_RX_DATA_BUFFER_SIZE   |
|31:24|   TTI_TX_DATA_BUFFER_SIZE   |   r  | 0x7 |   TTI_TX_DATA_BUFFER_SIZE   |

#### TTI_RX_DESCRIPTOR_BUFFER_SIZE field



#### TTI_TX_DESCRIPTOR_BUFFER_SIZE field



#### TTI_RX_DATA_BUFFER_SIZE field



#### TTI_TX_DATA_BUFFER_SIZE field



### TTI_QUEUE_THRESHOLD_CONTROL register

- Absolute Address: 0x1AC
- Base Offset: 0x2C
- Size: 0x4

<p>Queue Threshold Control</p>

| Bits|      Identifier      |Access|Reset|         Name         |
|-----|----------------------|------|-----|----------------------|
| 7:0 |TTI_RX_DESCRIPTOR_THLD|  rw  | 0x0 |TTI_RX_DESCRIPTOR_THLD|
| 15:8|TTI_TX_DESCRIPTOR_THLD|  rw  | 0x0 |TTI_TX_DESCRIPTOR_THLD|
|23:16|   TTI_RX_DATA_THLD   |  rw  | 0x0 |   TTI_RX_DATA_THLD   |
|31:24|   TTI_TX_DATA_THLD   |  rw  | 0x0 |   TTI_TX_DATA_THLD   |

#### TTI_RX_DESCRIPTOR_THLD field



#### TTI_TX_DESCRIPTOR_THLD field



#### TTI_RX_DATA_THLD field



#### TTI_TX_DATA_THLD field



## SoCManagementInterfaceRegisters register file

- Absolute Address: 0x1B0
- Base Offset: 0xB0
- Size: 0x8

|Offset|  Identifier  |     Name     |
|------|--------------|--------------|
|  0x0 | EXTCAP_HEADER|       —      |
|  0x4 |PLACE_HOLDER_1|PLACE_HOLDER_1|

### EXTCAP_HEADER register

- Absolute Address: 0x1B0
- Base Offset: 0x0
- Size: 0x4

|Bits|Identifier|Access|Reset|   Name   |
|----|----------|------|-----|----------|
| 7:0|  CAP_ID  |   r  | 0x0 |  CAP_ID  |
|23:8|CAP_LENGTH|   r  | 0x0 |CAP_LENGTH|

#### CAP_ID field

<p>Extended Capability ID</p>

#### CAP_LENGTH field

<p>Capability Structure Length in DWORDs</p>

### PLACE_HOLDER_1 register

- Absolute Address: 0x1B4
- Base Offset: 0x4
- Size: 0x4

|Bits| Identifier|Access|Reset|Name|
|----|-----------|------|-----|----|
|31:0|PLACEHOLDER|  rw  | 0x0 |    |

#### PLACEHOLDER field



## ControllerConfigRegisters register file

- Absolute Address: 0x1B8
- Base Offset: 0xB8
- Size: 0x8

|Offset|  Identifier  |     Name     |
|------|--------------|--------------|
|  0x0 | EXTCAP_HEADER|       —      |
|  0x4 |PLACE_HOLDER_1|PLACE_HOLDER_1|

### EXTCAP_HEADER register

- Absolute Address: 0x1B8
- Base Offset: 0x0
- Size: 0x4

|Bits|Identifier|Access|Reset|   Name   |
|----|----------|------|-----|----------|
| 7:0|  CAP_ID  |   r  | 0x0 |  CAP_ID  |
|23:8|CAP_LENGTH|   r  | 0x0 |CAP_LENGTH|

#### CAP_ID field

<p>Extended Capability ID</p>

#### CAP_LENGTH field

<p>Capability Structure Length in DWORDs</p>

### PLACE_HOLDER_1 register

- Absolute Address: 0x1BC
- Base Offset: 0x4
- Size: 0x4

|Bits| Identifier|Access|Reset|Name|
|----|-----------|------|-----|----|
|31:0|PLACEHOLDER|  rw  | 0x0 |    |

#### PLACEHOLDER field



## DAT memory

- Absolute Address: 0x400
- Base Offset: 0x400
- Size: 0x400

|Offset|   Identifier  |Name|
|------|---------------|----|
|  0x0 |DAT_MEMORY[128]|  — |

### DAT_MEMORY register

- Absolute Address: 0x400
- Base Offset: 0x0
- Size: 0x400
- Array Dimensions: [128]
- Array Stride: 0x8
- Total Size: 0x400

| Bits|    Identifier    |Access|Reset|       Name       |
|-----|------------------|------|-----|------------------|
| 6:0 |  STATIC_ADDRESS  |  rw  |  —  |  STATIC_ADDRESS  |
|  12 |    IBI_PAYLOAD   |  rw  |  —  |    IBI_PAYLOAD   |
|  13 |    IBI_REJECT    |  rw  |  —  |    IBI_REJECT    |
|  14 |    CRR_REJECT    |  rw  |  —  |    CRR_REJECT    |
|  15 |        TS        |  rw  |  —  |        TS        |
|23:16|  DYNAMIC_ADDRESS |  rw  |  —  |  DYNAMIC_ADDRESS |
|28:26|      RING_ID     |  rw  |  —  |      RING_ID     |
|30:29|DEV_NACK_RETRY_CNT|  rw  |  —  |DEV_NACK_RETRY_CNT|
|  31 |      DEVICE      |  rw  |  —  |      DEVICE      |
|39:32|   AUTOCMD_MASK   |  rw  |  —  |   AUTOCMD_MASK   |
|47:40|   AUTOCMD_VALUE  |  rw  |  —  |   AUTOCMD_VALUE  |
|50:48|   AUTOCMD_MODE   |  rw  |  —  |   AUTOCMD_MODE   |
|58:51| AUTOCMD_HDR_CODE |  rw  |  —  | AUTOCMD_HDR_CODE |

#### STATIC_ADDRESS field

<p>I3C/I2C static device address</p>

#### IBI_PAYLOAD field

<p>Device's IBI contains data payload</p>

#### IBI_REJECT field

<p>Reject device's request for IBI</p>

#### CRR_REJECT field

<p>Reject device's request for controller change</p>

#### TS field

<p>Enable/disable IBI timestamp</p>

#### DYNAMIC_ADDRESS field

<p>I3C dynamic address</p>

#### RING_ID field

<p>Send IBI read to ring bundle</p>

#### DEV_NACK_RETRY_CNT field

<p>Number of retries before giving up</p>

#### DEVICE field

<p>Device type:
0 - I3C device,
1 - I2C device.</p>

#### AUTOCMD_MASK field

<p>IBI mask</p>

#### AUTOCMD_VALUE field

<p>IBI value that triggers auto command</p>

#### AUTOCMD_MODE field

<p>Auto command mode and speed</p>

#### AUTOCMD_HDR_CODE field

<p>Device auto command in HDR mode</p>

## DCT memory

- Absolute Address: 0x800
- Base Offset: 0x800
- Size: 0x800

|Offset|   Identifier  |Name|
|------|---------------|----|
|  0x0 |DCT_MEMORY[128]|  — |

### DCT_MEMORY register

- Absolute Address: 0x800
- Base Offset: 0x0
- Size: 0x800
- Array Dimensions: [128]
- Array Stride: 0x10
- Total Size: 0x800

| Bits |   Identifier  |Access|Reset|      Name     |
|------|---------------|------|-----|---------------|
| 31:0 |     PID_HI    |   r  |  —  |     PID_HI    |
| 47:32|     PID_LO    |   r  |  —  |     PID_LO    |
| 71:64|      DCR      |   r  |  —  |      DCR      |
| 79:72|      BCR      |   r  |  —  |      BCR      |
|103:96|DYNAMIC_ADDRESS|   r  |  —  |DYNAMIC_ADDRESS|

#### PID_HI field

<p>Device Provisional ID High</p>

#### PID_LO field

<p>Device Provisional ID Low</p>

#### DCR field

<p>Value of the I3C device's Device Characteristics Register</p>

#### BCR field

<p>Value of the I3C device's Bus Characteristics Register</p>

#### DYNAMIC_ADDRESS field

<p>Device I3C Dynamic Address after ENTDAA</p>

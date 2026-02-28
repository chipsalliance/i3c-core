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

The following Broadcast CCCs are recognized but not actively handled (the core ACKs or NACKs as appropriate per the specification):

* ENTAS0-ENTAS3 - Enter Activity State (acknowledged, no behavioral change)
* ENTHDR0-ENTHDR7 - Enter HDR Mode (triggers HDR mode entry; HDR data transfer is not supported)
* ENDXFER - Data Transfer Ending Procedure Control
* SETBUSCON - Set Bus Context
* DEFGRPA / RSTGRPA - Group Address (not supported, NACKed)
* MLANE - Multi-Lane (not supported, NACKed)

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
* GETCAPS (R) - Get Optional Feature Capabilities
  * Without defining byte (Format 1)
  * With defining byte 0x93
* RSTACT (R) - Target Reset Action
  * Direct Write (Format 2) supports defining bytes 0x0, 0x1 and 0x2
  * Direct Read (Format 3) supports defining bytes 0x81, 0x82, and 0x84 and returns 0xFF as recovery timing
* ENDXFER - Data Transfer Ending Procedure Control

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

## CCC Error Handling

The core detects errors during CCC processing:

* **TE1**: CCC command code parity error
* **TE5**: Wrong R/W direction for a Direct CCC (e.g., SET command with Read)
* **Framing Error**: SETDASA/SETNEWDA padding bit error (Bit[0] != 0)

These errors are reported through the `TTI.TARGET_ERR_INTR_STATUS` register
and the `TTI.STATUS.PROTOCOL_ERROR` bit (readable via GETSTATUS CCC).
See {doc}`error_handling` for full details.

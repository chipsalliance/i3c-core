# I3C Common Command Codes (CCC)

The I3C core supports all CCCs required by the I3C Basic spec, please see "Table 16 I3C Common Command Codes" for a full reference.

All CCCs are exercised with Cocotb tests.

## Broadcast CCCs

The following Broadcast CCCs are currently supported by the core (all required Broadcast CCCs as per the errata, and one optional Broadcast CCC):

* ENEC (R) - Enable Events Command
* DISEC (R) - Disable Events Command
* SETMWL (R) - Set Max Write Length
* SETMRL (R) - Set Max Read Length
* SETAASA (O) - Set All Addresses to Static Adresses
* ENTDAA (R) - Enter Dynamic Address Assignment
* RSTDAA (R) - Direct Reset Dynamic Address Assignment - this direct CCC is deprecated, the core NACKs this command as per the spec
* RSTACT (R) - Target Reset Action
  * Broadcast (Format 1) supports defining bytes 0x0, 0x1 and 0x2

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
* GETMRL (R) - Set Max Read Length
* GETPID (C) - Get Provisioned ID
* GETBCR (C) - Get Bus Characteristics Register
* GETDCR (C) - Get Device Characteristics Register
* GETSTATUS (R) - Get Device Status
  * The two-byte format (Format 1)
* GETCAPS (R) - Get Optional Feature Capabilities
  * Without defining byte ( Format 1)
* RSTACT (R) - Target Reset Action
  * Direct Write (Format 2) supports defining bytes 0x0, 0x1 and 0x2
  * Direct Read (Format 3) supports defining bytes 0x81 and 0x82 and returns the 0xFF as recovery timing

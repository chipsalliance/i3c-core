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
* RSTACT (R) - Target Reset Action

## Direct CCCs

The following Direct CCCs are currently supported by the core (all required Direct CCCs, plus several optional/conditional ones):

* ENEC (R) - Enable Events Command
* DISEC (R) - Disable Events Command
* RSTDAA (R) - Direct Reset Dynamic Address Assignment - this direct CCC is deprecated, the core NACKs this command as per the spec
* SETDASA (O) - Set Dynamic Address from Static Address
* SETMWL (R) - Set Max Write Length
* SETMRL (R) - Set Max Read Length
* GETMWL (R) - Get Max Write Length
* GETMRL (R) - Set Max Read Length
* GETPID (C) - Get Provisioned ID
* GETBCR (C) - Get Bus Characteristics Register
* GETDCR (C) - Get Device Characteristics Register
* GETSTATUS (R) - Get Device Status
* RSTACT (R) - Target Reset Action

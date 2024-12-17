# SPDX-License-Identifier: Apache-2.0
from munch import Munch

# I3C Basic, Table 16 Common Command Codes
# Broadcast Commands
CCC = Munch.fromDict(
    {
        "BCAST": {
            # Enable Events Command
            "ENEC": 0x00,
            # Disable Events Command
            "DISEC": 0x01,
            # Enter Activity State 0
            "ENTAS0": 0x02,
            # Enter Activity State 1
            "ENTAS1": 0x03,
            # Enter Activity State 2
            "ENTAS2": 0x04,
            # Enter Activity State 3
            "ENTAS3": 0x05,
            # Reset Dynamic Address Assignment
            "RSTDAA": 0x06,
            # Enter Dynamic Address Assignment
            "ENTDAA": 0x07,
            # Define List of Targets
            "DEFTGTS": 0x08,
            # Set Max Write Length
            "SETMWL": 0x09,
            # Set Max Read Length
            "SETMRL": 0x0A,
            # Enter Test Mode
            "ENTTM": 0x0B,
            # Set Bus Context
            "SETBUSCON": 0x0C,
            # Data Transfer Ending Procedure Control
            "ENDXFER": 0x12,
            # Enter HDR Mode 0
            "ENTHDR0": 0x20,
            # Enter HDR Mode 1
            "ENTHDR1": 0x21,
            # Enter HDR Mode 2
            "ENTHDR2": 0x22,
            # Enter HDR Mode 3
            "ENTHDR3": 0x23,
            # Enter HDR Mode 4
            "ENTHDR4": 0x24,
            # Enter HDR Mode 5
            "ENTHDR5": 0x25,
            # Enter HDR Mode 6
            "ENTHDR6": 0x26,
            # Enter HDR Mode 7
            "ENTHDR7": 0x27,
            # Exchange Timing Information
            "SETXTIME": 0x28,
            # Set All Addresses to Static Addresses
            "SETAASA": 0x29,
            # Target Reset Action
            "RSTACT": 0x2A,
            # Define List of Group Address
            "DEFGRPA": 0x2B,
            # Reset Group Address
            "RSTGRPA": 0x2C,
            # Multi-Lane Data Transfer Control
            "MLANE": 0x2D,
        },
        "DIRECT": {
            # Enable Events Command
            "ENEC": 0x80,
            # Disable Events Command
            "DISEC": 0x81,
            # Enter Activity State 0
            "ENTAS0": 0x82,
            # Enter Activity State 1
            "ENTAS1": 0x83,
            # Enter Activity State 2
            "ENTAS2": 0x84,
            # Enter Activity State 3
            "ENTAS3": 0x85,
            # Direct  Reset Dynamic Address Assignment
            "RSTDAA": 0x86,
            # Set Dynamic Address from Static Address
            "SETDASA": 0x87,
            # Set New Dynamic Address
            "SETNEWDA": 0x88,
            # Set Max Write Length
            "SETMWL": 0x89,
            # Set Max Read Length
            "SETMRL": 0x8A,
            # Get Max Write Length
            "GETMWL": 0x8B,
            # Get Max Read Length
            "GETMRL": 0x8C,
            # Get Provisioned ID
            "GETPID": 0x8D,
            # Get Bus Characteristics Register
            "GETBCR": 0x8E,
            # Get Device Characteristics Register
            "GETDCR": 0x8F,
            # Get Device Status
            "GETSTATUS": 0x90,
            # Get Accept Controller Role
            "GETACCCR": 0x91,
            # Data Transfer Ending Procedure Control
            "ENDXFER": 0x92,
            # Set Bridge Targets
            "SETBRGTGT": 0x93,
            # Get Max Data Speed
            "GETMXDS": 0x94,
            # (formerly GETHDRCAPS) Get Optional Feature Capabilities
            "GETCAPS": 0x95,
            # Set Route
            "SETROUTE": 0x96,
            # Device to Device(s) Tunneling Control
            "D2DXFER": 0x97,
            # Set Exchange Timing Information
            "SETXTIME": 0x98,
            # Get Exchange Timing Information
            "GETXTIME": 0x99,
            # Target Reset Action
            "RSTACT": 0x9A,
            # Set Group Address
            "SETGRPA": 0x9B,
            # Reset Group Address
            "RSTGRPA": 0x9C,
            # Multi-Lane Data Transfer Control
            "MLANE": 0x9D,
        },
    }
)

# RSTACT defining byte values
RSTACT_DEF_BYTE = Munch.fromDict(
    {
        "NO_RESET": 0x00,
        "PERIPHERAL_RESET": 0x01,
        "TARGET_RESET": 0x02,
        "DEBUG_ADAPTER_RESET": 0x03,
        "VIRTUAL_TARGET_DETECT": 0x04,
        "TIME_TO_RESET_PERIPHERAL": 0x81,
        "TIME_TO_RESET_TARGET": 0x82,
        "TIME_TO_RESET_DEBUG_ADAPTER": 0x83,
        "VIRTUAL_TARGET_INDICATION": 0x84,
    }
)

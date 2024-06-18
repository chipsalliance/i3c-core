// SPDX-License-Identifier: Apache-2.0

`ifndef I3C_CCC
`define I3C_CCC

// I3C Basic, Table 16 Common Command Codes
// Broadcast Commands
`define I3C_BCAST_ENEC 8'h00 // Enable Events Command
`define I3C_BCAST_DISEC 8'h01 // Disable Events Command
`define I3C_BCAST_ENTAS0 8'h02 // Enter Activity State 0
`define I3C_BCAST_ENTAS1 8'h03 // Enter Activity State 1
`define I3C_BCAST_ENTAS2 8'h04 // Enter Activity State 2
`define I3C_BCAST_ENTAS3 8'h05 // Enter Activity State 3
`define I3C_BCAST_RSTDAA 8'h06 // Reset Dynamic Address Assignment
`define I3C_BCAST_ENTDAA 8'h07 // Enter Dynamic Address Assignment
`define I3C_BCAST_DEFTGTS 8'h08 // Define List of Targets
`define I3C_BCAST_SETMWL 8'h09 // Set Max Write Length
`define I3C_BCAST_SETMRL 8'h0A // Set Max Read Length
`define I3C_BCAST_ENTTM 8'h0B // Enter Test Mode
`define I3C_BCAST_SETBUSCON 8'h0C // Set Bus Context
`define I3C_BCAST_ENDXFER 8'h12 // Data Transfer Ending Procedure Control
`define I3C_BCAST_ENTHDR0 8'h20 // Enter HDR Mode 0
`define I3C_BCAST_ENTHDR1 8'h21 // Enter HDR Mode 1
`define I3C_BCAST_ENTHDR2 8'h22 // Enter HDR Mode 2
`define I3C_BCAST_ENTHDR3 8'h23 // Enter HDR Mode 3
`define I3C_BCAST_ENTHDR4 8'h24 // Enter HDR Mode 4
`define I3C_BCAST_ENTHDR5 8'h25 // Enter HDR Mode 5
`define I3C_BCAST_ENTHDR6 8'h26 // Enter HDR Mode 6
`define I3C_BCAST_ENTHDR7 8'h27 // Enter HDR Mode 7
`define I3C_BCAST_SETXTIME 8'h28 // Exchange Timing Information
`define I3C_BCAST_SETAASA 8'h29 // Set All Addresses to Static Addresses
`define I3C_BCAST_RSTACT 8'h2A // Target Reset Action
`define I3C_BCAST_DEFGRPA 8'h2B // Define List of Group Address
`define I3C_BCAST_RSTGRPA 8'h2C // Reset Group Address
`define I3C_BCAST_MLANE 8'h2D // Multi-Lane Data Transfer Control
// Direct Commands
`define I3C_DIRECT_ENEC 8'h80 // Enable Events Command
`define I3C_DIRECT_DISEC 8'h81 // Disable Events Command
`define I3C_DIRECT_ENTAS0 8'h82 // Enter Activity State 0
`define I3C_DIRECT_ENTAS1 8'h83 // Enter Activity State 1
`define I3C_DIRECT_ENTAS2 8'h84 // Enter Activity State 2
`define I3C_DIRECT_ENTAS3 8'h85 // Enter Activity State 3
`define I3C_DIRECT_RSTDAA 8'h86 // Direct  Reset Dynamic Address Assignment
`define I3C_DIRECT_SETDASA 8'h87 // Set Dynamic Address from Static Address
`define I3C_DIRECT_SETNEWDA 8'h88 // Set New Dynamic Address
`define I3C_DIRECT_SETMWL 8'h89 // Set Max Write Length
`define I3C_DIRECT_SETMRL 8'h8A // Set Max Read Length
`define I3C_DIRECT_GETMWL 8'h8B // Get Max Write Length
`define I3C_DIRECT_GETMRL 8'h8C // Get Max Read Length
`define I3C_DIRECT_GETPID 8'h8D // Get Provisioned ID
`define I3C_DIRECT_GETBCR 8'h8E // Get Bus Characteristics Register
`define I3C_DIRECT_GETDCR 8'h8F // Get Device Characteristics Register
`define I3C_DIRECT_GETSTATUS 8'h90 // Get Device Status
`define I3C_DIRECT_GETACCCR 8'h91 // Get Accept Controller Role
`define I3C_DIRECT_ENDXFER 8'h92 // Data Transfer Ending Procedure Control
`define I3C_DIRECT_SETBRGTGT 8'h93 // Set Bridge Targets
`define I3C_DIRECT_GETMXDS 8'h94 // Get Max Data Speed
`define I3C_DIRECT_GETCAPS 8'h95 // (formerly GETHDRCAPS) Get Optional Feature Capabilities
`define I3C_DIRECT_SETROUTE 8'h96 // Set Route
`define I3C_DIRECT_D2DXFER 8'h97 // Device to Device(s) Tunneling Control
`define I3C_DIRECT_SETXTIME 8'h98 // Set Exchange Timing Information
`define I3C_DIRECT_GETXTIME 8'h99 // Get Exchange Timing Information
`define I3C_DIRECT_RSTACT 8'h9A // Target Reset Action
`define I3C_DIRECT_SETGRPA 8'h9B // Set Group Address
`define I3C_DIRECT_RSTGRPA 8'h9C // Reset Group Address
`define I3C_DIRECT_MLANE 8'h9D // Multi-Lane Data Transfer Control

`endif  // I3C_CCC

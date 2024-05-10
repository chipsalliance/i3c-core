package i3c_agent_pkg;
  // dep packages
  import uvm_pkg::*;

  // macro includes
  `include "uvm_macros.svh"
  `include "dv_macros.svh"

  typedef enum bit {
    Host,
    Device
  } if_mode_e;

  typedef enum bit {
    BusOpWrite = 1'b0,
    BusOpRead  = 1'b1
  } bus_op_e;

  // Bus/Transaction types for the agent driver
  typedef enum logic [4:0] {
    None,
    DevAck, DevNack,
    WrData,
    BroadcastCCC,
    DirectCCCAddr,
    WrDataPP,


    HostRStart, HostStop,
    HostNAck, HostAck,
    RdData,     // I2C read transaction
    RdDataPP,   // I3C read transcation

    HostDevStart,
    HostDevAck, HostDevNAck,
    HostDevAddr
  } i3c_drv_type_e;

  // Driver phase
  typedef enum int {
    DrvIdle,
    DrvStart,
    DrvAddr,
    DrvAddrPushPull,
    DrvCCC,
    DrvCCCDef,
    DrvCCCSubCmd,
    DrvWr,
    DrvWrPushPull,
    DrvRd,
    DrvRdPushPull,
    DrvStop
  } i3c_drv_phase_e;

  typedef enum logic[7:0] {
    // Broadcast CCCs
    ENEC    = 8'h00,
    DISEC   = 8'h01,
    RSTDAA  = 8'h06,
    ENTDAA  = 8'h07,
    DEFTGTS = 8'h08,
    SETMWL  = 8'h09,
    SETMRL  = 8'h0A,
    RSTACT  = 8'h2A,
    // Direct CCCs
    DIR_ENEC   = 8'h80,
    DIR_DISEC  = 8'h81,
    SETDASA    = 8'h87,
    SETNEWDA   = 8'h88,
    DIR_SETMWL = 8'h89,
    DIR_SETMRL = 8'h8A,
    GETMWL     = 8'h8B,
    GETMRL     = 8'h8C,
    GETPID     = 8'h8D,
    GETBCR     = 8'h8E,
    GETDCR     = 8'h8F,
    GETSTATUS  = 8'h90,
    GETACCCR   = 8'h91,
    GETMXDS    = 8'h94,
    GETCAPS    = 8'h95,
    DIR_RSTACT = 8'h9A
  } i3c_ccc_e;

  typedef uvm_enum_wrapper#(i3c_ccc_e) i3c_ccc_wrapper;

  bit [1:0] defining_byte_for_CCC[logic[7:0]] = '{
    // {optional defining byte, required defining byte}
    // Broadcast CCCs
    8'h00 : 2'b00,
    8'h01 : 2'b00,
    8'h06 : 2'b00,
    8'h07 : 2'b00,
    8'h08 : 2'b00,
    8'h09 : 2'b00,
    8'h0A : 2'b00,
    8'h2A : 2'b01,

    // Direct CCCs
    8'h80 : 2'b00,
    8'h81 : 2'b00,
    8'h87 : 2'b00,
    8'h88 : 2'b00,
    8'h89 : 2'b00,
    8'h8A : 2'b00,
    8'h8B : 2'b00,
    8'h8C : 2'b00,
    8'h8D : 2'b00,
    8'h8E : 2'b00,
    8'h8F : 2'b00,
    8'h90 : 2'b10,
    8'h91 : 2'b00,
    8'h94 : 2'b10,
    8'h95 : 2'b10,
    8'h9A : 2'b01
  };

  bit [1:0] data_for_CCC[logic[7:0]] = '{
    // {optional data, required data}
    // Broadcast CCCs
    8'h00 : 2'b01,
    8'h01 : 2'b01,
    8'h06 : 2'b00,
    8'h07 : 2'b00,
    8'h08 : 2'b01,
    8'h09 : 2'b01,
    8'h0A : 2'b01,
    8'h2A : 2'b00,

    // Direct CCCs
    8'h80 : 2'b01,
    8'h81 : 2'b01,
    8'h87 : 2'b01,
    8'h88 : 2'b01,
    8'h89 : 2'b01,
    8'h8A : 2'b01,
    8'h8B : 2'b01,
    8'h8C : 2'b01,
    8'h8D : 2'b01,
    8'h8E : 2'b01,
    8'h8F : 2'b01,
    8'h90 : 2'b01,
    8'h91 : 2'b01,
    8'h94 : 2'b01,
    8'h95 : 2'b01,
    8'h9A : 2'b10
  };

  bit [1:0] subcmd_byte_for_CCC[logic[7:0]] = '{
    // {optional sub-command, required sub-command}
    // Broadcast CCCs
    8'h00 : 2'b00,
    8'h01 : 2'b00,
    8'h06 : 2'b00,
    8'h07 : 2'b00,
    8'h08 : 2'b00,
    8'h09 : 2'b00,
    8'h0A : 2'b00,
    8'h2A : 2'b00,

    // Direct CCCs
    8'h80 : 2'b00,
    8'h81 : 2'b00,
    8'h87 : 2'b00,
    8'h88 : 2'b00,
    8'h89 : 2'b00,
    8'h8A : 2'b00,
    8'h8B : 2'b00,
    8'h8C : 2'b00,
    8'h8D : 2'b00,
    8'h8E : 2'b00,
    8'h8F : 2'b00,
    8'h90 : 2'b00,
    8'h91 : 2'b00,
    8'h94 : 2'b00,
    8'h95 : 2'b00,
    8'h9A : 2'b00
  };

  bit data_direction_for_CCC[logic[7:0]] = '{
    // 0 - host to device
    // 1 - device to host
    // Broadcast CCCs
    8'h00 : 1'b0,
    8'h01 : 1'b0,
    8'h06 : 1'b0,
    8'h07 : 1'b0,
    8'h08 : 1'b0,
    8'h09 : 1'b0,
    8'h0A : 1'b0,
    8'h2A : 1'b0,

    // Direct CCCs
    8'h80 : 1'b0,
    8'h81 : 1'b0,
    8'h87 : 1'b0,
    8'h88 : 1'b0,
    8'h89 : 1'b0,
    8'h8A : 1'b0,
    8'h8B : 1'b1,
    8'h8C : 1'b1,
    8'h8D : 1'b1,
    8'h8E : 1'b1,
    8'h8F : 1'b1,
    8'h90 : 1'b1,
    8'h91 : 1'b1,
    8'h94 : 1'b1,
    8'h95 : 1'b1,
    8'h9A : 1'b0
  };

  typedef struct {
    int tHoldStop   = 1_300; // 1.3 us
    int tHoldStart  = 600;
    int tSetupStart = 600;
    int tSetupBit   = 100;
    int tHoldBit    = 0;
    int tClockPulse = 600;
    int tClockLow   = 1_300;
    int tSetupStop  = 1_300;
  } i2c_timing_t;

  i2c_timing_t i2c_400 = '{
    tHoldStop   : 1_300, // 1.3 us
    tHoldStart  : 600,
    tSetupStart : 600,
    tSetupBit   : 100,
    tHoldBit    : 0,
    tClockPulse : 600,
    tClockLow   : 1_300,
    tSetupStop  : 1_300
  };

  i2c_timing_t i2c_1000 = '{
    tHoldStop   : 500,
    tHoldStart  : 260,
    tSetupStart : 260,
    tSetupBit   : 50,
    tHoldBit    : 0,
    tClockPulse : 260,
    tClockLow   : 500,
    tSetupStop  : 500
  };

  typedef struct {
    int tHoldStop   = 1_300; // 1.3 us
    int tHoldStart  = 39;
    int tSetupStart = 20;
    int tHoldRStart = 20;
    int tSetupBit   = 3;
    int tHoldBit    = 0;
    int tClockPulse = 24;
    int tClockLowOD = 200;
    int tClockLowPP = 32;
    int tSetupStop  = 20;
  } i3c_timing_t;

  typedef struct {
    i2c_timing_t i2c_tc;
    i3c_timing_t i3c_tc;
  } bus_timing_t;

  typedef struct {
    bit        IBI_enabled;
    bit        controller_request_enable;
    bit        hot_join_request_enable;

    bit  [6:0] static_addr;
    bit        static_addr_valid;
    bit  [6:0] dynamic_addr;
    bit        dynamic_addr_valid;

    bit  [7:0] bcr;
    bit  [7:0] dcr;
    bit [47:0] pid;
    bit [15:0] device_read_limit;
    bit [15:0] max_read_length;
    bit [15:0] device_write_limit;
    bit [15:0] max_write_length;
    bit [15:0] status;
  } I3C_device;

  // forward declare classes to allow typedefs below
  typedef class i3c_item;
  typedef class i3c_agent_cfg;

  // package sources
  `include "i3c_item.sv"
  `include "i3c_agent_cfg.sv"
  `include "i3c_monitor.sv"
//  `include "i3c_driver.sv"
//  `include "i3c_sequencer.sv"
  `include "i3c_agent.sv"
//  `include "seq_lib/i2c_seq_list.sv"

endpackage: i3c_agent_pkg

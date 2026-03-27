// SPDX-License-Identifier: Apache-2.0

// Description: Decodes Command Descriptor and forwards byte to be sent on the
// I3C / I2C bus to the
// i3c_controller_fsm and i2c_controller_fsm
// Limitations: currently only I3C Write Immediate and I3C Write Regular with
// direct addresses are supported. 
// TODO: Add support for data byte ordering modes (HC_CONTROL.DATA_BYTE_ORDER_MODE)

module flow_active
  import controller_pkg::*;
  import i3c_pkg::*;
#(
    parameter int unsigned HciRespDataWidth = 32,
    parameter int unsigned HciCmdDataWidth  = 64,
    parameter int unsigned HciRxDataWidth   = 32,
    parameter int unsigned HciTxDataWidth   = 32,
    parameter int unsigned HciIbiDataWidth  = 32,

    parameter int unsigned HciRespThldWidth = 8,
    parameter int unsigned HciCmdThldWidth  = 8,
    parameter int unsigned HciRxThldWidth   = 3,
    parameter int unsigned HciTxThldWidth   = 3,
    parameter int unsigned HciIbiThldWidth  = 8
) (
    input logic clk_i,
    input logic rst_ni,

    // HCI queues
    // Command FIFO
    input logic cmd_queue_full_i,
    input logic [HciCmdThldWidth-1:0] cmd_queue_ready_thld_i,
    input logic cmd_queue_ready_thld_trig_i,
    input logic cmd_queue_empty_i,
    input logic cmd_queue_rvalid_i,
    output logic cmd_queue_rready_o,
    input logic [HciCmdDataWidth-1:0] cmd_queue_rdata_i,
    // RX FIFO
    input logic rx_queue_full_i,
    input logic [HciRxThldWidth-1:0] rx_queue_start_thld_i,
    input logic rx_queue_start_thld_trig_i,
    input logic [HciRxThldWidth-1:0] rx_queue_ready_thld_i,
    input logic rx_queue_ready_thld_trig_i,
    input logic rx_queue_empty_i,
    output logic rx_queue_wvalid_o,
    input logic rx_queue_wready_i,
    output logic [HciRxDataWidth-1:0] rx_queue_wdata_o,
    // TX FIFO
    input logic tx_queue_full_i,
    input logic [HciTxThldWidth-1:0] tx_queue_start_thld_i,
    input logic tx_queue_start_thld_trig_i,
    input logic [HciTxThldWidth-1:0] tx_queue_ready_thld_i,
    input logic tx_queue_ready_thld_trig_i,
    input logic tx_queue_empty_i,
    input logic tx_queue_rvalid_i,
    output logic tx_queue_rready_o,
    input logic [HciTxDataWidth-1:0] tx_queue_rdata_i,
    // Response FIFO
    input logic resp_queue_full_i,
    input logic [HciRespThldWidth-1:0] resp_queue_ready_thld_i,
    input logic resp_queue_ready_thld_trig_i,
    input logic resp_queue_empty_i,
    output logic resp_queue_wvalid_o,
    input logic resp_queue_wready_i,
    output logic [HciRespDataWidth-1:0] resp_queue_wdata_o,

    // In-band Interrupt queue
    input logic ibi_queue_full_i,
    input logic [HciIbiThldWidth-1:0] ibi_queue_ready_thld_i,
    input logic ibi_queue_ready_thld_trig_i,
    input logic ibi_queue_empty_i,
    output logic ibi_queue_wvalid_o,
    input logic ibi_queue_wready_i,
    output logic [HciIbiDataWidth-1:0] ibi_queue_wdata_o,

    // DAT <-> Controller interface
    output logic                          dat_read_valid_hw_o,
    output logic [$clog2(`DAT_DEPTH)-1:0] dat_index_hw_o,
    input  logic [                  63:0] dat_rdata_hw_i,

    // DCT <-> Controller interface
    output logic                          dct_write_valid_hw_o,
    output logic                          dct_read_valid_hw_o,
    output logic [$clog2(`DCT_DEPTH)-1:0] dct_index_hw_o,
    output logic [                 127:0] dct_wdata_hw_o,
    input  logic [                 127:0] dct_rdata_hw_i,

    // I2C Controller interface
    output logic host_enable_o,    // enable host functionality
    input  logic phy_sel_od_pp_i,
    output logic phy_sel_od_pp_o,

    output logic                         fmt_fifo_rvalid_o,
    output logic [I2CFifoDepthWidth-1:0] fmt_fifo_depth_o,
    input  logic                         fmt_fifo_rready_i,
    input  logic                         fmt_fifo_rdone_i,
    output logic [                  7:0] fmt_byte_o,
    output logic                         fmt_bit_o,                 // T bit
    output logic                         fmt_flag_start_before_o,
    output logic                         fmt_flag_restart_after_o,
    output logic                         fmt_flag_stop_after_o,
    output logic                         fmt_flag_read_continue_o,
    input  logic                         fmt_receive_nack_i,
    // fmt RX signals
    input  logic [                  7:0] fmt_byte_i,
    input  logic                         fmt_bit_i,
    output logic                         fmt_flag_read_bytes_o,
    input  logic                         fmt_flag_read_valid_i,

    output logic fmt_flag_nak_ok_o,
    output logic unhandled_unexp_nak_o,
    output logic unhandled_nak_timeout_o,

    // RX FIFO queue from I2C Controller
    input logic                   rx_fifo_wvalid_i,
    input logic [RxFifoWidth-1:0] rx_fifo_wdata_i,

    // I3C FSM control & status
    input  logic i3c_fsm_en_i,
    output logic i3c_fsm_idle_o,

    // Errors and Interrupts
    output i3c_err_t err,
    output i3c_irq_t irq
);

  // Helper function to check if current CCC has payload or not
  function automatic logic has_payload(logic [7:0] ccc);
    if((ccc == `I3C_DIRECT_ENEC) || (ccc == `I3C_DIRECT_DISEC) || (ccc == `I3C_BCAST_ENEC) || (ccc == `I3C_BCAST_DISEC)) begin
      // TODO: add more CCCs with payload
      return 1'b1;
    end else begin
      return 1'b0;
    end
  endfunction

  assign dct_write_valid_hw_o = '0;
  assign ibi_queue_wvalid_o = '0;
  assign err = '0;
  assign irq = '0;
  assign phy_sel_od_pp_o = phy_sel_od_pp_i;  //  TODO: assign properly

  typedef enum logic [4:0] {
    Idle = 5'd0,
    WaitForCmd = 5'd1,
    FetchAddr = 5'd2,
    I2CWriteImmediateDAT = 5'd3,
    I3CWriteImmediateDAT = 5'd4,
    I2CWriteImmediateDirect = 5'd5,
    I3CWriteImmediateDirect = 5'd6,
    I3CWriteRegularDirect = 5'd7,
    I3CReadDirect = 5'd8,
    InitI2CWrite = 5'd9,
    InitI2CRead = 5'd10,
    StallWrite = 5'd11,
    StallRead = 5'd12,
    DirectCCC = 5'd13,
    BroadcastCCC = 5'd14,
    WriteResp = 5'd15
  } flow_fsm_state_e;

  // TODO: Set BytesBeforeImmData from the HC_CONTROL.IBA_INCLUDE
  localparam int unsigned BytesBeforeImmData = 0;  // 1 if IBA is disabled, otherwise 2

  flow_fsm_state_e state, state_next;

  immediate_data_trans_dat_desc_t immediate_dat_cmd_desc;
  immediate_data_trans_direct_desc_t immediate_direct_cmd_desc;
  regular_trans_dat_desc_t regular_dat_cmd_desc;
  regular_trans_direct_desc_t regular_direct_cmd_desc;
  combo_trans_desc_t combo_cmd_desc;
  addr_assign_desc_t addr_cmd_desc;
  logic [63:0] cmd_desc;

  // Values extracted from the Command Descriptor
  cmd_transfer_dir_e cmd_dir;
  logic cmd_is_ccc;
  logic cmd_is_broadcast_ccc;
  i3c_cmd_attr_e cmd_attr;
  logic [4:0] dev_index;
  logic [2:0] cmd_tid;
  logic [15:0] data_length;
  logic imm_use_def_byte;
  logic is_direct_transfer;
  logic is_regular_transfer;

  // Generic incremental counter
  logic [31:0] transfer_cnt_q, transfer_cnt_d;
  logic transfer_cnt_en;
  logic transfer_cnt_clr;

  logic [HciCmdDataWidth-1:0] cmd_queue_rdata;
  logic cmd_queue_rvalid;

  // DAT table
  dat_entry_t dat_rdata;
  logic dat_captured, dat_read_valid_d;

  // DCT table
  // FUTUREFIX: Use DCT typedef struct
  logic [127:0] dct_rdata;
  logic dct_captured, dct_read_valid_d;

  // Values extracted from the DAT entry
  logic i2c_cmd;

  // TX Queue
  logic [HciTxDataWidth-1:0] tx_dword;
  logic [(HciTxDataWidth>>3)-1:0][7:0] tx_dword_array;
  logic [$clog2(HciTxDataWidth>>3)-1 : 0] byte_select;
  assign byte_select = ((transfer_cnt_q - 1) % (HciTxDataWidth >> 3));
  assign tx_dword_array = tx_dword;
  logic pop_tx_fifo;

  // RX Queue
  logic [HciRxDataWidth-1:0] rx_dword_d, rx_dword_q;
  logic [(HciRxDataWidth>>3)-1:0][7:0] rx_dword_array;
  assign rx_dword_d = rx_dword_array;

  // Response Queue
  i3c_response_desc_t resp_desc;
  i3c_resp_err_status_e resp_err_status_d, resp_err_status_q;
  logic [15:0] resp_data_length_d, resp_data_length_q;

  // CCC signals
  logic ccc_done;
  logic ccc_has_payload;
  logic [7:0] cmd_ccc, prev_ccc_d, prev_ccc_q;
  assign cmd_ccc = cmd_desc[14:7];
  assign ccc_has_payload = has_payload(cmd_ccc);

  // TODO: Set appropriately
  always_comb begin
    fmt_flag_nak_ok_o = 1'b0;
    unhandled_unexp_nak_o = 1'b0;
    unhandled_nak_timeout_o = 1'b0;
  end

  // Assign generic Command Descriptor to command specific structures
  assign immediate_dat_cmd_desc = cmd_desc;
  assign immediate_direct_cmd_desc = cmd_desc;
  assign regular_direct_cmd_desc = cmd_desc;
  assign regular_dat_cmd_desc = cmd_desc;
  assign combo_cmd_desc = cmd_desc;
  assign addr_cmd_desc = cmd_desc;

  // Initialize descriptor's reserved field
  assign resp_desc.__rsvd23_16 = '0;

  // Assign generic command fields to generic signals
  assign dev_index = cmd_desc[20:16];
  assign cmd_dir = cmd_desc[29] ? Read : Write;
  assign cmd_is_ccc = cmd_desc[15];
  assign cmd_is_broadcast_ccc = ~cmd_desc[14]; // the MSB of the CCC indicates if it's direct or a broadcast see Table 16 I3C Basic Spec
  assign cmd_attr = i3c_cmd_attr_e'(cmd_desc[2:0]);
  assign is_direct_transfer = ((cmd_attr == ImmediateDataTransferDirect) || (cmd_attr == RegularTransferDirect) || (cmd_attr == ComboTransferDirect)) && ((cmd_attr != InternalControl) && (cmd_attr != AddressAssignment));
  assign is_regular_transfer = cmd_attr == RegularTransferDirect || RegularTransferDAT;
  assign cmd_tid = is_direct_transfer ? {1'b0, cmd_desc[5:3]} : cmd_desc[6:3];
  // Assign if target is an I2C device
  assign i2c_cmd = is_direct_transfer ? immediate_direct_cmd_desc.i2c : dat_rdata.device; // TODO: adapt for regular transfer

  // Assign TX fifo signals
  assign pop_tx_fifo = tx_queue_rready_o;

  // Assign RX Queue signals
  assign rx_queue_wdata_o = rx_dword_d; // when transaction is finished early we update rx_word_d at the same time as setting rx_queue_wvalid_o

  // Assign constants
  // FUTUREFIX: Add control logic to constant signals
  assign host_enable_o = 1'b1;
  assign fmt_fifo_depth_o = 8'd1;

  // Capture data from DAT/DCT tables
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (~rst_ni) begin
      dat_read_valid_d <= 1'b0;
      dct_read_valid_d <= 1'b0;
      dat_rdata <= '0;
      dct_rdata <= '0;
      dat_captured <= 1'b0;
      dct_captured <= 1'b0;
    end else begin
      dat_read_valid_d <= dat_read_valid_hw_o;
      dct_read_valid_d <= dct_read_valid_hw_o;
      if (dat_read_valid_d) begin
        dat_rdata <= dat_rdata_hw_i;
      end else begin
        dat_rdata <= dat_rdata;
      end
      if (dct_read_valid_d) begin
        dct_rdata <= dct_rdata_hw_i;
        dct_captured <= 1'b1;
      end else begin
        dct_rdata <= dct_rdata;
        dct_captured <= 1'b0;
      end
    end
  end

  // Capture command FIFO control signals
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (~rst_ni) begin
      cmd_queue_rvalid <= '0;
      cmd_queue_rdata  <= '0;
    end else begin
      cmd_queue_rvalid <= cmd_queue_rvalid_i;
      cmd_queue_rdata  <= cmd_queue_rdata_i;
    end
  end

  // Assign internals based on the command attribute
  always_comb begin
    unique case (cmd_attr)
      ImmediateDataTransferDAT: begin
        // If DTT is 5-7, it is a CCC with a defining byte. In such case substract 5 from DTT to
        // get an actual transfer data length.
        // Values:
        // - 0: No payload
        // - 1–4: N bytes are valid
        // - 5: Defining Byte + 0
        // - 6: Defining Byte + 1
        // - 7: Defining Byte + 2
        imm_use_def_byte = immediate_dat_cmd_desc.dtt > 4 ? 1'b1 : 1'b0;
        data_length = imm_use_def_byte ? 16'(immediate_dat_cmd_desc.dtt - 5) : 16'(immediate_dat_cmd_desc.dtt);
      end
      ImmediateDataTransferDirect: begin
        // If DTT is 5-7, it is a CCC with a defining byte. In such case substract 5 from DTT to
        // get an actual transfer data length.
        // Values:
        // - 0: No payload
        // - 1–4: N bytes are valid
        // - 5: Defining Byte + 0
        // - 6: Defining Byte + 1
        // - 7: Defining Byte + 2
        imm_use_def_byte = immediate_direct_cmd_desc.dtt > 4 ? 1'b1 : 1'b0;
        data_length = imm_use_def_byte ? 16'(immediate_direct_cmd_desc.dtt - 5) : 16'(immediate_direct_cmd_desc.dtt);
      end
      AddressAssignment: begin
        // FUTUREFIX
        imm_use_def_byte = '0;
        data_length = '0;
      end
      ComboTransferDAT: begin
        imm_use_def_byte = '0;
        data_length = combo_cmd_desc.data_length;
      end
      InternalControl: begin
        // FUTUREFIX
        imm_use_def_byte = '0;
        data_length = '0;
      end
      RegularTransferDAT: begin
        imm_use_def_byte = '0;
        data_length = regular_dat_cmd_desc.data_length;
      end
      RegularTransferDirect: begin
        imm_use_def_byte = '0;
        data_length = regular_direct_cmd_desc.data_length;
      end
      default: begin
        imm_use_def_byte = '0;
        data_length = '0;
      end
    endcase
  end

  // Control internal transfer counter
  // FUTUREFIX: Consider using decremental counter with different load values
  // See i2c_controller_fsm.sv for reference
  always_comb begin
    transfer_cnt_d = transfer_cnt_q;
    if (transfer_cnt_clr) begin
      transfer_cnt_d = '0;
    end else if (transfer_cnt_en) begin
      transfer_cnt_d = transfer_cnt_q + 1;

    end else if ((transfer_cnt_q == '0) && cmd_is_ccc && ~cmd_is_broadcast_ccc && (prev_ccc_q == cmd_ccc)) begin
      transfer_cnt_d = 2; // transfer_cnt_q = 0: 7'h7E byte, transfer_cnt_q = 1: CCC byte according to Figure 32 I3C Basic Spec we are allowed to skip these two bytes when the CCC stays the same.
    end
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (~rst_ni) begin
      transfer_cnt_q <= '0;
    end else begin
      transfer_cnt_q <= transfer_cnt_d;
    end
  end

  // Fetch Command Descriptor from the Command Queue
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (~rst_ni) begin
      cmd_desc <= '0;
    end else begin
      if (cmd_queue_rvalid_i & cmd_queue_rready_o) begin
        cmd_desc <= cmd_queue_rdata_i;
      end else begin
        cmd_desc <= cmd_desc;
      end
    end
  end

  // Capture data from TX Queue
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (~rst_ni) begin
      tx_dword <= '0;
    end else begin
      if (pop_tx_fifo) begin
        tx_dword <= tx_queue_rdata_i;
      end else begin
        tx_dword <= tx_dword;
      end
    end
  end

  // Catch every error detected during the Controller operation
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (~rst_ni) begin
      // NOTE: We use the AbortedWithCRC error status as a default. This means
      // that internal hardware bugs can mistakenly produce the AbortedWithCRC error
      // status.
      resp_err_status_q <= AbortedWithCRC;
      rx_dword_q <= '0;
    end else begin
      resp_err_status_q <= resp_err_status_d;
      rx_dword_q <= rx_dword_d;
    end
  end

  // Catch every data_length update during the Controller operation
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (~rst_ni) begin
      resp_data_length_q <= '0;
    end else begin
      resp_data_length_q <= resp_data_length_d;
    end
  end

  // Store previous CCC for direct CCC frame (Table 31 I3C Basic Spec)
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (~rst_ni) begin
      prev_ccc_q <= 8'hFF;  // 0xFF is not used as a CCC, that's why it's a reset state
    end else begin
      prev_ccc_q <= prev_ccc_d;
    end
  end
  assign prev_ccc_d = ccc_done ? cmd_ccc : prev_ccc_q;

  // Combinational state output update
  always_comb begin
    i3c_fsm_idle_o = 1'b0;
    transfer_cnt_en = 1'b0;
    cmd_queue_rready_o = 1'b0;
    dat_read_valid_hw_o = 1'b0;
    dct_read_valid_hw_o = 1'b0;
    dat_index_hw_o = '0;
    tx_queue_rready_o = 1'b0;
    rx_queue_wvalid_o = 1'b0;
    transfer_cnt_clr = 1'b1;
    fmt_fifo_rvalid_o = 1'b0;
    fmt_flag_start_before_o = 1'b0;
    fmt_flag_restart_after_o = 1'b0;
    resp_queue_wvalid_o = 1'b0;
    fmt_flag_stop_after_o = 1'b0;
    fmt_flag_read_bytes_o = 1'b0;
    fmt_flag_read_continue_o = 1'b0;
    fmt_byte_o = '0;
    fmt_bit_o = '0;
    dct_wdata_hw_o = '0;
    ibi_queue_wdata_o = '0;
    dct_index_hw_o = '0;
    resp_data_length_d = '0;
    resp_queue_wdata_o = '0;
    resp_err_status_d = resp_err_status_q;
    resp_desc.err_status = i3c_resp_err_status_e'(0);
    resp_desc.tid = '0;
    resp_desc.data_length = '0;
    rx_dword_array = rx_dword_q;
    ccc_done = 1'b0;
    unique case (state)
      // Idle: Wait for command appearance in the Command Queue
      Idle: begin
        i3c_fsm_idle_o = 1'b1;
      end
      // WaitForCmd: Fetch Command Descriptor
      WaitForCmd: begin
        cmd_queue_rready_o = 1'b1;
      end
      // FetchAddr: Fetch DAT entry
      FetchAddr: begin
        // TODO: Optimize DAT read so it takes just 1 cycle
        dat_read_valid_hw_o = 1'b1;
        dat_index_hw_o = $clog2(`DAT_DEPTH)'(dev_index);
      end
      // I2CWriteImmediateDAT: Execute Immediate Transfer to Legacy I2C Device via I2C Controller
      I2CWriteImmediateDAT: begin
        // TODO: Figure out if the transfer should proceed if its DTT is set to `Defining Byte + 0`
        // since in such scenario it sends only a target device address. It might be better to just
        // report an error.
        transfer_cnt_clr = 1'b0;
        transfer_cnt_en = fmt_fifo_rdone_i;
        fmt_fifo_rvalid_o = 1'b1;
        fmt_flag_start_before_o = 1'b0;
        fmt_flag_stop_after_o = 1'b0;
        resp_data_length_d = '0;
        unique case (transfer_cnt_q)
          // TODO: Add support for broadcast address control before private transfers. This can
          // be realized via HC_CONTROL.I2C_DEV_PRESENT and HC_CONTROL.IBA_INCLUDE register fields.
          // 32'd0: fmt_byte_o = {7'h7e, 1'b0};
          // Target address
          32'd0: fmt_byte_o = {dat_rdata.static_address, 1'b0};
          // Byte 1
          32'd1:
          fmt_byte_o = imm_use_def_byte ? immediate_dat_cmd_desc.data_byte2
                                               : immediate_dat_cmd_desc.def_or_data_byte1;
          // Byte 2
          32'd2:
          fmt_byte_o = imm_use_def_byte ? immediate_dat_cmd_desc.data_byte3
                                               : immediate_dat_cmd_desc.data_byte2;
          // Byte 3
          32'd3: fmt_byte_o = immediate_dat_cmd_desc.data_byte3;
          // Byte 4
          32'd4: fmt_byte_o = immediate_dat_cmd_desc.data_byte4;
          default: fmt_byte_o = '0;
        endcase

        // Send start condition before first byte
        if (transfer_cnt_q == 0) begin
          fmt_flag_start_before_o = 1'b1;
        end
        // Send stop condition after last byte if TOC is set to STOP
        if (transfer_cnt_q == data_length + (BytesBeforeImmData - 1)) begin
          fmt_flag_stop_after_o = immediate_dat_cmd_desc.toc;
        end
        // Disable FIFO valid whenever I2C Controller is not ready or an immediate transfer is finished
        if (fmt_fifo_rready_i | (transfer_cnt_q == data_length + BytesBeforeImmData)) begin // TODO: shouldn't this be ~fmt_fifo_rready_i?
          fmt_fifo_rvalid_o = 1'b0;
        end
      end
      // I3CWriteImmediateDAT: Execute Immediate Transfer to I3C Device
      I3CWriteImmediateDAT: begin
        // TODO
      end
      // I2CWriteImmediate: Execute Immediate Transfer to Legacy I2C Device via I2C Controller
      I2CWriteImmediateDirect: begin
        // TODO
      end
      // I3CWriteImmediate: Execute Immediate Transfer to I3C Device
      I3CWriteImmediateDirect: begin
        // TODO: Figure out if the transfer should proceed if its DTT is set to `Defining Byte + 0`
        // since in such scenario it sends only a target device address. It might be better to just
        // report an error.
        transfer_cnt_clr = 1'b0;
        transfer_cnt_en = fmt_fifo_rdone_i;
        fmt_fifo_rvalid_o = 1'b1;
        fmt_flag_start_before_o = 1'b0;
        fmt_flag_stop_after_o = 1'b0;
        resp_data_length_d = (transfer_cnt_q == 0) ? '0 : transfer_cnt_q - 1;
        fmt_bit_o = 1'b1;
        unique case (transfer_cnt_q)
          // TODO: Add support for broadcast address control before private transfers. This can
          // be realized via HC_CONTROL.I2C_DEV_PRESENT and HC_CONTROL.IBA_INCLUDE register fields.
          // 32'd0: fmt_byte_o = {7'h7e, 1'b0};
          // Target address
          32'd0: begin
            fmt_byte_o = {immediate_direct_cmd_desc.dev_address, 1'b0};

          end
          // Byte 1
          32'd1: begin
            fmt_byte_o = imm_use_def_byte ? immediate_direct_cmd_desc.data_byte2
                                               : immediate_direct_cmd_desc.def_or_data_byte1;
            fmt_bit_o = ^{fmt_byte_o, 1'b1};
          end
          // Byte 2
          32'd2: begin
            fmt_byte_o = imm_use_def_byte ? immediate_direct_cmd_desc.data_byte3
                                               : immediate_direct_cmd_desc.data_byte2;
            fmt_bit_o = ^{fmt_byte_o, 1'b1};
          end
          // Byte 3
          32'd3: begin
            fmt_byte_o = immediate_direct_cmd_desc.data_byte3;
            fmt_bit_o  = ^{fmt_byte_o, 1'b1};
          end
          // Byte 4
          32'd4: begin
            fmt_byte_o = immediate_direct_cmd_desc.data_byte4;
            fmt_bit_o  = ^{fmt_byte_o, 1'b1};
          end
          default: begin
            fmt_byte_o = '0;
            fmt_bit_o  = 1'b0;
          end
        endcase

        // Send start condition before first byte
        if (transfer_cnt_q == 0) begin
          fmt_flag_start_before_o = 1'b1;
        end
        // Send stop condition after last byte if TOC is set to STOP
        if (transfer_cnt_q == data_length + (BytesBeforeImmData)) begin
          fmt_flag_stop_after_o = immediate_direct_cmd_desc.toc;
          fmt_flag_restart_after_o = ~immediate_direct_cmd_desc.toc;
          resp_err_status_d = Success;
        end
        // Disable FIFO valid whenever I2C Controller is not ready or an immediate transfer is finished
        if (fmt_fifo_rready_i && (transfer_cnt_q < data_length + 1 + BytesBeforeImmData)) begin
          fmt_fifo_rvalid_o = 1'b1;
        end
        if (fmt_receive_nack_i & fmt_fifo_rdone_i) begin
          resp_err_status_d = Nack;
        end
      end
      I3CWriteRegularDirect: begin
        transfer_cnt_clr = 1'b0;
        transfer_cnt_en = fmt_fifo_rdone_i;
        fmt_fifo_rvalid_o = 1'b1;
        fmt_flag_start_before_o = 1'b0;
        fmt_flag_stop_after_o = 1'b0;
        resp_data_length_d = (transfer_cnt_q == 0) ? '0 : transfer_cnt_q - 1;
        fmt_bit_o = 1'b1;
        tx_queue_rready_o = ((transfer_cnt_q % (HciTxDataWidth >> 3)) == 0) & transfer_cnt_en;

        if (transfer_cnt_q == 32'd0) begin : addr_assignment
          fmt_byte_o = {regular_direct_cmd_desc.dev_address, 1'b0};
          fmt_flag_start_before_o = 1'b1;
        end else begin
          fmt_byte_o = tx_dword_array[byte_select];
          fmt_bit_o  = ^{fmt_byte_o, 1'b1};
        end

        // Send stop signal
        if (transfer_cnt_q >= data_length) begin
          fmt_flag_stop_after_o = regular_direct_cmd_desc.toc;
          fmt_flag_restart_after_o = ~regular_direct_cmd_desc.toc;
          tx_queue_rready_o = 1'b0;  // when we're done we don't want to pop new data from the queue
          resp_err_status_d = Success;  // successfull transfer without errors
        end

        // Error conditions
        if (transfer_cnt_q < data_length && transfer_cnt_en && tx_queue_empty_i) begin
          // TODO: implement error handling 
        end
        if (fmt_receive_nack_i & fmt_fifo_rdone_i) begin
          resp_err_status_d = Nack;
        end
      end
      I3CReadDirect: begin
        transfer_cnt_clr = 1'b0;
        transfer_cnt_en = fmt_fifo_rdone_i | fmt_flag_read_valid_i;
        resp_data_length_d = (transfer_cnt_q == 0) ? '0 : transfer_cnt_q;
        fmt_flag_read_bytes_o = 1'b1;
        if (transfer_cnt_q == 32'd0) begin
          fmt_byte_o = {regular_direct_cmd_desc.dev_address, 1'b1};
          fmt_flag_start_before_o = 1'b1;
          fmt_fifo_rvalid_o = 1'b1;
        end else begin
          rx_dword_array = (byte_select == '0) & fmt_flag_read_valid_i ? '0 : rx_dword_q;  // reset each new word to 0
          if (fmt_flag_read_valid_i) begin
            rx_dword_array[byte_select] = fmt_byte_i;
          end

          if (((transfer_cnt_q) % (HciRxDataWidth >> 3)) == 0) begin
            rx_queue_wvalid_o = fmt_flag_read_valid_i;  // Send data to rx queue
            if (~rx_queue_wready_i) begin
              // TODO: stall SCL until rx_queue can consume data
            end
          end
        end

        if (transfer_cnt_q <= data_length & (~fmt_bit_i & fmt_flag_read_valid_i)) begin  // receive RX T bit
          fmt_flag_stop_after_o = 1'b1;
          resp_err_status_d = I3cShortReadErr;
          rx_dword_array[byte_select] = fmt_byte_i;
          rx_queue_wvalid_o = 1'b1; // send the uncompleted word to the RX queue when transaction is finished early
        end

        if (transfer_cnt_q >= data_length & fmt_flag_read_valid_i) begin
          fmt_flag_stop_after_o = regular_direct_cmd_desc.toc;
          fmt_flag_restart_after_o = ~regular_direct_cmd_desc.toc;
          resp_err_status_d = Success;  // successfull transfer without errors
        end

        if (fmt_receive_nack_i & fmt_fifo_rdone_i) begin
          resp_err_status_d = Nack;
        end

      end
      InitI2CWrite: begin
        // FUTUREFIX
      end
      InitI2CRead: begin
        // FUTUREFIX
      end
      StallWrite: begin
        // FUTUREFIX
      end
      StallRead: begin
        // FUTUREFIX
      end
      DirectCCC: begin
        transfer_cnt_clr = 1'b0;
        transfer_cnt_en = fmt_fifo_rdone_i;
        fmt_fifo_rvalid_o = 1'b1;
        fmt_flag_start_before_o = 1'b0;
        fmt_flag_stop_after_o = 1'b0;
        resp_data_length_d = (transfer_cnt_q == 0) ? '0 : transfer_cnt_q - 1;
        ccc_done = 1'b0;
        fmt_bit_o = 1'b1;
        tx_queue_rready_o = 1'b0;
        unique case (transfer_cnt_q)
          32'd0: begin  // Broadcast Address
            fmt_byte_o = {7'h7E, 1'b0};
            fmt_flag_start_before_o = 1'b1;
          end
          32'd1: begin  // Broadcast the CCC
            fmt_byte_o = cmd_ccc;
            fmt_bit_o = ^{fmt_byte_o, 1'b1};
            fmt_flag_restart_after_o = 1'b1;
            tx_queue_rready_o = is_regular_transfer & fmt_fifo_rdone_i; // Pop payload byte for next cycle
          end
          32'd2: begin  // Transmit Target Addr
            fmt_byte_o = is_regular_transfer ? {regular_direct_cmd_desc.dev_address, cmd_dir == Read} 
                                             : {immediate_direct_cmd_desc.dev_address, cmd_dir == Read};
            if (fmt_receive_nack_i) begin
              resp_err_status_d = Nack;
            end
          end
          32'd3: begin  // Transmit the first Payload byte
            ccc_done = ((cmd_ccc == `I3C_DIRECT_ENEC) | (cmd_ccc == `I3C_DIRECT_DISEC)) & fmt_fifo_rdone_i; // CCC is done if it only needs one payload byte
            if (is_regular_transfer) begin
              fmt_byte_o = tx_dword_array[0];
              fmt_bit_o = ^{fmt_byte_o, 1'b1};
              // TODO: when we have more than one payload byte stop/restart should not
              // be set
              fmt_flag_stop_after_o = regular_direct_cmd_desc.toc;
              fmt_flag_restart_after_o = ~regular_direct_cmd_desc.toc;
              resp_err_status_d = Success;  // successfull transfer without errors
            end else begin
              fmt_byte_o = immediate_direct_cmd_desc.def_or_data_byte1;
              fmt_bit_o = ^{fmt_byte_o, 1'b1};
              // TODO: when we have more than one payload byte this should not
              // be set
              fmt_flag_stop_after_o = immediate_direct_cmd_desc.toc;
              fmt_flag_restart_after_o = ~immediate_direct_cmd_desc.toc;
              resp_err_status_d = Success;  // successfull transfer without errors
            end
          end
          32'd4: begin
            // TODO: implement direct CCC with more than one payload byte
          end
          default: begin
            resp_err_status_d = HcAborted;
          end
        endcase
      end
      BroadcastCCC: begin
        transfer_cnt_clr = 1'b0;
        transfer_cnt_en = fmt_fifo_rdone_i;
        fmt_fifo_rvalid_o = 1'b1;
        fmt_flag_start_before_o = 1'b0;
        fmt_flag_stop_after_o = 1'b0;
        resp_data_length_d = (transfer_cnt_q == 0) ? '0 : transfer_cnt_q - 1;
        ccc_done = 1'b0;
        fmt_bit_o = 1'b1;
        tx_queue_rready_o = 1'b0;
        unique case (transfer_cnt_q)
          32'd0: begin  // Broadcast Address
            fmt_byte_o = {7'h7E, 1'b0};
            fmt_flag_start_before_o = 1'b1;
          end
          32'd1: begin  // Broadcast the CCC
            fmt_byte_o = cmd_ccc;
            fmt_bit_o = ^{fmt_byte_o, 1'b1};
            fmt_flag_stop_after_o = ~ccc_has_payload & ((is_regular_transfer & regular_direct_cmd_desc.toc) | (~is_regular_transfer & immediate_direct_cmd_desc.toc));
            fmt_flag_restart_after_o = ~ccc_has_payload & ((is_regular_transfer & ~regular_direct_cmd_desc.toc) | (~is_regular_transfer & ~immediate_direct_cmd_desc.toc));
            tx_queue_rready_o = is_regular_transfer & fmt_fifo_rdone_i; // Pop payload byte for next cycle
            ccc_done = ~ccc_has_payload & fmt_fifo_rdone_i;
          end
          32'd2: begin  // Transmit the first Payload byte
            ccc_done = ((cmd_ccc == `I3C_BCAST_ENEC) | (cmd_ccc == `I3C_BCAST_DISEC)) & fmt_fifo_rdone_i;
            if (is_regular_transfer) begin
              fmt_byte_o = tx_dword_array[0];
              fmt_bit_o = ^{fmt_byte_o, 1'b1};
              // TODO: when we have more than one payload byte this should not
              // be set
              fmt_flag_stop_after_o = regular_direct_cmd_desc.toc;
              fmt_flag_restart_after_o = ~regular_direct_cmd_desc.toc;
            end else begin
              fmt_byte_o = immediate_direct_cmd_desc.def_or_data_byte1;
              fmt_bit_o = ^{fmt_byte_o, 1'b1};
              // TODO: when we have more than one payload byte this should not
              // be set
              fmt_flag_stop_after_o = immediate_direct_cmd_desc.toc;
              fmt_flag_restart_after_o = ~immediate_direct_cmd_desc.toc;
            end
          end
          32'd3: begin
            // TODO: implement broadcast CCC with more than one payload byte
          end
          default: begin
            resp_err_status_d = HcAborted;
          end
        endcase
        if (ccc_done) begin
          resp_err_status_d = Success;  // successfull transfer without errors
        end

      end
      // WriteResp: Generate Response Descriptor and load it to Response Queue
      WriteResp: begin
        resp_desc.err_status = resp_err_status_q;
        resp_desc.tid = cmd_tid;
        resp_desc.data_length = resp_data_length_q;
        resp_queue_wvalid_o = 1'b1;
        resp_queue_wdata_o = resp_desc;
      end
      default: begin
        resp_desc.err_status = AbortedWithCRC;  // TODO: change default state?
        resp_desc.tid = '0;
        resp_desc.data_length = '0;
      end
    endcase
  end

  // Combinational state transition
  always_comb begin
    state_next = state;
    unique case (state)
      // Idle: Wait for command appearance in the Command Queue
      Idle: begin
        if (i3c_fsm_en_i) begin
          state_next = WaitForCmd;
        end
      end
      // WaitForCmd: Fetch Command Descriptor
      WaitForCmd: begin
        if (~cmd_queue_empty_i & cmd_queue_rvalid_i) begin
          state_next = FetchAddr;
        end
      end
      // FetchAddr: Fetch target address, either from DAT or from cmd_desc
      FetchAddr: begin
        if (is_direct_transfer) begin
          unique case (cmd_attr)
            ImmediateDataTransferDirect: begin
              state_next = cmd_is_ccc & fmt_fifo_rready_i ? (cmd_is_broadcast_ccc ? BroadcastCCC : DirectCCC) :
                           i2c_cmd & fmt_fifo_rready_i ? I2CWriteImmediateDirect :
                           (fmt_fifo_rready_i ? I3CWriteImmediateDirect : state);
            end
            RegularTransferDirect: begin
              state_next = cmd_is_ccc & fmt_fifo_rready_i ? (cmd_is_broadcast_ccc ? BroadcastCCC : DirectCCC) :
                          (cmd_dir == Read) ? I3CReadDirect : (fmt_fifo_rready_i ? I3CWriteRegularDirect : state);
            end
            ComboTransferDirect: begin
              // TODO
            end
            default: state_next = state;  // Stall
          endcase
        end else begin
          if (dat_captured) begin
            if (cmd_attr == ImmediateDataTransferDAT) begin //TODO: here we will have the main decode regarding the cmd_attr -> have a case statement that checks all cmd_attr types from Table 21 TCRI spec and give them their own state -> important for CCC
              // TODO: Report an error if a command is immediate with RNW set to Read
              state_next = i2c_cmd ? I2CWriteImmediateDAT : I3CWriteImmediateDAT;
            end else begin
              if (cmd_dir == Write) begin
                state_next = Idle;
              end else if (cmd_dir == Read) begin
                state_next = I3CReadDirect;
              end
            end
          end
        end
      end
      // I3CWriteImmediate: Execute Immediate Transfer to Legacy I2C Device via I2C Controller
      I2CWriteImmediateDAT: begin
        if (transfer_cnt_q == data_length + BytesBeforeImmData) begin
          // TODO: Do not generate Response Descriptor if WROC field of the Command Descriptor is set to 0
          state_next = WriteResp;
        end
      end
      // I2CWriteImmediate: Execute Immediate Transfer to I3C Device
      I3CWriteImmediateDAT: begin
        // TODO
      end
      // I2CWriteImmediate: Execute Immediate Transfer to Legacy I2C Device via I2C Controller
      I2CWriteImmediateDirect: begin
        if (transfer_cnt_q == data_length + BytesBeforeImmData) begin
          // TODO: Do not generate Response Descriptor if WROC field of the Command Descriptor is set to 0
          state_next = WriteResp;
        end
      end
      // I3CWriteImmediate: Execute Immediate Transfer to I3C Device
      I3CWriteImmediateDirect: begin
        if (fmt_receive_nack_i & fmt_fifo_rdone_i) begin
          state_next = WriteResp;  // TODO: create an error state for such occasions
        end else if (transfer_cnt_q > data_length + BytesBeforeImmData) begin
          state_next = immediate_direct_cmd_desc.wroc ? WriteResp : Idle;
        end
      end
      I3CWriteRegularDirect: begin
        if (fmt_receive_nack_i & fmt_fifo_rdone_i) begin
          state_next = WriteResp;  // TODO: create an error state for such occasions
        end else if (transfer_cnt_q > data_length) begin
          state_next = regular_direct_cmd_desc.wroc ? WriteResp : Idle;
        end
        if (transfer_cnt_q < data_length && transfer_cnt_en && tx_queue_empty_i && tx_queue_rready_o) begin
          state_next = WriteResp;  // TODO: create an error state for such occasions
        end
      end
      I3CReadDirect: begin
        if (fmt_receive_nack_i & fmt_fifo_rdone_i) begin
          state_next = WriteResp;
        end else if (transfer_cnt_q >= data_length & fmt_flag_read_valid_i) begin
          state_next = regular_direct_cmd_desc.wroc ? WriteResp : Idle;
        end else if (transfer_cnt_q < data_length & (~fmt_bit_i & fmt_flag_read_valid_i)) begin  // receive RX T bit
          state_next = regular_direct_cmd_desc.sre ? WriteResp : Idle;
        end
      end
      InitI2CWrite: begin
        // FUTUREFIX
      end
      InitI2CRead: begin
        // FUTUREFIX
      end
      StallWrite: begin
        // FUTUREFIX
      end
      StallRead: begin
        // FUTUREFIX
      end
      DirectCCC: begin
        if (ccc_done) begin
          state_next = (~is_regular_transfer & immediate_direct_cmd_desc.wroc) ? WriteResp : 
                       (is_regular_transfer & regular_direct_cmd_desc.wroc)    ? WriteResp : Idle;
        end else if (fmt_receive_nack_i & fmt_fifo_rdone_i) begin
          state_next = WriteResp;
        end
      end
      BroadcastCCC: begin
        if (ccc_done) begin
          state_next = (~is_regular_transfer & immediate_direct_cmd_desc.wroc) ? WriteResp : 
                       (is_regular_transfer & regular_direct_cmd_desc.wroc)    ? WriteResp : Idle;
        end else if (fmt_receive_nack_i & fmt_fifo_rdone_i) begin
          state_next = WriteResp;
        end
      end
      // WriteResp: Generate Response Descriptor and load it to Response Queue
      WriteResp: begin
        if (resp_queue_wready_i) begin
          state_next = Idle;
        end
      end
      default: begin
        state_next = Idle;
      end
    endcase
  end

  // Sequential state update
  always_ff @(posedge clk_i or negedge rst_ni) begin : proc_test
    if (~rst_ni) begin
      state <= Idle;
    end else begin
      state <= state_next;
    end
  end

endmodule

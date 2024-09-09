// SPDX-License-Identifier: Apache-2.0

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
    input logic [HciIbiThldWidth-1:0] ibi_queue_thld_i,
    input logic ibi_queue_above_thld_i,
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
    output logic host_enable_o,  // enable host functionality

    output logic fmt_fifo_rvalid_o,
    output logic [I2CFifoDepthWidth-1:0] fmt_fifo_depth_o,
    input logic fmt_fifo_rready_i,
    output logic [7:0] fmt_byte_o,
    output logic fmt_flag_start_before_o,
    output logic fmt_flag_stop_after_o,
    output logic fmt_flag_read_bytes_o,
    output logic fmt_flag_read_continue_o,
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

  // TODO: Set BytesBeforeImmData from the HC_CONTROL.IBA_INCLUDE
  localparam int unsigned BytesBeforeImmData = 1;  // 1 if IBA is disabled, otherwise 2

  flow_fsm_state_e state, state_next;

  immediate_data_trans_desc_t immediate_cmd_desc;
  regular_trans_desc_t regular_cmd_desc;
  combo_trans_desc_t combo_cmd_desc;
  addr_assign_desc_t addr_cmd_desc;
  logic [63:0] cmd_desc;

  // Values extracted from the Command Descriptor
  cmd_transfer_dir_e cmd_dir;
  i3c_cmd_attr_e cmd_attr;
  logic [4:0] dev_index;
  logic [3:0] cmd_tid;
  logic [15:0] data_length;
  logic imm_use_def_byte;

  // Generic incremental counter
  logic [31:0] transfer_cnt;
  logic transfer_cnt_en;
  logic transfer_cnt_rst;

  logic [HciCmdDataWidth-1:0] cmd_queue_rdata;
  logic cmd_queue_rvalid;

  // DAT table
  dat_entry_t dat_rdata;
  logic dat_captured, dat_read_valid_d;

  // DCT table
  // TODO: Use DCT typedef struct
  logic [127:0] dct_rdata;
  logic dct_captured, dct_read_valid_d;

  // Values extracted from the DAT entry
  logic i2c_cmd;

  // TX Queue
  logic [HciTxDataWidth-1:0] tx_dword;
  logic pop_tx_fifo;

  // Response Queue
  i3c_response_desc_t resp_desc;
  i3c_resp_err_status_e resp_err_status_q, resp_err_status_d;
  logic [15:0] resp_data_length_q, resp_data_length_d;

  // TODO: Set appropriately
  always_comb begin
    resp_err_status_q = Success;
    fmt_flag_read_bytes_o = 1'b0;
    fmt_flag_read_continue_o = 1'b0;
    fmt_flag_nak_ok_o = 1'b0;
    unhandled_unexp_nak_o = 1'b0;
    unhandled_nak_timeout_o = 1'b0;
  end

  // Assign generic Command Descriptor to command specific structures
  assign immediate_cmd_desc = cmd_desc;
  assign regular_cmd_desc = cmd_desc;
  assign combo_cmd_desc = cmd_desc;
  assign addr_cmd_desc = cmd_desc;

  // Initialize descriptor's reserved field
  assign resp_desc.__rsvd23_16 = '0;

  // Assign generic command fields to generic signals
  assign dev_index = cmd_desc[20:16];
  assign cmd_tid = cmd_desc[6:3];
  assign cmd_dir = cmd_desc[29] ? Read : Write;
  assign cmd_attr = i3c_cmd_attr_e'(cmd_desc[2:0]);

  // Assign DAT entry specific signals
  assign i2c_cmd = dat_rdata.device;

  // Assign constants
  // TODO: Add control logic to constant signals
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
        dat_captured <= 1'b1;
      end else begin
        dat_rdata <= dat_rdata;
        dat_captured <= 1'b0;
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
      ImmediateDataTransfer: begin
        // If DTT is 5-7, it is a CCC with a defining byte. In such case substract 5 from DTT to
        // get an actual transfer data length.
        // Values:
        // - 0: No payload
        // - 1–4: N bytes are valid
        // - 5: Defining Byte + 0
        // - 6: Defining Byte + 1
        // - 7: Defining Byte + 2
        imm_use_def_byte = immediate_cmd_desc.dtt > 4 ? 1'b1 : 1'b0;
        data_length = imm_use_def_byte ? immediate_cmd_desc.dtt - 5 : immediate_cmd_desc.dtt;
      end
      AddressAssignment: begin
        // TODO
        imm_use_def_byte = '0;
        data_length = '0;
      end
      ComboTransfer: begin
        imm_use_def_byte = '0;
        data_length = combo_cmd_desc.data_length;
      end
      InternalControl: begin
        // TODO
        imm_use_def_byte = '0;
        data_length = '0;
      end
      RegularTransfer: begin
        imm_use_def_byte = '0;
        data_length = regular_cmd_desc.data_length;
      end
      default: begin
        imm_use_def_byte = '0;
        data_length = '0;
      end
    endcase
  end

  // Control internal transfer counter
  // TODO: Consider using decremental counter with different load values
  // See i2c_controller_fsm.sv for reference
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (~rst_ni) begin
      transfer_cnt <= '0;
    end else begin
      if (transfer_cnt_rst) begin
        transfer_cnt <= '0;
      end else if (transfer_cnt_en) begin
        transfer_cnt <= transfer_cnt + 1;
      end else begin
        transfer_cnt <= transfer_cnt;
      end
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
      resp_err_status_d <= Success;
    end else begin
      // TODO: Add proper error catching
      if (i3c_fsm_idle_o) begin
        resp_err_status_d <= Success;
      end else begin
        resp_err_status_d <= resp_err_status_d;
      end
    end
  end

  // Catch every data_length update during the Controller operation
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (~rst_ni) begin
      resp_data_length_d <= '0;
    end else begin
      if (i3c_fsm_idle_o) begin
        resp_data_length_d <= '0;
      end else if (resp_data_length_q) begin
        resp_data_length_d <= resp_data_length_q;
      end else begin
        resp_data_length_d <= resp_data_length_d;
      end
    end
  end

  // Combinational state output update
  always_comb begin
    i3c_fsm_idle_o = 1'b0;
    transfer_cnt_en = 1'b0;
    cmd_queue_rready_o = 1'b0;
    dat_read_valid_hw_o = 1'b0;
    dct_read_valid_hw_o = 1'b0;
    dat_index_hw_o = '0;
    tx_queue_rready_o = 1'b0;
    pop_tx_fifo = 1'b0;
    transfer_cnt_rst = 1'b1;
    fmt_fifo_rvalid_o = 1'b0;
    fmt_flag_start_before_o = 1'b0;
    unique case (state)
      // Idle: Wait for command appearance in the Command Queue
      Idle: begin
        i3c_fsm_idle_o = 1'b1;
      end
      // WaitForCmd: Fetch Command Descriptor
      WaitForCmd: begin
        cmd_queue_rready_o = 1'b1;
      end
      // FetchDAT: Fetch DAT entry
      FetchDAT: begin
        // TODO: Optimize DAT read so it takes just 1 cycle
        dat_read_valid_hw_o = 1'b1;
        dat_index_hw_o = dev_index;
      end
      // I2CWriteImmediate: Execute Immediate Transfer to Legacy I2C Device via I2C Controller
      I2CWriteImmediate: begin
        // TODO: Figure out if the transfer should proceed if its DTT is set to `Defining Byte + 0`
        // since in such scenario it sends only a target device address. It might be better to just
        // report an error.
        transfer_cnt_rst = 1'b0;
        transfer_cnt_en = fmt_fifo_rready_i;
        fmt_fifo_rvalid_o = 1'b1;
        fmt_flag_start_before_o = 1'b0;
        // TODO: Fix inferred latch 'fmt_flag_stop_after_o'
        fmt_flag_stop_after_o = 1'b0;
        // TODO: Fix inferred latch 'resp_data_length_q'
        resp_data_length_q = '0;
        unique case (transfer_cnt)
          // TODO: Add support for broadcast address control before private transfers. This can
          // be realized via HC_CONTROL.I2C_DEV_PRESENT and HC_CONTROL.IBA_INCLUDE register fields.
          // 32'd0: fmt_byte_o = {7'h7e, 1'b0};
          // Target address
          // TODO: Fix inferred latch 'fmt_byte_o'
          32'd0: fmt_byte_o = {dat_rdata.static_address, 1'b0};
          // Byte 1
          32'd1:
          fmt_byte_o = imm_use_def_byte ? immediate_cmd_desc.data_byte2
                                               : immediate_cmd_desc.def_or_data_byte1;
          // Byte 2
          32'd2:
          fmt_byte_o = imm_use_def_byte ? immediate_cmd_desc.data_byte3
                                               : immediate_cmd_desc.data_byte2;
          // Byte 3
          32'd3: fmt_byte_o = immediate_cmd_desc.data_byte3;
          // Byte 4
          32'd4: fmt_byte_o = immediate_cmd_desc.data_byte4;
          default: fmt_byte_o = '0;
        endcase

        // Send start condition before first byte
        if (transfer_cnt == 0) begin
          fmt_flag_start_before_o = 1'b1;
        end
        // Send stop condition after last byte if TOC is set to STOP
        if (transfer_cnt == data_length + (BytesBeforeImmData - 1)) begin
          fmt_flag_stop_after_o = immediate_cmd_desc.toc;
        end
        // Disable FIFO valid whenever I2C Controller is not ready or an immediate transfer is finished
        if (fmt_fifo_rready_i | (transfer_cnt == data_length + BytesBeforeImmData)) begin
          fmt_fifo_rvalid_o = 1'b0;
        end
      end
      // I2CWriteImmediate: Execute Immediate Transfer to I3C Device
      I3CWriteImmediate: begin
        // TODO
      end
      FetchTxData: begin
        // TODO
      end
      FetchRxData: begin
        // TODO
      end
      InitI2CWrite: begin
        // TODO
      end
      InitI2CRead: begin
        // TODO
      end
      StallWrite: begin
        // TODO
      end
      StallRead: begin
        // TODO
      end
      IssueCmd: begin
        // TODO
      end
      // WriteResp: Generate Response Descriptor and load it to Response Queue
      WriteResp: begin
        // TODO: Fix inferred latch 'resp_queue_wvalid_o'
        resp_queue_wvalid_o = 1'b0;
        resp_desc.err_status = resp_err_status_d;
        resp_desc.tid = cmd_tid;
        resp_desc.data_length = resp_data_length_d;

        if (resp_queue_wready_i) begin
          resp_queue_wvalid_o = 1'b1;
          // TODO: Fix inferred latch 'resp_queue_wdata_o'
          resp_queue_wdata_o  = resp_desc;
        end
      end
      default: begin
        // TODO
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
          state_next = FetchDAT;
        end
      end
      // FetchDAT: Fetch DAT entry
      FetchDAT: begin
        if (dat_captured) begin
          if (cmd_attr == ImmediateDataTransfer) begin
            // TODO: Report an error if a command is immediate with RNW set to Read
            state_next = i2c_cmd ? I2CWriteImmediate : I3CWriteImmediate;
          end else begin
            if (cmd_dir == Write) begin
              state_next = FetchTxData;
            end else if (cmd_dir == Read) begin
              state_next = FetchRxData;
            end
          end
        end
      end
      // I2CWriteImmediate: Execute Immediate Transfer to Legacy I2C Device via I2C Controller
      I2CWriteImmediate: begin
        if (transfer_cnt == data_length + BytesBeforeImmData) begin
          // TODO: Do not generate Response Descriptor if WROC field of the Command Descriptor is set to 0
          state_next = WriteResp;
        end
      end
      // I2CWriteImmediate: Execute Immediate Transfer to I3C Device
      I3CWriteImmediate: begin
        // TODO
      end
      FetchTxData: begin
        // TODO
      end
      FetchRxData: begin
        // TODO
      end
      InitI2CWrite: begin
        // TODO
      end
      InitI2CRead: begin
        // TODO
      end
      StallWrite: begin
        // TODO
      end
      StallRead: begin
        // TODO
      end
      IssueCmd: begin
        // TODO
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

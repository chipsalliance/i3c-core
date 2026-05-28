// SPDX-License-Identifier: Apache-2.0

// Description: Decodes Command Descriptor and forwards byte to be sent on the
// I3C / I2C bus to the
// i3c_controller_fsm and i2c_controller_fsm
// TODO: Add support for data byte ordering modes (HC_CONTROL.DATA_BYTE_ORDER_MODE)

module flow_active
  import controller_pkg::*;
  import i3c_pkg::*;
  import prim_ram_2p_pkg::*;
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
    input  dat_mem_sink_t                          dat_mem_sink_i,
    output logic                                   dat_read_valid_hw_o,
    output logic          [$clog2(`DAT_DEPTH)-1:0] dat_index_hw_o,
    input  logic          [                  63:0] dat_rdata_hw_i,

    // DCT <-> Controller interface
    output logic                          dct_write_valid_hw_o,
    output logic                          dct_read_valid_hw_o,
    output logic [$clog2(`DCT_DEPTH)-1:0] dct_index_hw_o,
    output logic [                 127:0] dct_wdata_hw_o,
    input  logic [                 127:0] dct_rdata_hw_i,

    // I2C Controller interface
    output logic host_enable_o,  // enable host functionality
    output logic is_i2c_transfer_o,  // is it an I2C transfer
    input logic i2c_cmd_complete_i,

    output logic       fmt_fifo_rvalid_o,
    input  logic       fmt_fifo_rready_i,
    input  logic       fmt_fifo_rdone_i,
    output logic [7:0] fmt_byte_o,
    output logic       fmt_bit_o,                   // T bit
    output logic       fmt_flag_start_before_o,
    output logic       fmt_flag_restart_after_o,
    output logic       fmt_flag_stop_after_o,
    output logic       fmt_flag_read_continuous_o,
    input  logic       fmt_receive_nack_i,
    input  logic       fmt_sda_arbitration_i,
    // fmt RX signals
    input  logic [7:0] fmt_byte_i,
    input  logic       fmt_bit_i,
    output logic       fmt_flag_read_bytes_o,
    input  logic       fmt_flag_read_valid_i,

    output logic fmt_flag_nak_ok_o,
    output logic fmt_flag_hdr_exit_o,
    output logic unhandled_nak_timeout_o,

    // RX FIFO queue from I2C Controller
    input logic                   rx_fifo_wvalid_i,
    input logic [RxFifoWidth-1:0] rx_fifo_wdata_i,

    // I3C FSM control & status
    input  logic i3c_fsm_en_i,
    output logic i3c_fsm_idle_o,
    input  logic pio_rs_i,
    input  logic halt_on_cmd_seq_timeout_i,

    // Errors and Interrupts
    input logic resume_i,  // HC_CONTROL.RESUME CSR field
    input logic abort_i,   // HC_CONTROL.ABORT | PIO_CONTROL.ABORT CSR fields

    output i3c_irq_t irq_o
);
  localparam int IBIBufferDepthDwords = `IBI_BUFFER_DEPTH;

  // Helper function to check if current CCC has payload or not
  function automatic logic has_payload(ccc_cmd_e ccc);
    if((ccc == CCC_DIRECT_ENEC) || (ccc == CCC_DIRECT_DISEC) || (ccc == CCC_BCAST_ENEC) || (ccc == CCC_BCAST_DISEC)) begin
      // TODO: #95745 add more CCCs with payload
      return 1'b1;
    end else begin
      return 1'b0;
    end
  endfunction

  // Helper function to check if current CCC has only one byte of payload or not
  function automatic logic ccc_has_one_byte_of_payload(ccc_cmd_e ccc);
    if(((ccc == CCC_DIRECT_ENEC) | (ccc == CCC_DIRECT_DISEC) | (ccc == CCC_DIRECT_SETDASA) | (ccc == CCC_DIRECT_SETNEWDA) | (ccc == CCC_DIRECT_GETBCR) | (ccc == CCC_DIRECT_GETDCR))) begin
      // TODO: #95745 add more CCCs with payload
      return 1'b1;
    end else begin
      return 1'b0;
    end
  endfunction

  logic
      hc_err_cmd_seq_timeout_stat,
      hc_seq_cancel_stat,
      pio_transfer_abort_stat,
      pio_transfer_err_stat;

  always_comb begin : interrupt_assignment
    irq_o.sched_cmd_missed_tick_stat = 1'b0;
    irq_o.hc_err_cmd_seq_timeout_stat = hc_err_cmd_seq_timeout_stat;
    irq_o.hc_warn_cmd_seq_stall_stat = 1'b0;
    irq_o.hc_seq_cancel_stat = hc_seq_cancel_stat;
    irq_o.hc_internal_err_stat = 1'b0;
    irq_o.pio_transfer_err_stat = pio_transfer_err_stat;
    irq_o.pio_transfer_abort_stat = pio_transfer_abort_stat;
  end

  typedef enum logic [4:0] {
    Idle = 5'd0,
    WaitForCmd = 5'd1,
    FetchAddr = 5'd2,
    I2CWriteImmediate = 5'd3,
    I3CWriteImmediate = 5'd4,
    I3CWriteRegular = 5'd5,
    I2CWriteRegular = 5'd6,
    I3CRead = 5'd7,
    I2CRead = 5'd8,
    StallWrite = 5'd9,
    StallRead = 5'd10,
    DirectCCC = 5'd11,
    BroadcastCCC = 5'd12,
    DynamicAddrAssignment = 5'd13,
    WriteResp = 5'd14,
    InternalControlCommand = 5'd15,
    I3CBcastHeader = 5'd16,
    IBI = 5'd17,
    Error = 5'd18
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
  internal_control_desc_t internal_ctrl_cmd_desc;
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

  // DAT table
  dat_entry_t dat_rdata;
  logic dat_captured, dat_read_valid_d, dat_read_valid_q;
  logic [$clog2(`DAT_DEPTH)-1:0] dat_index_q, dat_index_d;

  // DCT table
  // FUTUREFIX: Use DCT typedef struct
  logic [127:0] dct_rdata;
  dct_entry_t dct_data;
  logic dct_read_valid_d, dct_read_valid_q;
  logic [$clog2(`DCT_DEPTH)-1:0] dct_index_q, dct_index_d;

  // I2C Signals
  logic i2c_cmd;
  logic i2c_start_d, i2c_start_q;

  // TX Queue
  logic [HciTxDataWidth-1:0] tx_dword;
  logic [(HciTxDataWidth>>3)-1:0][7:0] tx_dword_array;
  logic [$clog2(HciTxDataWidth>>3)-1 : 0] byte_select;
  logic [$clog2(HciTxDataWidth>>3)-1 : 0] ccc_byte_select;
  assign byte_select = ((transfer_cnt_q - 1) % (HciTxDataWidth >> 3));
  assign ccc_byte_select = ((transfer_cnt_q - 3) % (HciTxDataWidth >> 3)); // the first 2 CCC transfers are irrelevant for the byte_select signal (CCC and target addr)
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
  logic ccc_last_trans;
  logic ccc_has_payload;
  logic ccc_ce0_first_retry_d, ccc_ce0_first_retry_q;
  ccc_cmd_e cmd_ccc, prev_ccc_d, prev_ccc_q;
  assign cmd_ccc = ccc_cmd_e'(cmd_desc[14:7]);
  assign ccc_has_payload = has_payload(cmd_ccc);

  // Dynamic Address Assignment signals

  // The number of assigned addresses is limited by the DEV_COUNT field in the Address Assignment cmd desc which is 4 bits
  logic [3:0] assigned_addr_cnt_d, assigned_addr_cnt_q;
  logic [7:0][7:0] dct_raw_data_d, dct_raw_data_q;  // raw data being read during DAA arbitration
  logic daa_iteration_done;
  logic first_nack_q, first_nack_d;

  // Internal Control Command Signals / Flags
  logic icc_done;
  logic
      broadcast_addr_enable_d,
      broadcast_addr_enable_q,
      use_ce2_error_handling_on_nack_d,
      use_ce2_error_handling_on_nack_q;
  logic prev_cmd_toc_d, prev_cmd_toc_q;
  logic err_handled_q, err_handled_d;

  // IBI signals
  logic ibi_abort, ibi_done;
  i3c_ibi_status_desc_t ibi_status_d, ibi_status_q;
  logic [  $clog2(IBIBufferDepthDwords)-1:0] ibi_dword_select;
  logic [$clog2((HciIbiDataWidth >> 3))-1:0] ibi_byte_select;
  logic [IBIBufferDepthDwords-1:0][(HciIbiDataWidth >> 3)-1:0][7:0] ibi_data_d, ibi_data_q;
  logic ibi_wb_d, ibi_wb_q;
  logic [5:0] ibi_wb_cnt_q, ibi_wb_cnt_d;  // max of 64 DWORDs can be sent per IBI

  // RLT signals
  logic [6:0] rlt_dynamic_address;
  logic rlt_req, rlt_wreq, rlt_valid;
  logic [$clog2(`DAT_DEPTH)-1:0] rlt_dat_index;

  assign ibi_dword_select = (transfer_cnt_q - 1) >> 2;
  assign ibi_byte_select  = (transfer_cnt_q - 1) & 2'b11;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (~rst_ni) begin
      assigned_addr_cnt_q <= '0;
      dct_raw_data_q <= '0;
      first_nack_q <= 1'b1;
      dat_index_q <= dev_index;
      dct_index_q <= '0; // TODO: #95749 base index should be the one in I3CBASE.DCT_SECTION_OFFSET.TABLE_INDEX
    end else begin
      assigned_addr_cnt_q <= assigned_addr_cnt_d;
      dct_raw_data_q <= dct_raw_data_d;
      first_nack_q <= first_nack_d;
      dat_index_q <= dat_index_d;
      dct_index_q <= dct_index_d;
    end
  end

  // TODO: #95750 Remove unused signals
  always_comb begin
    fmt_flag_nak_ok_o = 1'b0;
    unhandled_nak_timeout_o = 1'b0;
  end

  // Assign generic Command Descriptor to command specific structures
  assign immediate_dat_cmd_desc = cmd_desc;
  assign immediate_direct_cmd_desc = cmd_desc;
  assign regular_direct_cmd_desc = cmd_desc;
  assign regular_dat_cmd_desc = cmd_desc;
  assign combo_cmd_desc = cmd_desc;
  assign addr_cmd_desc = cmd_desc;
  assign internal_ctrl_cmd_desc = cmd_desc;

  // Initialize descriptor's reserved field
  assign resp_desc.__rsvd23_16 = '0;

  // Assign generic command fields to generic signals
  assign dev_index = cmd_desc[20:16];
  assign cmd_dir = cmd_desc[29] ? Read : Write;
  assign cmd_is_ccc = cmd_desc[15];
  assign cmd_is_broadcast_ccc = ~cmd_desc[14]; // the MSB of the CCC indicates if it's direct or a broadcast see Table 16 I3C Basic Spec
  assign cmd_attr = i3c_cmd_attr_e'(cmd_desc[2:0]);
  assign is_direct_transfer = ((cmd_attr == ImmediateDataTransferDirect) || (cmd_attr == RegularTransferDirect) || (cmd_attr == ComboTransferDirect) || (cmd_attr == InternalControl)) && ((cmd_attr != AddressAssignment));
  assign is_regular_transfer = (cmd_attr == RegularTransferDirect) || (cmd_attr == RegularTransferDAT);
  assign cmd_tid = is_direct_transfer ? {1'b0, cmd_desc[5:3]} : cmd_desc[6:3];
  // Assign if target is an I2C device
  assign i2c_cmd = (is_direct_transfer && (cmd_attr != InternalControl)) ? cmd_desc[6] : dat_rdata.device; // NOTE: the i2c bit is the same for regular cmd desc and immediate cmd desc, that's why no further checking is needed
  assign is_i2c_transfer_o = i2c_cmd;


  // Assign TX fifo signals
  assign pop_tx_fifo = tx_queue_rready_o & tx_queue_rvalid_i;

  // Assign RX Queue signals
  assign rx_queue_wdata_o = rx_dword_d; // when transaction is finished early we update rx_word_d at the same time as setting rx_queue_wvalid_o

  // Assign constants
  // FUTUREFIX: Add control logic to constant signals
  assign host_enable_o = 1'b1;

  // Capture data from DAT/DCT tables
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (~rst_ni) begin
      dat_read_valid_q <= 1'b0;
      dct_read_valid_q <= 1'b0;
    end else begin
      dat_read_valid_q <= dat_read_valid_d;
      dct_read_valid_q <= dct_read_valid_d;
    end
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (~rst_ni) begin
      dat_rdata <= '0;
      dct_rdata <= '0;
      dat_captured <= 1'b0;
    end else begin
      if (dat_read_valid_q) begin
        dat_rdata <= dat_rdata_hw_i;
        dat_captured <= 1'b1;
      end else begin
        dat_rdata <= dat_rdata;
        dat_captured <= 1'b0;
      end
      if (dct_read_valid_q) begin
        dct_rdata <= dct_rdata_hw_i;
      end else begin
        dct_rdata <= dct_rdata;
      end
    end
  end

  assign dct_index_hw_o = dct_index_q;
  assign dat_read_valid_d = dat_read_valid_hw_o;
  assign dct_read_valid_d = dct_read_valid_hw_o;

  // dynamic address -> DAT index reverse lookup table
  assign rlt_wreq = dat_mem_sink_i.req && dat_mem_sink_i.write && (&dat_mem_sink_i.wmask[22:16]);
  // read request is valid 1 cycle after the request has been issued
  logic [$clog2(`DAT_DEPTH)-1:0] unused_a_rdata;
  ram_2p_cfg_rsp_t unused_cfg_rsp;
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (~rst_ni) begin
      rlt_valid <= 1'b0;
    end else begin
      rlt_valid <= rlt_req;
    end
  end
  prim_ram_2p #(
      .Width($clog2(`DAT_DEPTH)),
      // The RLT has to have an entry for each 7-bit I3C address.
      .Depth(128)
  ) i_reverse_lookup_table (
      .clk_a_i(clk_i),
      .clk_b_i(clk_i),

      // Write Port
      .a_req_i(rlt_wreq),
      .a_write_i(1'b1),
      .a_addr_i(dat_mem_sink_i.wdata[22:16]), // dynamic address field of DAT entry without parity bit
      .a_wdata_i(dat_mem_sink_i.addr),  // DAT index
      .a_wmask_i('1),
      .a_rdata_o(unused_a_rdata),

      // Read Port
      .b_req_i  (rlt_req),
      .b_write_i(1'b0),
      .b_addr_i (rlt_dynamic_address),
      .b_wdata_i('0),
      .b_wmask_i('0),
      .b_rdata_o(rlt_dat_index),

      .cfg_i('0),
      .cfg_rsp_o(unused_cfg_rsp)
  );

  // Capture command FIFO control signals
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (~rst_ni) begin
      cmd_queue_rdata <= '0;
    end else begin
      cmd_queue_rdata <= cmd_queue_rdata_i;
    end
  end

  // Store Internal Control Flags
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (~rst_ni) begin
      broadcast_addr_enable_q          <= 1'b0;
      use_ce2_error_handling_on_nack_q <= 1'b0;
      ccc_ce0_first_retry_q            <= 1'b0;
      prev_cmd_toc_q                   <= 1'b1;
      err_handled_q                    <= 1'b0;
    end else begin
      broadcast_addr_enable_q          <= broadcast_addr_enable_d;
      use_ce2_error_handling_on_nack_q <= use_ce2_error_handling_on_nack_d;
      ccc_ce0_first_retry_q            <= ccc_ce0_first_retry_d;
      prev_cmd_toc_q                   <= prev_cmd_toc_d;
      err_handled_q                    <= err_handled_d;
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
        imm_use_def_byte = '0;
        data_length = '0;
      end
      ComboTransferDAT: begin
        imm_use_def_byte = '0;
        data_length = combo_cmd_desc.data_length;
      end
      InternalControl: begin
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
  always_comb begin
    transfer_cnt_d = transfer_cnt_q;
    if (transfer_cnt_clr) begin
      transfer_cnt_d = '0;
    end else if (transfer_cnt_en) begin
      transfer_cnt_d = transfer_cnt_q + 1;

    end else if ((transfer_cnt_q == '0) && cmd_is_ccc && ~cmd_is_broadcast_ccc && ((prev_ccc_q == cmd_ccc) && ~prev_cmd_toc_q)) begin
      transfer_cnt_d = 2; // transfer_cnt_q = 0: 7'h7E byte, transfer_cnt_q = 1: CCC byte according to Figure 32 I3C Basic Spec we are allowed to skip these two bytes when the CCC stays the same.
    end else if(state == DynamicAddrAssignment && daa_iteration_done && (assigned_addr_cnt_q <= addr_cmd_desc.dev_count)) begin
      transfer_cnt_d = 2;  // transfer_cnt_q = 2: is the start of a DAA "frame", while we have not assigned all addresses we should try again
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
      rx_dword_q <= '0;
      resp_err_status_q <= AbortedWithCRC;
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
      prev_ccc_q <= ccc_cmd_e'(8'hFF);  // 0xFF is not used as a CCC, that's why it's a reset state
    end else begin
      prev_ccc_q <= prev_ccc_d;
    end
  end
  assign prev_ccc_d = ccc_done ? cmd_ccc : prev_ccc_q;

  // Store I2C Signals
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (~rst_ni) begin
      i2c_start_q <= 1'b0;
    end else begin
      i2c_start_q <= i2c_start_d;
    end
  end

  // Store IBI Status Descriptor
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (~rst_ni) begin
      ibi_status_q <= '0;
      ibi_data_q   <= '0;
      ibi_wb_q     <= 1'b0;
      ibi_wb_cnt_q <= '0;
    end else begin
      ibi_status_q <= ibi_status_d;
      ibi_data_q   <= ibi_data_d;
      ibi_wb_q     <= ibi_wb_d;
      ibi_wb_cnt_q <= ibi_wb_cnt_d;
    end
  end

  // Combinational state output update
  always_comb begin
    i3c_fsm_idle_o = 1'b0;
    i2c_start_d = i2c_start_q;
    transfer_cnt_en = 1'b0;
    cmd_queue_rready_o = 1'b0;
    dat_read_valid_hw_o = 1'b0;
    dct_read_valid_hw_o = 1'b0;
    dct_write_valid_hw_o = 1'b0;
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
    fmt_flag_read_continuous_o = 1'b0;
    fmt_byte_o = '0;
    fmt_bit_o = '0;
    dct_wdata_hw_o = '0;
    ibi_queue_wdata_o = '0;
    ibi_queue_wvalid_o = 1'b0;
    resp_data_length_d = '0;
    resp_queue_wdata_o = '0;
    resp_err_status_d = resp_err_status_q;
    resp_desc.err_status = i3c_resp_err_status_e'(0);
    resp_desc.tid = '0;
    resp_desc.data_length = '0;
    rx_dword_array = rx_dword_q;
    ccc_done = 1'b0;
    assigned_addr_cnt_d = assigned_addr_cnt_q;
    dct_raw_data_d = dct_raw_data_q;
    daa_iteration_done = 1'b0;
    first_nack_d = 1'b1;
    dat_index_d = dat_index_q;
    dct_data = '0;
    dct_index_d = dct_index_q;
    broadcast_addr_enable_d = broadcast_addr_enable_q;
    use_ce2_error_handling_on_nack_d = use_ce2_error_handling_on_nack_q;
    icc_done = 1'b0;
    prev_cmd_toc_d = prev_cmd_toc_q;
    ibi_done = 1'b0;
    ibi_abort = 1'b0;
    ibi_status_d = ibi_status_q;
    ibi_data_d = ibi_data_q;
    ibi_wb_d = ibi_wb_q;
    ibi_wb_cnt_d = ibi_wb_cnt_q;
    rlt_dynamic_address = '0;
    rlt_req = 1'b0;
    ccc_last_trans = 1'b0;
    pio_transfer_err_stat = 1'b0;
    err_handled_d = 1'b0;
    fmt_flag_hdr_exit_o = 1'b0;
    ccc_ce0_first_retry_d = 1'b0;
    // Interrupts
    pio_transfer_abort_stat = 1'b0;
    hc_seq_cancel_stat = 1'b0;
    hc_err_cmd_seq_timeout_stat = 1'b0;
    unique case (state)
      // Idle: Wait for command appearance in the Command Queue
      Idle: begin
        i3c_fsm_idle_o = 1'b1;
      end
      // WaitForCmd: Fetch Command Descriptor
      WaitForCmd: begin
        cmd_queue_rready_o = 1'b0;
        if (pio_rs_i) begin
          cmd_queue_rready_o = 1'b1;
        end
      end
      // FetchAddr: Fetch DAT entry
      FetchAddr: begin
        dat_read_valid_hw_o = ~is_direct_transfer;
        dat_index_hw_o = $clog2(`DAT_DEPTH)'(dev_index);
      end
      // I2CWriteImmediate: Execute Immediate Transfer to Legacy I2C Device via I2C Controller
      I2CWriteImmediate: begin
        transfer_cnt_clr = 1'b0;
        transfer_cnt_en = fmt_fifo_rdone_i;
        fmt_fifo_rvalid_o = 1'b1;
        fmt_flag_start_before_o = 1'b0;
        fmt_flag_stop_after_o = 1'b0;
        resp_data_length_d = transfer_cnt_q;
        unique case (transfer_cnt_q)
          // TODO: #95752 Add support for broadcast address control before private transfers. This can
          // be realized via HC_CONTROL.I2C_DEV_PRESENT and HC_CONTROL.IBA_INCLUDE register fields.
          // 32'd0: fmt_byte_o = {7'h7e, 1'b0};
          // Target address
          32'd0: begin
            // I2C uses Static Address from the DAT
            fmt_byte_o = is_direct_transfer ? {immediate_direct_cmd_desc.dev_address, 1'b0} : {dat_rdata.static_address, 1'b0};
          end
          // Byte 1
          32'd1: begin
            fmt_byte_o = is_direct_transfer ? (imm_use_def_byte ? immediate_direct_cmd_desc.data_byte2
                                               : immediate_direct_cmd_desc.def_or_data_byte1) : 
                                              (imm_use_def_byte ? immediate_dat_cmd_desc.data_byte2
                                               : immediate_dat_cmd_desc.def_or_data_byte1);
          end
          // Byte 2
          32'd2: begin
            fmt_byte_o = is_direct_transfer ? (imm_use_def_byte ? immediate_direct_cmd_desc.data_byte3
                                               : immediate_direct_cmd_desc.data_byte2) : 
                                              (imm_use_def_byte ? immediate_dat_cmd_desc.data_byte3
                                               : immediate_dat_cmd_desc.data_byte2);
          end
          // Byte 3
          32'd3: begin
            fmt_byte_o = is_direct_transfer ? immediate_direct_cmd_desc.data_byte3 : immediate_dat_cmd_desc.data_byte3;
          end
          // Byte 4
          32'd4: begin
            fmt_byte_o = is_direct_transfer ? immediate_direct_cmd_desc.data_byte4 : immediate_dat_cmd_desc.data_byte4;
          end
          default: begin
            fmt_byte_o = '0;
          end
        endcase

        // Send start condition before first byte
        if (transfer_cnt_q == 0) begin
          fmt_flag_start_before_o = 1'b1;
        end
        // Send stop condition after last byte if TOC is set to STOP
        if (transfer_cnt_q == data_length + (BytesBeforeImmData)) begin
          fmt_flag_stop_after_o = is_direct_transfer ? immediate_direct_cmd_desc.toc : immediate_dat_cmd_desc.toc;
          fmt_flag_restart_after_o = is_direct_transfer ? ~immediate_direct_cmd_desc.toc : ~immediate_dat_cmd_desc.toc;
          prev_cmd_toc_d = ~fmt_flag_restart_after_o;
          if (fmt_fifo_rdone_i & fmt_flag_restart_after_o & ~cmd_queue_rvalid_i) begin
            fmt_flag_stop_after_o = 1'b1;
            fmt_flag_restart_after_o = 1'b0;
            hc_seq_cancel_stat = 1'b1;
            hc_err_cmd_seq_timeout_stat = 1'b1;
          end
          resp_err_status_d = Success;
        end
        // Disable FIFO valid whenever I2C Controller is not ready or an immediate transfer is finished
        if (fmt_fifo_rready_i && (transfer_cnt_q < data_length + 1 + BytesBeforeImmData)) begin
          fmt_fifo_rvalid_o = 1'b1;
        end
        if (fmt_receive_nack_i) begin
          resp_err_status_d = Nack;
        end
        if (abort_i) begin
          fmt_flag_stop_after_o = 1'b1;
          resp_err_status_d = HcAborted;
        end
      end
      // I3CWriteImmediate: Execute Immediate Transfer to I3C Device
      I3CWriteImmediate: begin
        // TODO: Figure out if the transfer should proceed if its DTT is set to `Defining Byte + 0`
        // since in such scenario it sends only a target device address. It might be better to just
        // report an error.
        transfer_cnt_clr = 1'b0;
        transfer_cnt_en = fmt_fifo_rdone_i;
        fmt_fifo_rvalid_o = 1'b1;
        fmt_flag_start_before_o = 1'b0;
        fmt_flag_stop_after_o = 1'b0;
        resp_data_length_d = transfer_cnt_q;
        fmt_bit_o = 1'b1;
        unique case (transfer_cnt_q)
          // TODO: #95752 Add support for broadcast address control before private transfers. This can
          // be realized via HC_CONTROL.I2C_DEV_PRESENT and HC_CONTROL.IBA_INCLUDE register fields.
          // 32'd0: fmt_byte_o = {7'h7e, 1'b0};
          // Target address
          32'd0: begin
            fmt_byte_o = is_direct_transfer ? {immediate_direct_cmd_desc.dev_address, 1'b0} : {dat_rdata.dynamic_address, 1'b0};

          end
          // Byte 1
          32'd1: begin
            fmt_byte_o = is_direct_transfer ? (imm_use_def_byte ? immediate_direct_cmd_desc.data_byte2
                                               : immediate_direct_cmd_desc.def_or_data_byte1) : 
                                              (imm_use_def_byte ? immediate_dat_cmd_desc.data_byte2
                                               : immediate_dat_cmd_desc.def_or_data_byte1);
            fmt_bit_o = ^{fmt_byte_o, 1'b1};
          end
          // Byte 2
          32'd2: begin
            fmt_byte_o = is_direct_transfer ? (imm_use_def_byte ? immediate_direct_cmd_desc.data_byte3
                                               : immediate_direct_cmd_desc.data_byte2) : 
                                              (imm_use_def_byte ? immediate_dat_cmd_desc.data_byte3
                                               : immediate_dat_cmd_desc.data_byte2);
            fmt_bit_o = ^{fmt_byte_o, 1'b1};
          end
          // Byte 3
          32'd3: begin
            fmt_byte_o = is_direct_transfer ? immediate_direct_cmd_desc.data_byte3 : immediate_dat_cmd_desc.data_byte3;
            fmt_bit_o = ^{fmt_byte_o, 1'b1};
          end
          // Byte 4
          32'd4: begin
            fmt_byte_o = is_direct_transfer ? immediate_direct_cmd_desc.data_byte4 : immediate_dat_cmd_desc.data_byte4;
            fmt_bit_o = ^{fmt_byte_o, 1'b1};
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
          fmt_flag_stop_after_o = is_direct_transfer ? immediate_direct_cmd_desc.toc : immediate_dat_cmd_desc.toc;
          fmt_flag_restart_after_o = is_direct_transfer ? ~immediate_direct_cmd_desc.toc : ~immediate_dat_cmd_desc.toc;
          prev_cmd_toc_d = ~fmt_flag_restart_after_o;
          if (fmt_fifo_rdone_i & fmt_flag_restart_after_o & ~cmd_queue_rvalid_i) begin
            fmt_flag_stop_after_o = 1'b1;
            fmt_flag_restart_after_o = 1'b0;
            hc_seq_cancel_stat = 1'b1;
            hc_err_cmd_seq_timeout_stat = 1'b1;
          end
          resp_err_status_d = Success;
        end
        // Disable FIFO valid whenever I2C Controller is not ready or an immediate transfer is finished
        if (fmt_fifo_rready_i && (transfer_cnt_q < data_length + 1 + BytesBeforeImmData)) begin
          fmt_fifo_rvalid_o = 1'b1;
        end
        if (fmt_receive_nack_i & fmt_fifo_rdone_i) begin
          resp_err_status_d   = Nack;
          fmt_flag_hdr_exit_o = use_ce2_error_handling_on_nack_q;
        end
        if (abort_i) begin
          fmt_flag_stop_after_o = 1'b1;
          resp_err_status_d = HcAborted;
        end
      end
      I3CWriteRegular: begin
        transfer_cnt_clr = 1'b0;
        transfer_cnt_en = fmt_fifo_rdone_i;
        fmt_fifo_rvalid_o = 1'b1;
        fmt_flag_start_before_o = 1'b0;
        fmt_flag_stop_after_o = 1'b0;
        resp_data_length_d = transfer_cnt_q;
        fmt_bit_o = 1'b1;
        tx_queue_rready_o = ((transfer_cnt_q % (HciTxDataWidth >> 3)) == 0) & transfer_cnt_en;

        if (transfer_cnt_q == 32'd0) begin : addr_assignment
          fmt_byte_o = is_direct_transfer ? {regular_direct_cmd_desc.dev_address, 1'b0} : {dat_rdata.dynamic_address, 1'b0};
          fmt_flag_start_before_o = 1'b1;
        end else begin
          fmt_byte_o = tx_dword_array[byte_select];
          fmt_bit_o  = ^{fmt_byte_o, 1'b1};
        end

        // Send stop signal
        if (transfer_cnt_q >= data_length) begin
          fmt_flag_stop_after_o = is_direct_transfer ? regular_direct_cmd_desc.toc : regular_dat_cmd_desc.toc;
          fmt_flag_restart_after_o = is_direct_transfer ? ~regular_direct_cmd_desc.toc : ~regular_dat_cmd_desc.toc;
          prev_cmd_toc_d = ~fmt_flag_restart_after_o;
          if (fmt_fifo_rdone_i & fmt_flag_restart_after_o & ~cmd_queue_rvalid_i) begin
            fmt_flag_stop_after_o = 1'b1;
            fmt_flag_restart_after_o = 1'b0;
            hc_seq_cancel_stat = 1'b1;
            hc_err_cmd_seq_timeout_stat = 1'b1;
          end
          tx_queue_rready_o = 1'b0;  // when we're done we don't want to pop new data from the queue
          resp_err_status_d = Success;  // successfull transfer without errors
        end

        // Error conditions
        if (tx_queue_rready_o && tx_queue_empty_i) begin
          resp_err_status_d = Ovl;
          fmt_flag_stop_after_o = 1'b1;
        end
        if (fmt_receive_nack_i & fmt_fifo_rdone_i) begin
          resp_err_status_d   = Nack;
          fmt_flag_hdr_exit_o = use_ce2_error_handling_on_nack_q;
        end
        if (abort_i) begin
          fmt_flag_stop_after_o = 1'b1;
          resp_err_status_d = HcAborted;
        end
      end
      I2CWriteRegular: begin
        transfer_cnt_clr = 1'b0;
        transfer_cnt_en = fmt_fifo_rdone_i;
        fmt_fifo_rvalid_o = 1'b1;
        fmt_flag_start_before_o = 1'b0;
        fmt_flag_stop_after_o = 1'b0;
        resp_data_length_d = transfer_cnt_q;
        fmt_bit_o = 1'b1;
        tx_queue_rready_o = ((transfer_cnt_q % (HciTxDataWidth >> 3)) == 0) & transfer_cnt_en;

        if (transfer_cnt_q == 32'd0) begin
          // I2C uses Static Address from the DAT
          fmt_byte_o = is_direct_transfer ? {regular_direct_cmd_desc.dev_address, 1'b0} : {dat_rdata.static_address, 1'b0};
          fmt_flag_start_before_o = 1'b1;
        end else begin
          fmt_byte_o = tx_dword_array[byte_select];
        end

        // Send stop signal
        if (transfer_cnt_q >= data_length) begin
          fmt_flag_stop_after_o = is_direct_transfer ? regular_direct_cmd_desc.toc : regular_dat_cmd_desc.toc;
          fmt_flag_restart_after_o = is_direct_transfer ? ~regular_direct_cmd_desc.toc : ~regular_dat_cmd_desc.toc;
          tx_queue_rready_o = 1'b0;  // when we're done we don't want to pop new data from the queue
          resp_err_status_d = Success;  // successfull transfer without errors
        end

        // Error conditions
        if (tx_queue_rready_o && tx_queue_empty_i) begin
          resp_err_status_d = Ovl;
          fmt_flag_stop_after_o = 1'b1;
        end
        if (fmt_receive_nack_i) begin
          resp_err_status_d = Nack;
        end
        if (abort_i) begin
          fmt_flag_stop_after_o = 1'b1;
          resp_err_status_d = HcAborted;
        end
      end
      I3CRead: begin
        transfer_cnt_clr = 1'b0;
        transfer_cnt_en = fmt_fifo_rdone_i | fmt_flag_read_valid_i;
        resp_data_length_d = (transfer_cnt_q == 0) ? '0 : transfer_cnt_q;
        fmt_flag_read_bytes_o = 1'b1;
        fmt_flag_stop_after_o = 1'b0;
        if (transfer_cnt_q == 32'd0) begin
          fmt_byte_o = is_direct_transfer ? {regular_direct_cmd_desc.dev_address, 1'b1} : {dat_rdata.dynamic_address, 1'b1};
          fmt_flag_start_before_o = 1'b1;
          fmt_fifo_rvalid_o = 1'b1;
        end else begin
          rx_dword_array = (byte_select == '0) & fmt_flag_read_valid_i ? '0 : rx_dword_q;  // reset each new word to 0
          if (fmt_flag_read_valid_i) begin
            rx_dword_array[byte_select] = fmt_byte_i;
          end
          if (((transfer_cnt_q) % (HciRxDataWidth >> 3)) == 0) begin
            rx_queue_wvalid_o = fmt_flag_read_valid_i;  // Send data to rx queue
            if (~rx_queue_wready_i & rx_queue_full_i & rx_queue_wvalid_o) begin
              resp_err_status_d = Ovl;
              rx_dword_array = '0;  // Reset the DWORD
              fmt_flag_stop_after_o = 1'b1;
            end
          end
        end

        if (transfer_cnt_q <= data_length & (~fmt_bit_i & fmt_flag_read_valid_i) & ~fmt_flag_stop_after_o) begin  // receive RX T bit
          fmt_flag_stop_after_o = 1'b1;
          resp_err_status_d = I3cShortReadErr;
          rx_dword_array[byte_select] = fmt_byte_i;
          rx_queue_wvalid_o = 1'b1; // send the uncompleted word to the RX queue when transaction is finished early
        end

        if (transfer_cnt_q >= data_length & fmt_flag_read_valid_i) begin
          fmt_flag_stop_after_o = is_direct_transfer ? regular_direct_cmd_desc.toc : regular_dat_cmd_desc.toc;
          fmt_flag_restart_after_o = is_direct_transfer ? ~regular_direct_cmd_desc.toc : ~regular_dat_cmd_desc.toc;
          prev_cmd_toc_d = ~fmt_flag_restart_after_o;
          if (fmt_fifo_rdone_i & fmt_flag_restart_after_o & ~cmd_queue_rvalid_i) begin
            fmt_flag_stop_after_o = 1'b1;
            fmt_flag_restart_after_o = 1'b0;
            hc_seq_cancel_stat = 1'b1;
            hc_err_cmd_seq_timeout_stat = 1'b1;
          end
          resp_err_status_d = Success;  // successfull transfer without errors
          rx_queue_wvalid_o = 1'b1; // send the uncompleted word to the RX queue when transaction is finished
        end

        if (fmt_receive_nack_i & fmt_fifo_rdone_i) begin
          resp_err_status_d = Nack;
          fmt_flag_hdr_exit_o = use_ce2_error_handling_on_nack_q;
          rx_queue_wvalid_o = 1'b1; // send the uncompleted word to the RX queue when transaction is finished
        end

        if (abort_i) begin
          fmt_flag_stop_after_o = 1'b1;
          resp_err_status_d = HcAborted;
        end
      end
      I2CRead: begin
        transfer_cnt_clr = 1'b0;
        transfer_cnt_en = fmt_fifo_rdone_i | rx_fifo_wvalid_i;
        resp_data_length_d = (transfer_cnt_q == 0) ? '0 : transfer_cnt_q - 1;
        fmt_flag_read_bytes_o = 1'b1;
        fmt_byte_o = data_length < 15'd256 ? data_length : '0; // fmt_byte_o contains the number of bytes to read, if it's 0 we read 256 bytes
        if (transfer_cnt_q == 32'd0) begin
          // I2C uses Static Address from the DAT
          fmt_byte_o = is_direct_transfer ? {regular_direct_cmd_desc.dev_address, 1'b1} : {dat_rdata.static_address, 1'b1};
          fmt_flag_start_before_o = 1'b1;
          fmt_flag_read_bytes_o = 1'b0;
          fmt_fifo_rvalid_o = 1'b1;
        end else begin
          rx_dword_array = (byte_select == '0) & rx_fifo_wvalid_i ? '0 : rx_dword_q;  // reset each new word to 0
          fmt_fifo_rvalid_o = 1'b1;
          if (rx_fifo_wvalid_i) begin
            rx_dword_array[byte_select] = rx_fifo_wdata_i;
          end
          if (((transfer_cnt_q) % (HciRxDataWidth >> 3)) == 0) begin
            rx_queue_wvalid_o = rx_fifo_wvalid_i;  // Send data to rx queue
            if (~rx_queue_wready_i & rx_queue_full_i & rx_queue_wvalid_o) begin
              resp_err_status_d = Ovl;
              rx_dword_array = '0;  // Reset the DWORD
              fmt_flag_stop_after_o = 1'b1;
            end
          end
        end

        if (transfer_cnt_q >= data_length) begin
          fmt_flag_read_continuous_o = 1'b0;
          fmt_flag_stop_after_o = is_direct_transfer ? regular_direct_cmd_desc.toc : regular_dat_cmd_desc.toc;
          fmt_flag_restart_after_o = is_direct_transfer ? ~regular_direct_cmd_desc.toc : ~regular_dat_cmd_desc.toc;
          prev_cmd_toc_d = ~fmt_flag_restart_after_o;
          if (fmt_fifo_rdone_i & fmt_flag_restart_after_o & ~cmd_queue_rvalid_i) begin
            fmt_flag_stop_after_o = 1'b1;
            fmt_flag_restart_after_o = 1'b0;
            hc_seq_cancel_stat = 1'b1;
            hc_err_cmd_seq_timeout_stat = 1'b1;
          end
          resp_err_status_d = Success;  // successfull transfer without errors
          rx_queue_wvalid_o = rx_fifo_wvalid_i;  // Send data to rx queue after transaction is done
        end

        if (abort_i) begin
          fmt_flag_stop_after_o = 1'b1;
          resp_err_status_d = HcAborted;
        end
      end
      StallWrite: begin
        // TODO: #95754 is this state ever needed?
      end
      StallRead: begin
        // TODO: #95754 is this state ever needed?
      end
      DirectCCC: begin
        transfer_cnt_clr = 1'b0;
        transfer_cnt_en = fmt_fifo_rdone_i | fmt_flag_read_valid_i;
        fmt_fifo_rvalid_o = 1'b1;
        ccc_last_trans = 1'b0;
        fmt_flag_start_before_o = 1'b0;
        fmt_flag_stop_after_o = 1'b0;
        resp_data_length_d = (transfer_cnt_q == 0) ? '0 : transfer_cnt_q - 1;
        ccc_done = 1'b0;
        fmt_bit_o = 1'b1;
        tx_queue_rready_o = 1'b0;
        ccc_ce0_first_retry_d = ccc_ce0_first_retry_q;
        unique case (transfer_cnt_q) inside
          32'd0: begin  // Broadcast Address
            fmt_byte_o = {7'h7E, 1'b0};
            fmt_flag_start_before_o = 1'b1;
            if (fmt_receive_nack_i) begin
              resp_err_status_d   = AddrHeader;
              fmt_flag_hdr_exit_o = 1'b1;  // CE2 recovery
            end
          end
          32'd1: begin  // Broadcast the CCC
            fmt_byte_o = cmd_ccc;
            fmt_bit_o = ^{fmt_byte_o, 1'b1};
            fmt_flag_restart_after_o = 1'b1;
            tx_queue_rready_o = is_regular_transfer & fmt_fifo_rdone_i; // Pop payload byte for next cycle
          end
          32'd2: begin  // Transmit Target Addr
            fmt_byte_o = is_direct_transfer ? (is_regular_transfer ? {regular_direct_cmd_desc.dev_address, cmd_dir == Read} 
                                             : {immediate_direct_cmd_desc.dev_address, cmd_dir == Read}) 
                                             : ((cmd_ccc == CCC_DIRECT_SETDASA) ? {dat_rdata.static_address, cmd_dir == Read} : {dat_rdata.dynamic_address, cmd_dir == Read});
            // SETDASA is the only CCC using the static address instead of the dynamic address
            tx_queue_rready_o = is_regular_transfer & fmt_fifo_rdone_i & (prev_ccc_q == cmd_ccc); // Pop payload byte for next cycle if we skipped sending 7'h7E and CCC bytes
            fmt_flag_read_bytes_o = fmt_fifo_rdone_i & (cmd_dir == Read);
            if (fmt_receive_nack_i) begin
              resp_err_status_d   = Nack;
              fmt_flag_hdr_exit_o = use_ce2_error_handling_on_nack_q;
            end
          end
          32'd3: begin  // Transmit the first Payload byte
            ccc_last_trans = ccc_has_one_byte_of_payload(cmd_ccc);
            ccc_done =  ccc_last_trans & transfer_cnt_en; // CCC is done if it only needs one payload byte
            if (is_regular_transfer) begin
              if (cmd_dir == Read) begin
                fmt_fifo_rvalid_o = 1'b0;
                fmt_flag_read_bytes_o = 1'b1;
                rx_dword_array = (ccc_byte_select == '0) & fmt_flag_read_valid_i ? '0 : rx_dword_q;  // reset each new word to 0
                if (fmt_flag_read_valid_i) begin
                  rx_dword_array[ccc_byte_select] = fmt_byte_i;
                end
                if (ccc_done) begin
                  rx_queue_wvalid_o = fmt_flag_read_valid_i;  // Send data to rx queue
                  if (~rx_queue_wready_i) begin
                    resp_err_status_d = Ovl;
                    fmt_flag_stop_after_o = 1'b1;
                  end
                end
                if (~ccc_done & (~fmt_bit_i & fmt_flag_read_valid_i)) begin  // receive RX T bit
                  fmt_flag_stop_after_o = 1'b1;
                  fmt_bit_o = 1'b0;
                  resp_err_status_d = I3cShortReadErr;
                  rx_dword_array[ccc_byte_select] = fmt_byte_i;
                  rx_queue_wvalid_o = 1'b1; // send the uncompleted word to the RX queue when transaction is finished early
                end
              end else begin
                fmt_byte_o = tx_dword_array[0];
                fmt_bit_o  = ^{fmt_byte_o, 1'b1};
              end
              if (ccc_last_trans) begin
                fmt_flag_stop_after_o = is_direct_transfer ? regular_direct_cmd_desc.toc : regular_dat_cmd_desc.toc;
                fmt_flag_restart_after_o = is_direct_transfer ? ~regular_direct_cmd_desc.toc : ~regular_dat_cmd_desc.toc;
                prev_cmd_toc_d = ~fmt_flag_restart_after_o;
                if (fmt_fifo_rdone_i & fmt_flag_restart_after_o & ~cmd_queue_rvalid_i) begin
                  fmt_flag_stop_after_o = 1'b1;
                  fmt_flag_restart_after_o = 1'b0;
                  hc_seq_cancel_stat = 1'b1;
                  hc_err_cmd_seq_timeout_stat = 1'b1;
                end
                resp_err_status_d = (cmd_ccc == CCC_DIRECT_SETDASA) ? NotSupported : Success;  // SETDASA is only supported with address assignment cmd desc
              end
            end else begin
              fmt_byte_o = (cmd_ccc == CCC_DIRECT_SETDASA) ? {dat_rdata.dynamic_address, 1'b0} : (is_direct_transfer ? immediate_direct_cmd_desc.def_or_data_byte1 : immediate_dat_cmd_desc.def_or_data_byte1);
              fmt_bit_o = ^{fmt_byte_o, 1'b1};
              if (ccc_last_trans) begin
                fmt_flag_stop_after_o = (cmd_ccc == CCC_DIRECT_SETDASA) ? addr_cmd_desc.toc : (is_direct_transfer ? immediate_direct_cmd_desc.toc : immediate_dat_cmd_desc.toc);
                fmt_flag_restart_after_o = (cmd_ccc == CCC_DIRECT_SETDASA) ? ~addr_cmd_desc.toc : (is_direct_transfer ? ~immediate_direct_cmd_desc.toc : ~immediate_dat_cmd_desc.toc);
                prev_cmd_toc_d = ~fmt_flag_restart_after_o;
                if (fmt_fifo_rdone_i & fmt_flag_restart_after_o & ~cmd_queue_rvalid_i) begin
                  fmt_flag_stop_after_o = 1'b1;
                  fmt_flag_restart_after_o = 1'b0;
                  hc_seq_cancel_stat = 1'b1;
                  hc_err_cmd_seq_timeout_stat = 1'b1;
                end
                resp_err_status_d = Success;  // successfull transfer without errors
              end
            end
          end
          [32'd4 : 32'd8]: begin
            if (is_regular_transfer) begin
              ccc_last_trans = is_direct_transfer ? (transfer_cnt_q == (regular_dat_cmd_desc.data_length + 2)) : (transfer_cnt_q == (regular_direct_cmd_desc.data_length + 2));
              ccc_done = ccc_last_trans & transfer_cnt_en;
              if (cmd_dir == Read) begin  // GET CCC
                fmt_flag_read_bytes_o = 1'b1;
                fmt_fifo_rvalid_o = 1'b0;
                rx_dword_array = (ccc_byte_select == '0) & fmt_flag_read_valid_i ? '0 : rx_dword_q;  // reset each new word to 0
                if (fmt_flag_read_valid_i) begin
                  rx_dword_array[ccc_byte_select] = fmt_byte_i;
                end
                if (((transfer_cnt_q - 2) % (HciRxDataWidth >> 3)) == 0) begin
                  rx_queue_wvalid_o = fmt_flag_read_valid_i;  // Send data to rx queue
                  if (~rx_queue_wready_i) begin
                    resp_err_status_d = Ovl;
                    fmt_flag_stop_after_o = 1'b1;
                  end
                end
                if (~ccc_done & (~fmt_bit_i & fmt_flag_read_valid_i)) begin  // receive RX T bit
                  fmt_flag_stop_after_o = 1'b1;
                  fmt_bit_o = 1'b0;
                  if (ccc_ce0_first_retry_q) begin
                    resp_err_status_d = I3cShortReadErr;
                    rx_dword_array[ccc_byte_select] = fmt_byte_i;
                    rx_queue_wvalid_o = 1'b1; // send the uncompleted word to the RX queue when transaction is finished early
                    ccc_done = 1'b1;
                  end else begin  // retry the CCC
                    transfer_cnt_clr = 1'b1;
                    ccc_ce0_first_retry_d = 1'b1;
                    rx_dword_array = '0;  // reset the received data
                  end
                end
              end
              if (ccc_last_trans) begin
                fmt_flag_stop_after_o = is_direct_transfer ? regular_direct_cmd_desc.toc : regular_dat_cmd_desc.toc;
                rx_queue_wvalid_o = fmt_flag_read_valid_i;  // Send data to rx queue even if DWORD is not full
                fmt_flag_restart_after_o = is_direct_transfer ? ~regular_direct_cmd_desc.toc : ~regular_dat_cmd_desc.toc;
                prev_cmd_toc_d = ~fmt_flag_restart_after_o;
                if (fmt_fifo_rdone_i & fmt_flag_restart_after_o & ~cmd_queue_rvalid_i) begin
                  fmt_flag_stop_after_o = 1'b1;
                  fmt_flag_restart_after_o = 1'b0;
                  hc_seq_cancel_stat = 1'b1;
                  hc_err_cmd_seq_timeout_stat = 1'b1;
                end
                fmt_bit_o = 1'b0;
                resp_err_status_d = Success;
              end
            end else begin
              // Should not use immediate transfer descriptors for GET CCCs
              ccc_done = 1'b1;
              resp_err_status_d = NotSupported;
            end
          end
          default: begin
            resp_err_status_d = HcAborted;
          end
        endcase
        if (abort_i) begin
          fmt_flag_stop_after_o = 1'b1;
          resp_err_status_d = HcAborted;
        end
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
            if (fmt_receive_nack_i) begin
              resp_err_status_d   = AddrHeader;
              fmt_flag_hdr_exit_o = 1'b1;  // CE2 recovery
            end
          end
          32'd1: begin  // Broadcast the CCC
            fmt_byte_o = cmd_ccc;
            fmt_bit_o = ^{fmt_byte_o, 1'b1};
            fmt_flag_stop_after_o = ~ccc_has_payload & ((is_regular_transfer & ((is_direct_transfer & regular_direct_cmd_desc.toc) | (~is_direct_transfer & regular_dat_cmd_desc.toc)))
                                   | (~is_regular_transfer & ((is_direct_transfer & immediate_direct_cmd_desc.toc) | (~is_direct_transfer & immediate_dat_cmd_desc.toc))));
            fmt_flag_restart_after_o = ~ccc_has_payload & ((is_regular_transfer & ((is_direct_transfer & ~regular_direct_cmd_desc.toc) | (~is_direct_transfer & ~regular_dat_cmd_desc.toc)))
                                   | (~is_regular_transfer & ((is_direct_transfer & ~immediate_direct_cmd_desc.toc) | (~is_direct_transfer & ~immediate_dat_cmd_desc.toc))));
            prev_cmd_toc_d = ~fmt_flag_restart_after_o;
            if (fmt_fifo_rdone_i & fmt_flag_restart_after_o & ~cmd_queue_rvalid_i) begin
              fmt_flag_stop_after_o = 1'b1;
              fmt_flag_restart_after_o = 1'b0;
              hc_seq_cancel_stat = 1'b1;
              hc_err_cmd_seq_timeout_stat = 1'b1;
            end

            tx_queue_rready_o = is_regular_transfer & fmt_fifo_rdone_i; // Pop payload byte for next cycle
            ccc_done = ~ccc_has_payload & fmt_fifo_rdone_i;
          end
          32'd2: begin  // Transmit the first Payload byte
            ccc_done = ((cmd_ccc == CCC_BCAST_ENEC) | (cmd_ccc == CCC_BCAST_DISEC)) & fmt_fifo_rdone_i;
            if (is_regular_transfer) begin
              fmt_byte_o = tx_dword_array[0];
              fmt_bit_o = ^{fmt_byte_o, 1'b1};
              // TODO: #95745 when we have more than one payload byte this should not
              // be set
              fmt_flag_stop_after_o = is_direct_transfer ? regular_direct_cmd_desc.toc : regular_dat_cmd_desc.toc;
              fmt_flag_restart_after_o = is_direct_transfer ? ~regular_direct_cmd_desc.toc : ~regular_dat_cmd_desc.toc;
              prev_cmd_toc_d = ~fmt_flag_restart_after_o;
              if (fmt_fifo_rdone_i & fmt_flag_restart_after_o & ~cmd_queue_rvalid_i) begin
                fmt_flag_stop_after_o = 1'b1;
                fmt_flag_restart_after_o = 1'b0;
                hc_seq_cancel_stat = 1'b1;
                hc_err_cmd_seq_timeout_stat = 1'b1;
              end
            end else begin
              fmt_byte_o = is_direct_transfer ? immediate_direct_cmd_desc.def_or_data_byte1 : immediate_dat_cmd_desc.def_or_data_byte1;
              fmt_bit_o = ^{fmt_byte_o, 1'b1};
              // TODO: #95745 when we have more than one payload byte this should not
              // be set
              fmt_flag_stop_after_o = is_direct_transfer ? immediate_direct_cmd_desc.toc : immediate_dat_cmd_desc.toc;
              fmt_flag_restart_after_o = is_direct_transfer ? ~immediate_direct_cmd_desc.toc : ~immediate_dat_cmd_desc.toc;
              prev_cmd_toc_d = ~fmt_flag_restart_after_o;
              if (fmt_fifo_rdone_i & fmt_flag_restart_after_o & ~cmd_queue_rvalid_i) begin
                fmt_flag_stop_after_o = 1'b1;
                fmt_flag_restart_after_o = 1'b0;
                hc_seq_cancel_stat = 1'b1;
                hc_err_cmd_seq_timeout_stat = 1'b1;
              end
            end
          end
          32'd3: begin
            // TODO: #95745 implement broadcast CCC with more than one payload byte
          end
          default: begin
            resp_err_status_d = HcAborted;
          end
        endcase
        if (ccc_done) begin
          resp_err_status_d = Success;  // successfull transfer without errors
        end
        if (abort_i) begin
          fmt_flag_stop_after_o = 1'b1;
          resp_err_status_d = HcAborted;
        end

      end
      DynamicAddrAssignment: begin
        transfer_cnt_clr = 1'b0;
        transfer_cnt_en = fmt_fifo_rdone_i | fmt_flag_read_valid_i;
        fmt_fifo_rvalid_o = 1'b1;
        fmt_flag_start_before_o = 1'b0;
        fmt_flag_stop_after_o = 1'b0;
        fmt_flag_restart_after_o = 1'b0;
        resp_data_length_d = (transfer_cnt_q == 0) ? '0 : transfer_cnt_q - 1;
        ccc_done = 1'b0;
        fmt_bit_o = 1'b1;
        assigned_addr_cnt_d = assigned_addr_cnt_q;
        dct_raw_data_d = dct_raw_data_q;
        first_nack_d = first_nack_q;
        daa_iteration_done = 1'b0;

        if (~addr_cmd_desc.wroc | ~addr_cmd_desc.toc | (addr_cmd_desc.dev_count == 0)) begin // CMD Desc violates format specified in I3C HCI Spec
          resp_err_status_d = NotSupported;
          ccc_done = 1'b1;
        end

        unique case (transfer_cnt_q) inside
          32'd0: begin  // Broadcast Address
            dat_index_d = $clog2(`DAT_DEPTH)'(dev_index);
            fmt_byte_o = {7'h7E, 1'b0};
            fmt_flag_start_before_o = 1'b1;
            if (fmt_fifo_rdone_i && fmt_receive_nack_i) begin
              resp_err_status_d   = AddrHeader;
              fmt_flag_hdr_exit_o = 1'b1;  // CE2 recovery
            end
          end
          32'd1: begin  // CCC Byte
            fmt_byte_o = cmd_ccc;
            fmt_bit_o = ^{fmt_byte_o, 1'b1};
            fmt_flag_restart_after_o = 1'b1;
          end
          32'd2: begin  // Start DAA
            fmt_byte_o = {7'h7E, 1'b1};  // Important: RnW = 1 for DAA
            fmt_flag_read_continuous_o = 1'b1;
            if (fmt_fifo_rdone_i && fmt_receive_nack_i) begin  // we are done
              ccc_done = 1'b1;
              fmt_flag_stop_after_o = 1'b1;
              if(assigned_addr_cnt_q == addr_cmd_desc.dev_count) begin // we've successfully assigned all addresses
                resp_err_status_d  = Success;
                resp_data_length_d = '0;  // no remaining target devices
              end else begin
                resp_err_status_d = Success;
                resp_data_length_d = addr_cmd_desc.dev_count - assigned_addr_cnt_q;  // still some target devices without a dynamic address
              end
            end else if (fmt_fifo_rdone_i && (assigned_addr_cnt_q >= addr_cmd_desc.dev_count)) begin // there are more devices still on the bus
              ccc_done = 1'b1;
              resp_err_status_d = Success;
              resp_data_length_d = 16'd1; // according to I3C HCI Spec this indicates that at least 1 device has not yet been assigned a dynamic address
            end
          end
          [32'd3 : 32'd10]: begin  // Read device characteristics
            fmt_flag_read_continuous_o = (transfer_cnt_q == 32'd10) && fmt_flag_read_valid_i ? 1'b0 : 1'b1;
            dct_raw_data_d[(transfer_cnt_q-3)] = fmt_flag_read_valid_i ? fmt_byte_i : dct_raw_data_q[(transfer_cnt_q-3)];
          end
          32'd11: begin  // Send dynamic address and parity bit
            fmt_byte_o = {dat_rdata.dynamic_address, ^{dat_rdata.dynamic_address, 1'b1}};
            fmt_flag_restart_after_o = 1'b1;
            if (fmt_fifo_rdone_i) begin
              daa_iteration_done = 1'b1;
              transfer_cnt_en = 1'b0;  // we need to disable transfer_cnt incrementing
              if (fmt_receive_nack_i) begin
                if (first_nack_q) begin // according to I3C Basic Spec the target gets 2 attempts to ACK the assigned dyn addr
                  fmt_flag_restart_after_o = 1'b1;
                  first_nack_d = 1'b0;
                end else begin
                  fmt_flag_stop_after_o = 1'b1;
                  fmt_flag_restart_after_o = 1'b0;
                  ccc_done = 1'b1;
                  resp_err_status_d = Nack;
                  fmt_flag_hdr_exit_o = use_ce2_error_handling_on_nack_q;
                  first_nack_d = 1'b1;
                end
              end else begin  // we have successfully assigned a dynamic address
                assigned_addr_cnt_d = assigned_addr_cnt_q + 1;

                // Populate DCT entry
                dct_data.pid_lo = {dct_raw_data_q[0], dct_raw_data_q[1]};
                dct_data.pid_hi = {
                  dct_raw_data_q[2], dct_raw_data_q[3], dct_raw_data_q[4], dct_raw_data_q[5]
                };
                dct_data.bcr = dct_raw_data_q[6];
                dct_data.dcr = dct_raw_data_q[7];
                dct_data.dynamic_address = {
                  dat_rdata.dynamic_address, ^{dat_rdata.dynamic_address, 1'b1}
                };
                dct_wdata_hw_o = dct_data;
                dct_write_valid_hw_o = 1'b1;
                dct_index_d = dct_index_q + 1; // note the new index is used after we write the dct entry

                // Fetch next DAT entry
                dat_read_valid_hw_o = 1'b1;
                dat_index_hw_o = dat_index_q + 1;

              end
            end
          end

          default: begin
            resp_err_status_d = AbortedWithCRC;
          end
        endcase

        if (abort_i) begin
          fmt_flag_stop_after_o = 1'b1;
          resp_err_status_d = HcAborted;
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
      // InternalControlCommand: Controls the Host Controller itself (not I3C
      // Transfer Command)
      InternalControlCommand: begin
        icc_done = 1'b0;
        unique case (internal_ctrl_cmd_desc.mipi_cmd)
          BrodcastAddressEnable: begin
            broadcast_addr_enable_d = cmd_desc[12];  // See Table 137 I3C HCI Spec
            icc_done = 1'b1;
          end
          CtrlSDARecoveryOrBusReset: begin
            unique case (internal_ctrl_cmd_desc[15:12]) // subcommand REC_RESET_PROC see Table 140 I3C HCI Spec
              4'h5: begin
                // Use CE2 error handling for a non-responsive I3C Target, by
                // sending HDR Exit Pattern after NACK of Private read/write
                use_ce2_error_handling_on_nack_d = 1'b1;
                icc_done = 1'b1;
              end
              // TODO: #95755 add support for all REC_RESET_PROC
              default: begin
                icc_done = 1'b1;
              end
            endcase
          end
          // TODO: #95756 add more cases of subcommands
          default: begin
            icc_done = 1'b1;
          end
        endcase
      end

      // I3CBcastHeader: sends I3C Broadcast Header if flag is set
      I3CBcastHeader: begin
        fmt_fifo_rvalid_o = 1'b1;
        fmt_flag_start_before_o = 1'b1;
        fmt_flag_stop_after_o = 1'b0;
        fmt_flag_restart_after_o = 1'b1;
        fmt_byte_o = {7'h7E, 1'b0};
        if (fmt_fifo_rdone_i && fmt_receive_nack_i) begin
          resp_err_status_d   = AddrHeader;
          fmt_flag_hdr_exit_o = 1'b1;  // CE2 recovery
        end
        if (abort_i) begin
          fmt_flag_stop_after_o = 1'b1;
          resp_err_status_d = HcAborted;
        end
      end
      IBI: begin
        fmt_flag_read_bytes_o = 1'b1;
        transfer_cnt_clr = 1'b0;
        transfer_cnt_en = fmt_fifo_rdone_i | fmt_flag_read_valid_i;
        fmt_fifo_rvalid_o = 1'b1;
        fmt_flag_start_before_o = 1'b0;
        fmt_flag_stop_after_o = 1'b0;
        fmt_flag_restart_after_o = 1'b0;
        ibi_data_d = ibi_data_q;
        ibi_abort = dat_rdata.ibi_reject | ~dat_rdata.ibi_payload;
        rlt_req = 1'b0;
        if (~ibi_wb_q) begin
          if (transfer_cnt_q == '0) begin
            ibi_wb_cnt_d = '0;
            fmt_flag_read_bytes_o = 1'b1;  // read dynamic address
            fmt_bit_o = 1'b0;
            ibi_status_d.ibi_sts = 1'b0;
            ibi_status_d.error = 1'b0;
            ibi_status_d.status_type = RegularIBI;
            ibi_status_d.ts = 1'b0;
            ibi_status_d.last_status = 1'b1; // TODO: #95758 some IBIs require multiple IBI status desc according to HCI Spec
            if (ibi_abort) begin
              fmt_flag_stop_after_o = 1'b1;
              fmt_flag_read_bytes_o = 1'b0;
              fmt_bit_o = 1'b1;  // NACK the dynamic address
              ibi_status_d.ibi_sts = 1'b1;
              ibi_wb_d = fmt_fifo_rdone_i;
            end
            ibi_status_d.ibi_id = fmt_flag_read_valid_i ? fmt_byte_i : ibi_status_q.ibi_id;
            rlt_req = fmt_flag_read_valid_i;
            rlt_dynamic_address = fmt_flag_read_valid_i ? 7'(fmt_byte_i >> 1) : 7'h0;
            // Fetch DAT for next cycle
            dat_index_hw_o = rlt_dat_index;
            dat_read_valid_hw_o = rlt_valid;
            transfer_cnt_en = fmt_fifo_rdone_i;
          end else begin
            if (transfer_cnt_q == (IBIBufferDepthDwords << 2)) begin
              fmt_flag_stop_after_o = 1'b1;
              ibi_status_d.error = 1'b1; // NOTE: if the target sends the max amount of bytes the controller will still abort it and report an error (even though it's technically not an error)
            end
            if (fmt_flag_read_valid_i) begin
              if (((transfer_cnt_q - 1) >> 2) < IBIBufferDepthDwords) begin
                ibi_status_d.data_length = ibi_status_q.data_length + 1;
                ibi_wb_d = ~fmt_bit_i;
                fmt_flag_stop_after_o = ~fmt_bit_i;
                ibi_data_d[ibi_dword_select][ibi_byte_select] = fmt_byte_i;
              end else begin  // Internal IBI buffer overflow
                ibi_status_d.error = 1'b1;
                fmt_flag_stop_after_o = 1'b1;
                ibi_wb_d = 1'b1;
                ibi_wb_cnt_d = '0;
              end
            end
          end
        end else begin  // Write Back the IBI Status + Payload to IBI Queue
          if (ibi_queue_wready_i) begin
            if (ibi_wb_cnt_q == '0) begin  // First entry is the IBI Status Descriptor
              ibi_queue_wdata_o  = ibi_status_q;
              ibi_queue_wvalid_o = 1'b1;
            end else if (ibi_wb_cnt_q < ((ibi_status_q.data_length + 3) >> 2)) begin
              ibi_queue_wdata_o  = ibi_data_q[ibi_wb_cnt_q-1];
              ibi_queue_wvalid_o = 1'b1;
            end else begin  // Wrote back all data
              ibi_queue_wdata_o = ibi_data_q[ibi_wb_cnt_q-1];
              ibi_queue_wvalid_o = 1'b1;
              ibi_done = 1'b1;
              ibi_wb_cnt_d = '0;
              ibi_wb_d = 1'b0;
            end
            ibi_wb_cnt_d = ibi_queue_wvalid_o ? ibi_wb_cnt_q + 1 : ibi_wb_cnt_q; // increment writeback counter upon successfull write
          end
        end
        if (abort_i) begin
          fmt_flag_stop_after_o = 1'b1;
          resp_err_status_d = HcAborted;
        end
      end
      Error: begin
        pio_transfer_err_stat = ~err_handled_q;
        err_handled_d = err_handled_q;
        resp_err_status_d = resp_err_status_q;
        unique case (resp_err_status_q)
          Crc: begin
            // TODO: implement
          end
          Parity: begin
            // TODO: implement
          end
          Frame: begin
            // TODO: implement
          end
          AddrHeader: begin
            // Error Type CE 2 requires generating HDR Exit pattern
            fmt_flag_hdr_exit_o = 1'b1;
            if (fmt_fifo_rdone_i) begin
              err_handled_d = 1'b1;  // hdr exit pattern was sent
              resp_err_status_d = AbortedWithCRC;
            end
          end
          Nack: begin
            if (use_ce2_error_handling_on_nack_q) begin
              fmt_flag_hdr_exit_o = 1'b1;
              if (fmt_fifo_rdone_i) begin
                err_handled_d = 1'b1;  // hdr exit pattern was sent
                resp_err_status_d = AbortedWithCRC;
              end
            end
          end
          Ovl: begin
            err_handled_d = 1'b1;  // Nothing to handle by the Controller
            resp_err_status_d = AbortedWithCRC;
          end
          I3cShortReadErr: begin
            err_handled_d = 1'b1;  // Nothing to handle by the Controller
            resp_err_status_d = I3cShortReadErr;
          end
          HcAborted: begin
            pio_transfer_abort_stat = 1'b1;
            if (~abort_i) begin
              err_handled_d = 1'b1;
              resp_err_status_d = AbortedWithCRC;
              pio_transfer_abort_stat = 1'b0;
            end
          end
          I2cDataNackOrI3cBusAborted: begin
            // TODO: implement
          end
          NotSupported: begin
            // TODO: implement
          end
          AbortedWithCRC: begin
            // TODO: implement
          end
          default: begin
            // We land in this case when a cmd seq error happens
            err_handled_d = 1'b1;
          end
        endcase
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
        if (~cmd_queue_empty_i & cmd_queue_rvalid_i & cmd_queue_rready_o) begin
          state_next = FetchAddr;
        end
      end
      // FetchAddr: Fetch target address, either from DAT or from cmd_desc
      FetchAddr: begin
        if (is_direct_transfer) begin
          unique case (cmd_attr)
            ImmediateDataTransferDirect: begin
              state_next = cmd_is_ccc & fmt_fifo_rready_i ? (cmd_is_broadcast_ccc ? BroadcastCCC : DirectCCC) :
                           i2c_cmd & fmt_fifo_rready_i ? I2CWriteImmediate :
                           (fmt_fifo_rready_i ? ((broadcast_addr_enable_q & prev_cmd_toc_q) ? I3CBcastHeader : I3CWriteImmediate) : state);
            end
            RegularTransferDirect: begin
              state_next = cmd_is_ccc & fmt_fifo_rready_i ? (cmd_is_broadcast_ccc ? BroadcastCCC : DirectCCC) :
                           i2c_cmd & fmt_fifo_rready_i ? ((cmd_dir == Read) ? I2CRead : I2CWriteRegular) : 
                           ((broadcast_addr_enable_q & prev_cmd_toc_q) ? I3CBcastHeader : 
                          (cmd_dir == Read) ? I3CRead : (fmt_fifo_rready_i ? I3CWriteRegular : state));
            end
            ComboTransferDirect: begin
              // TODO: #95759 implement combo transfer command descriptor
            end
            InternalControl: begin
              state_next = InternalControlCommand;
            end
            default: state_next = state;  // Stall
          endcase
        end else begin
          if (dat_captured) begin
            unique case (cmd_attr)
              ImmediateDataTransferDAT: begin
                state_next = cmd_is_ccc & fmt_fifo_rready_i ? (cmd_is_broadcast_ccc ? BroadcastCCC : DirectCCC) :
                           i2c_cmd & fmt_fifo_rready_i ? I2CWriteImmediate :
                           (fmt_fifo_rready_i ? ((broadcast_addr_enable_q & prev_cmd_toc_q) ? I3CBcastHeader : I3CWriteImmediate) : state);
              end
              RegularTransferDAT: begin
                state_next = cmd_is_ccc & fmt_fifo_rready_i ? (cmd_is_broadcast_ccc ? BroadcastCCC : DirectCCC) :
                           i2c_cmd & fmt_fifo_rready_i ? ((cmd_dir == Read) ? I2CRead : I2CWriteRegular) : 
                          ((broadcast_addr_enable_q & prev_cmd_toc_q) ? I3CBcastHeader : 
                          (cmd_dir == Read) ? I3CRead : (fmt_fifo_rready_i ? I3CWriteRegular : state));
              end
              ComboTransferDAT: begin
                // TODO: #95759 implement combo transfer command descriptor
              end
              AddressAssignment: begin
                state_next = fmt_fifo_rready_i ? (cmd_ccc == CCC_DIRECT_SETDASA ? DirectCCC : DynamicAddrAssignment) : state;
              end
              default: state_next = state;  // Stall
            endcase
          end
        end
      end
      // I2CWriteImmediate: Execute Immediate Transfer to Legacy I2C Device via I2C Controller
      I2CWriteImmediate: begin
        if (fmt_receive_nack_i) begin
          state_next = WriteResp;
        end else if ((transfer_cnt_q >= data_length + BytesBeforeImmData) && fmt_fifo_rdone_i) begin
          state_next = immediate_direct_cmd_desc.wroc ? WriteResp : Idle;
        end
      end
      // I3CWriteImmediate: Execute Immediate Transfer to I3C Device
      I3CWriteImmediate: begin
        if (fmt_receive_nack_i & fmt_fifo_rdone_i) begin
          state_next = WriteResp;
        end else if ((transfer_cnt_q >= data_length + BytesBeforeImmData) && fmt_fifo_rdone_i) begin
          state_next = immediate_direct_cmd_desc.wroc ? WriteResp : Idle;
        end
      end
      I2CWriteRegular: begin
        if (fmt_receive_nack_i) begin
          state_next = WriteResp;
        end else if ((transfer_cnt_q >= data_length) && fmt_fifo_rdone_i) begin
          state_next = regular_direct_cmd_desc.wroc ? WriteResp : Idle;
        end
        if (tx_queue_empty_i && tx_queue_rready_o) begin
          state_next = WriteResp;
        end
      end
      I3CWriteRegular: begin
        if (fmt_receive_nack_i & fmt_fifo_rdone_i) begin
          state_next = WriteResp;
        end else if ((transfer_cnt_q >= data_length) && fmt_fifo_rdone_i) begin
          state_next = regular_direct_cmd_desc.wroc ? WriteResp : Idle;
        end
        if (tx_queue_empty_i && tx_queue_rready_o) begin
          state_next = WriteResp;
        end
      end
      I3CRead: begin
        if (rx_queue_full_i & rx_queue_wvalid_o) begin  // OVL condition
          state_next = WriteResp;
        end else if (fmt_receive_nack_i & fmt_fifo_rdone_i) begin
          state_next = WriteResp;
        end else if (transfer_cnt_q >= data_length & fmt_flag_read_valid_i) begin
          state_next = regular_direct_cmd_desc.wroc ? WriteResp : Idle;
        end else if (transfer_cnt_q < data_length & (~fmt_bit_i & fmt_flag_read_valid_i)) begin  // receive RX T bit
          state_next = regular_direct_cmd_desc.sre ? WriteResp : Idle;
        end
      end
      I2CRead: begin
        if (rx_queue_full_i & rx_queue_wvalid_o) begin  // OVL condition
          state_next = WriteResp;
        end else if (fmt_receive_nack_i) begin
          state_next = WriteResp;
        end else if (transfer_cnt_q >= data_length & fmt_fifo_rready_i) begin
          state_next = regular_direct_cmd_desc.wroc ? WriteResp : Idle;
        end
      end
      StallWrite: begin
        // TODO: #95754 is this state ever needed?
      end
      StallRead: begin
        // TODO: #95754 is this state ever needed?
      end
      DirectCCC: begin
        if (ccc_done) begin
          state_next = (~is_regular_transfer & immediate_direct_cmd_desc.wroc) ? WriteResp : 
                       (is_regular_transfer & regular_direct_cmd_desc.wroc)    ? WriteResp : Idle;
        end else if (fmt_receive_nack_i & fmt_fifo_rdone_i) begin
          state_next = WriteResp;
        end
        if (rx_queue_full_i & rx_queue_wvalid_o) begin  // OVL condition
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
        if (rx_queue_full_i & rx_queue_wvalid_o) begin  // OVL condition
          state_next = WriteResp;
        end
      end
      DynamicAddrAssignment: begin
        if (ccc_done) begin
          state_next = WriteResp;
        end
      end
      // WriteResp: Generate Response Descriptor and load it to Response Queue
      WriteResp: begin
        if (resp_queue_wready_i) begin
          state_next = (resp_err_status_q != Success) ? Error : Idle; // Wait in the error state upon sending an error to the driver
          if (halt_on_cmd_seq_timeout_i & ~prev_cmd_toc_q & ~cmd_queue_rvalid_i) begin  // CMD Seq timeout
            state_next = Error;
          end
        end
      end
      // InternalControlCommand: Controls the Host Controller itself (not I3C
      // Transfer Command)
      InternalControlCommand: begin
        if (icc_done) begin
          state_next = Idle;
          // TODO: #95756 some ICCs require a response, switch to WriteResp state for
          // these once they are implemented
        end
      end
      // I3CBcastHeader: sends I3C Broadcast Header if flag is set
      I3CBcastHeader: begin
        if (fmt_fifo_rdone_i) begin
          if (fmt_receive_nack_i) begin  // AddrHeader error
            state_next = WriteResp;
          end else begin
            unique case (cmd_attr)
              ImmediateDataTransferDirect: begin
                state_next = I3CWriteImmediate;
              end
              RegularTransferDirect: begin
                state_next = (cmd_dir == Read) ? I3CRead : I3CWriteRegular;
              end
              ImmediateDataTransferDAT: begin
                state_next = I3CWriteImmediate;
              end
              RegularTransferDAT: begin
                state_next = (cmd_dir == Read) ? I3CRead : I3CWriteRegular;
              end
              default: state_next = state;  // Stall
            endcase
          end
        end
      end
      IBI: begin
        if (ibi_done) begin
          state_next = Idle;
        end
      end
      Error: begin
        if (~resume_i & err_handled_q) begin  // the driver has cleared the RESUME field in the HC_CONTROL CSR.
          state_next = Idle;
        end
      end
      default: begin
        state_next = Idle;
      end
    endcase
    if (fmt_sda_arbitration_i) begin
      state_next = IBI;
    end
    if (abort_i & fmt_fifo_rready_i & (state != WriteResp) & (state != Error)) begin // wait for the i3c_controller_fsm to issue stop and go back to idle
      state_next = WriteResp;
    end
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

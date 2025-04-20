module ccc_entdaa
    import controller_pkg::*;
    import i3c_pkg::*;
(
    input logic clk_i,  // Clock
    input logic rst_ni, // Async reset, active low
    input logic [47:0] id_i,
    input logic [7:0] dcr_i,
    input logic [7:0] bcr_i,

    input logic start_daa_i,
    output logic done_daa_o,

    // Bus RX interface
    input logic [7:0] bus_rx_data_i,
    input logic bus_rx_done_i,
    output logic bus_rx_req_bit_o,
    output logic bus_rx_req_byte_o,

    // Bus TX interface
    input logic bus_tx_done_i,
    output logic bus_tx_req_byte_o,
    output logic bus_tx_req_bit_o,
    output logic [7:0] bus_tx_req_value_o,
    output logic bus_tx_sel_od_pp_o,

    // Bus Monitor interface
    input logic bus_rstart_det_i,
    input logic bus_stop_det_i,

    // bus access
    input logic arbitration_lost_i,

    // addr
    output logic [6:0] address_o,
    output logic address_valid_o
);


  typedef enum logic [7:0] {
    Idle = 'h0,
    WaitStart = 'h1,
    ReceiveRsvdByte = 'h2,
    AckRsvdByte = 'h3,
    SendNack = 'h4,
    SendID = 'h5,
    PrepareIDBit = 'h6,
    SendIDBit = 'h7,
    LostArbitration = 'h8,
    ReceiveAddr = 'h9,
    AckAddr = 'ha,
    Done = 'hb,
    Error = 'hc
  } state_e;

  state_e state_q, state_d;
  logic [6:0] id_bit_count;
  logic load_id_counter, tick_id_counter;
  logic reserved_word_det;

  logic [63:0] device_id;
  logic calculated_parity;
  logic parity_ok;

  assign reserved_word_det = (bus_rx_data_i[7:1] == 7'h7e && bus_rx_data_i[0] == 1'b1);
  assign device_id = {id_i, bcr_i, dcr_i};
  assign calculated_parity = ~(bus_rx_data_i[7] ^ bus_rx_data_i[6] ^ bus_rx_data_i[5] ^ bus_rx_data_i[4] ^ bus_rx_data_i[3] ^ bus_rx_data_i[2] ^ bus_rx_data_i[1]);
  assign parity_ok = (calculated_parity == bus_rx_data_i[0]);
  assign done_daa_o = (state_q == Done);

  always_ff @(posedge clk_i or negedge rst_ni) begin: id_bit_counter
    if (!rst_ni) begin
      id_bit_count <= '0;
    end else begin
      if (load_id_counter) begin
        id_bit_count <= 7'd64;
      end else if (tick_id_counter) begin
        id_bit_count <= id_bit_count - 1'b1;
      end else begin
        id_bit_count <= id_bit_count;
      end
    end
  end

  always_comb begin: state_functions
    state_d = state_q;
    unique case (state_q)
      Idle: begin
        if (start_daa_i) begin
          state_d = WaitStart;
        end
      end
      WaitStart: begin
        if (bus_rstart_det_i) begin
          state_d = ReceiveRsvdByte;
        end
      end
      ReceiveRsvdByte: begin
        if (bus_rx_done_i) begin
          if (reserved_word_det) state_d = AckRsvdByte;
          else state_d = SendNack;
        end
      end
      AckRsvdByte: begin
        if (bus_tx_done_i) begin
    	  state_d = SendID;
    	end
      end
      SendNack: begin
        if (bus_tx_done_i) begin
          state_d = Error;
    	end
      end
      SendID: begin
        // load ID counter
        state_d = PrepareIDBit;
      end
      PrepareIDBit: begin
        if (id_bit_count != '0) begin
          state_d = SendIDBit;
        end
      end
      SendIDBit: begin
        if (bus_tx_done_i) begin
          // our Id was overwritten by some other device
          if (arbitration_lost_i) begin
            state_d = LostArbitration;
          end
          if (id_bit_count == '0) begin
            state_d = ReceiveAddr;
          end else begin
            state_d = PrepareIDBit;
          end
        end
      end
      LostArbitration: begin
        state_d = Error;
      end
      ReceiveAddr: begin
        if (bus_rx_done_i) begin
          if (parity_ok) state_d = AckAddr;
          else state_d = SendNack;
        end
      end
      AckAddr: begin
        if (bus_tx_done_i) begin
          state_d = Done;
        end
      end
      Done: begin
        state_d = Idle;
      end
      Error: begin
      // we wait here until we receive Stop
      end
      default: begin
      end
    endcase
  end

  always_comb begin : state_outputs
    bus_rx_req_byte_o = '0;
    bus_rx_req_bit_o = '0;

    bus_tx_req_byte_o = '0;
    bus_tx_req_bit_o = '0;
    bus_tx_req_value_o = '0;
    bus_tx_sel_od_pp_o = '0;

    load_id_counter = '0;
    tick_id_counter = '0;
    address_o = '0;
    address_valid_o = '0;
    unique case (state_q)
      Idle: begin
      end
      WaitStart: begin
      end
      ReceiveRsvdByte: begin
        bus_rx_req_byte_o = '1;
      end
      AckRsvdByte: begin
        bus_tx_req_byte_o = '0;
        bus_tx_req_bit_o = '1;
        bus_tx_req_value_o = '0;
      end
      SendNack: begin
        bus_tx_req_bit_o = '1;
        bus_tx_req_value_o = '1;
      end
      SendID: begin
        load_id_counter = '1;
      end
      PrepareIDBit: begin
        tick_id_counter = '1;
      end
      SendIDBit: begin
        bus_tx_req_bit_o = '1;
        bus_tx_req_value_o = {7'h0, device_id[id_bit_count[5:0]]};
      end
      ReceiveAddr: begin
        bus_rx_req_byte_o = '1;
        if (bus_rx_done_i) begin
          address_valid_o = '1;
          address_o = bus_rx_data_i[7:1];
        end
      end
      AckAddr: begin
        bus_tx_req_bit_o = '1;
        bus_tx_req_value_o = '0;
      end
      Done: begin
      end
      Error: begin
      end
      default: begin
      end
   endcase
  end
  // Synchronous state transition
  always_ff @(posedge clk_i or negedge rst_ni) begin : state_transition
    if (!rst_ni) begin
      state_q <= Idle;
    end else begin
      if (bus_stop_det_i) state_q <= Done;
      else state_q <= state_d;
    end
  end

endmodule

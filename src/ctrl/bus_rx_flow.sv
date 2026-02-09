// SPDX-License-Identifier: Apache-2.0
/*
    Read a byte
*/

module bus_rx_flow (
  input  logic clk_i,
  input  logic rst_ni,

  input  logic scl_posedge_i,
  input  logic scl_stable_high_i,
  input  logic sda_i,

  input  i3c_pkg::bus_rx_req_t rx_req_i,
  output i3c_pkg::bus_rx_rsp_t rx_rsp_o
);

  logic [3:0] bit_counter;
  logic       bit_counter_en;

  logic [6:0] rx_data;
  logic       rx_bit;

  logic rx_bit_en;
  logic rx_done, rx_rsp_done;
  logic req;
  logic rx_req_bit;

  typedef enum logic [2:0] {
    Idle,
    ReadByte,
    ReadBit,
    NextTaskDecision
  } rx_state_e;

  rx_state_e state_d, state_q;

  assign req = rx_req_i.req_bit | rx_req_i.req_byte;

  assign rx_rsp_o = '{
    idle: (state_q == Idle),
    done: rx_rsp_done,
    data: rx_req_bit ? {{7{1'b0}}, rx_bit} : {rx_data[6:0], sda_i}
  };

  always_ff @(posedge clk_i or negedge rst_ni) begin : ff_bit_request
    if (~rst_ni) begin
      rx_req_bit <= '0;
    end else begin
      rx_req_bit <= rx_req_i.req_bit;
    end
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin : read_bit_from_bus
    if (~rst_ni) begin
      rx_done <= '0;
      rx_bit  <= '0;
    end else begin
      if (rx_bit_en & scl_posedge_i) begin
        rx_done <= 1'b1;
        rx_bit  <= sda_i;
      end else begin
        rx_done <= '0;
        rx_bit  <= '0;
      end
    end
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin : read_byte_from_bus
    if (~rst_ni) begin
      rx_data <= '0;
    end else begin
      if (bit_counter_en) begin
        if (rx_done) rx_data[6:0] <= {rx_data[5:0], sda_i};
      end else begin
        rx_data <= '0;
      end
    end
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin : update_bit_counter
    if (~rst_ni) begin
      bit_counter <= 4'h7;
    end else begin
      if (bit_counter_en) begin
        if (rx_done) bit_counter <= bit_counter - 1;
        else bit_counter <= bit_counter;
      end else begin
        bit_counter <= 4'h7;
      end
    end
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin : update_fsm_state
    if (~rst_ni) begin
      state_q <= Idle;
    end else begin
      state_q <= state_d;
    end
  end

  always_comb begin : rx_fsm_outputs
    rx_rsp_done = 1'b0;
    rx_bit_en = '0;
    bit_counter_en = '0;

    unique case (state_q)
      Idle: begin end
      ReadByte: begin
        bit_counter_en = 1'b1;
        rx_bit_en = ~rx_done;
        if (~|bit_counter & rx_done) begin
          rx_rsp_done = 1'b1;
        end
      end
      ReadBit: begin
        rx_bit_en = ~rx_done;
        if (rx_done) rx_rsp_done = 1'b1;
      end
      NextTaskDecision: begin
        rx_bit_en = req;
      end
      default: begin end
    endcase
  end

  always_comb begin : rx_fsm_state
    state_d = state_q;

    unique case (state_q)
      Idle: begin
        state_d = rx_req_i.req_byte ? ReadByte : rx_req_bit ? ReadBit : Idle;
      end
      ReadByte: begin
        if (!rx_req_i.req_byte) begin
          state_d = Idle;
        end else if (rx_rsp_done) begin
          state_d = NextTaskDecision;
        end
      end
      ReadBit: begin
        if (!rx_req_i.req_bit) begin
          state_d = Idle;
        end else if (rx_done) begin
          state_d = NextTaskDecision;
        end
      end
      NextTaskDecision: begin
        state_d = rx_req_i.req_byte ? ReadByte : rx_req_bit ? ReadBit : Idle;
      end
      default: begin
        state_d = Idle;
      end
    endcase

    // Allow to abort and go back to Idle if needed
    if (~req) begin
      state_d = Idle;
    end
  end

  // Make sure we never attempt to receive byte and bit at the same time
  `I3C_ASSERT(RxBitAndByte_A, !rx_req_i.req_bit | !rx_req_i.req_byte)

endmodule

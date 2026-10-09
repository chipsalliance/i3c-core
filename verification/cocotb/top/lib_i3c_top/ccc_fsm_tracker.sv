// SPDX-License-Identifier: Apache-2.0
//
// FSM state transition tracker for ccc.
//
// Logs every state_q transition with a timestamp to ccc_fsm_transitions.log.
// Enable with +define+TRACK_FSM_TRANSITIONS at compile time.
// Usage: make ... TRACK_FSM=1
//
// Output format (one line per transition):
//   <timestamp> | <old_state_name> | <new_state_name>

`ifndef SYNTHESIS
`ifndef VERILATOR

module ccc_fsm_tracker (
    input logic       clk_i,
    input logic       rst_ni,
    input logic [7:0] state_q
);

`ifdef TRACK_FSM_TRANSITIONS
  logic [7:0] prev_state_trk;
  integer fsm_log_fd;

  function automatic string state_to_name(input logic [7:0] s);
    case (s)
      8'd0:  return "WaitCCC";
      8'd1:  return "RxCmdTbit";
      8'd2:  return "RxDefByte";
      8'd3:  return "RxDefByteOrBusCond";
      8'd4:  return "RxDefByteTbit";
      8'd5:  return "WaitDirectRstart";
      8'd6:  return "RxDirectDefByteTbit";
      8'd7:  return "RxTargetAddr";
      8'd8:  return "TxTargetAddrAck";
      8'd9:  return "RxSubCmdByte";
      8'd10: return "RxData";
      8'd11: return "RxDataTbit";
      8'd12: return "TxData";
      8'd13: return "TxDataTbitCont";
      8'd14: return "TxDataTbitEnd";
      8'd15: return "WaitForBusCond";
      8'd16: return "WaitForENTDAAEnd";
      8'd17: return "HandleTargetENTDAA";
      8'd18: return "HandleVirtualTargetENTDAA";
      8'd19: return "WaitForStop";
      default: begin
        string name;
        $sformat(name, "UNKNOWN(%0d)", s);
        return name;
      end
    endcase
  endfunction

  initial begin
    fsm_log_fd = $fopen("ccc_fsm_transitions.log", "w");
    if (fsm_log_fd == 0) begin
      $display("ERROR [ccc_fsm_tracker] $fopen failed");
    end else begin
      $display("INFO [ccc_fsm_tracker] Opened ccc_fsm_transitions.log (fd=%0d)", fsm_log_fd);
    end
    $fwrite(fsm_log_fd, "# ccc state transition log\n");
    $fwrite(fsm_log_fd, "# timestamp | old_state | new_state\n");
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      prev_state_trk <= 8'd0;
    end else if (state_q !== prev_state_trk) begin
      $fwrite(fsm_log_fd, "%0t | %s | %s\n",
              $time, state_to_name(prev_state_trk), state_to_name(state_q));
      prev_state_trk <= state_q;
    end
  end

  final begin
    $fclose(fsm_log_fd);
  end
`endif

endmodule : ccc_fsm_tracker

bind ccc ccc_fsm_tracker u_ccc_fsm_tracker (
    .clk_i   (clk_i),
    .rst_ni  (rst_ni),
    .state_q (state_q)
);

`endif // VERILATOR
`endif // SYNTHESIS

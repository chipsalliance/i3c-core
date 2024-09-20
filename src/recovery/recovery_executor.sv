// SPDX-License-Identifier: Apache-2.0

/*
    Recovery command execution module. Responds to commands decoded from I3C
    transactions by recovery_receiver and controls data frow to/from CSRs and
    TTI data queues.

    FIXME: Check if cmd_len_i is valid w.r.t. cmd_cmd_i
*/
module recovery_executor
  import i3c_pkg::*;
(
    input  logic clk_i,  // Clock
    input  logic rst_ni, // Reset (active low)

    // Command interface
    input  logic        cmd_valid_i,
    input  logic        cmd_is_rd_i,
    input  logic [ 7:0] cmd_cmd_i,
    input  logic [15:0] cmd_len_i,
    input  logic        cmd_error_i,
    output logic        cmd_done_o,

    // RX data interface
    output logic        rx_req_o,
    input  logic        rx_ack_i,
    input  logic [31:0] rx_data_i,  // FIXME: parametrize

    output logic        rx_queue_sel_o,
    output logic        rx_queue_clr_o,

    // Recovery CSR interface
    input  I3CCSR_pkg::I3CCSR__I3C_EC__SecFwRecoveryIf__out_t hwif_rec_i,
    output I3CCSR_pkg::I3CCSR__I3C_EC__SecFwRecoveryIf__in_t  hwif_rec_o
);

    // Commands
    typedef enum logic [7:0] {
        CMD_PROT_CAP = 'd34,
        CMD_DEVICE_ID = 'd35,
        CMD_DEVICE_STATUS = 'd36,
        CMD_DEVICE_RESET = 'd37,
        CMD_RECOVERY_CTRL = 'd38,
        CMD_RECOVERY_STATUS = 'd39,
        CMD_HW_STATUS = 'd40,
        CMD_INDIRECT_CTRL = 'd41,
        CMD_INDIRECT_STATUS = 'd42,
        CMD_INDIRECT_DATA = 'd43,
        CMD_VENDOR = 'd44,
        CMD_INDIRECT_FIFO_CTRL = 'd45,
        CMD_INDIRECT_FIFO_STATUS = 'd46,
        CMD_INDIRECT_FIFO_DATA = 'd47
    } command_e;

    // Target CSR selector
    typedef enum logic [7:0] {
        CSR_PROC_CAP_0              = 'd0,
        CSR_PROC_CAP_1              = 'd1,
        CSR_PROC_CAP_2              = 'd2,
        CSR_PROC_CAP_3              = 'd3,
        CSR_DEVICE_ID_0             = 'd4,
        CSR_DEVICE_ID_1             = 'd5,
        CSR_DEVICE_ID_2             = 'd6,
        CSR_DEVICE_ID_3             = 'd7,
        CSR_DEVICE_ID_4             = 'd8,
        CSR_DEVICE_ID_5             = 'd9,
        CSR_DEVICE_ID_6             = 'd10,
        CSR_DEVICE_STATUS_0         = 'd11,
        CSR_DEVICE_STATUS_1         = 'd12,
        CSR_DEVICE_RESET            = 'd13,
        CSR_RECOVERY_CTRL           = 'd14,
        CSR_RECOVERY_STATUS         = 'd15,
        CSR_HW_STATUS               = 'd16,
        CSR_INDIRECT_FIFO_CTRL_0    = 'd17,
        CSR_INDIRECT_FIFO_CTRL_1    = 'd18,
        CSR_INDIRECT_FIFO_STATUS_0  = 'd19,
        CSR_INDIRECT_FIFO_STATUS_1  = 'd20,
        CSR_INDIRECT_FIFO_STATUS_2  = 'd21,
        CSR_INDIRECT_FIFO_STATUS_3  = 'd22,
        CSR_INDIRECT_FIFO_STATUS_4  = 'd23,
        CSR_INDIRECT_FIFO_STATUS_5  = 'd24
    } csr_e;

    // Internal signals
    logic [15:0] dcnt;
    csr_e        csr_sel;

    // ....................................................

    // FSM
    typedef enum logic [7:0] {
        Idle        = 'h00,
        CsrWrite    = 'h10,
        CsrRead     = 'h20,
        Done        = 'hD0,
        Error       = 'hE0
    } state_e;

    state_e state_d, state_q;

    // State transition
    always_ff @(posedge clk_i)
        if (!rst_ni)
            state_q <= Idle;
        else
            state_q <= state_d;

    // Next state
    always_comb case (state_q)
        Idle: if (cmd_valid_i) begin
                if (cmd_error_i)        state_d <= Error;
                else if (!cmd_is_rd_i)  state_d <= CsrWrite;
                else                    state_d <= CsrRead;
            end

        CsrWrite:   if (rx_ack_i & (dcnt == 1)) state_d <= Done;
        CsrRead:    state_d <= Done;
        Error:      state_d <= Done;
        Done:       state_d <= Idle;
    endcase

    // ....................................................

    // Data counter
    always_ff @(posedge clk_i) case (state_q)
        Idle:       if (cmd_valid_i)   dcnt <= (|cmd_len_i[1:0]) ? (cmd_len_i / 4 + 1) : (cmd_len_i / 4); // Round up
        CsrWrite:   if (rx_ack_i)      dcnt <= dcnt - 1;
    endcase

    // Target / source CSR
    always_ff @(posedge clk_i) case (state_q)
        Idle:       if(cmd_valid_i) case (cmd_cmd_i)
            CMD_PROT_CAP:               csr_sel <= CSR_PROC_CAP_0;
            CMD_DEVICE_ID:              csr_sel <= CSR_DEVICE_ID_0;
            CMD_DEVICE_STATUS:          csr_sel <= CSR_DEVICE_STATUS_0;
            CMD_DEVICE_RESET:           csr_sel <= CSR_DEVICE_RESET;
            CMD_RECOVERY_CTRL:          csr_sel <= CSR_RECOVERY_CTRL;
            CMD_RECOVERY_STATUS:        csr_sel <= CSR_RECOVERY_STATUS;
            CMD_HW_STATUS:              csr_sel <= CSR_HW_STATUS;
            CMD_INDIRECT_FIFO_CTRL:     csr_sel <= CSR_INDIRECT_FIFO_CTRL_0;
            CMD_INDIRECT_FIFO_STATUS:   csr_sel <= CSR_INDIRECT_FIFO_STATUS_0;
            endcase

        // FIXME: This will overflow resulting on overwriting unwanted CSRs if
        // a malicious packet with length > CSR length is received
        CsrWrite:   if (rx_ack_i)       csr_sel <= csr_e'(csr_sel + 1);
    endcase

    // ....................................................

    assign rx_queue_sel_o = 1'b1;
    assign rx_queue_clr_o = (state_q == Error);

    // RX FIFO data request
    always_ff @(posedge clk_i) case (state_q)
        Idle:       rx_req_o <= cmd_valid_i & !cmd_error_i & (cmd_len_i != 0);
        CsrWrite:   rx_req_o <= rx_ack_i    & (dcnt != 1);
        default:    rx_req_o <= '0;
    endcase

    // CSR write. Only applicable for writable CSRs as per the OCP
    // recovery spec.
    always_comb begin
        hwif_rec_o.DEVICE_RESET.PLACEHOLDER.we              = rx_ack_i & (csr_sel == CSR_DEVICE_RESET);
        hwif_rec_o.RECOVERY_CTRL.PLACEHOLDER.we             = rx_ack_i & (csr_sel == CSR_RECOVERY_CTRL);
        hwif_rec_o.INDIRECT_FIFO_CTRL_0.PLACEHOLDER.we      = rx_ack_i & (csr_sel == CSR_INDIRECT_FIFO_CTRL_0);
        hwif_rec_o.INDIRECT_FIFO_CTRL_1.PLACEHOLDER.we      = rx_ack_i & (csr_sel == CSR_INDIRECT_FIFO_CTRL_1);
    end

    always_comb begin
        hwif_rec_o.DEVICE_RESET.PLACEHOLDER.next            = rx_data_i;
        hwif_rec_o.RECOVERY_CTRL.PLACEHOLDER.next           = rx_data_i;
        hwif_rec_o.INDIRECT_FIFO_CTRL_0.PLACEHOLDER.next    = rx_data_i;
        hwif_rec_o.INDIRECT_FIFO_CTRL_1.PLACEHOLDER.next    = rx_data_i;
    end

    // ....................................................

    // Response
    assign cmd_done_o = (state_q == Done);

endmodule

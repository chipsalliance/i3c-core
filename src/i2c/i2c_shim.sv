// SPDX-License-Identifier: Apache-2.0

module i2c_shim (

    input  logic    clk_i,
    input  logic    rst_ni,

    input  logic    scl_i,  // serial clock input from i2c bus
    output logic    scl_o,  // serial clock output to i2c bus
    input  logic    sda_i,  // serial data input from i2c bus
    output logic    sda_o   // serial data output to i2c bus

    // TODO: All other control & data signals
);

    // I2C FSM
    i2c_fsm (

        .clk_i              (clk_i),
        .rst_ni             (rst_ni),

        .scl_i              (scl_i),
        .scl_o              (scl_o),
        .sda_i              (sda_i),
        .sda_o              (sda_o),

        // Host mode only
        .host_enable_i      (1'b1),
        .target_enable_i    (1'b0),

        // TODO: Looks like a command port
        .fmt_fifo_rvalid_i          (),
        .fmt_fifo_depth_i           (),
        .fmt_fifo_rready_o          (),
        .fmt_byte_i                 (),
        .fmt_flag_start_before_i    (),
        .fmt_flag_stop_after_i      (),
        .fmt_flag_read_bytes_i      (),
        .fmt_flag_read_continue_i   (),
        .fmt_flag_nak_ok_i          (),

        .unhandled_unexp_nak_i      (), // TODO: ?

        // RX data (can't backpressure)
        .rx_fifo_wvalid_o           (),
        .rx_fifo_wdata_o            (),

        // TX data port
        .tx_fifo_rvalid_i           (),
        .tx_fifo_rready_o           (),
        .tx_fifo_rdata_i            (),

        // Response fifo
        .acq_fifo_wvalid_o          (),
        .acq_fifo_wdata_o           (), 
        .acq_fifo_depth_i           (), 
        .acq_fifo_wready_o          (),
        .acq_fifo_rdata_i           (), // Not needed, used by an ASSERT()

        // TODO: Drive these with data from a preset(s)
        .thigh_i                    (),
        .tlow_i                     (),
        .t_r_i                      (),
        .t_f_i                      (),
        .thd_sta_i                  (),
        .tsu_sta_i                  (),
        .tsu_sto_i                  (),
        .tsu_dat_i                  (),
        .thd_dat_i                  (),
        .t_buf_i                    (),

        .stretch_timeout_i          (),
        .timeout_enable_i           (),

        .host_timeout_i             (1'b0), // Irrelevant for host mode
        .host_nack_handler_timeout_en_i (1'b0), // Irrelevant for host mode
        .nack_timeout_en_i          (1'b0), // Irrelevant for host mode

        .target_address0_i          ('d0)   // Irrelevant for host mode,
        .target_mask0_i             ('d0)   // Irrelevant for host mode,
        .target_address1_i          ('d0)   // Irrelevant for host mode,
        .target_mask1_i             ('d0)   // Irrelevant for host mode,

        // Host mode related events
        .event_nak_o                (),
        .event_scl_interference_o   (),
        .event_sda_interference_o   (),
        .event_stretch_timeout_o    (),
        .event_sda_unstable_o       (),
        .event_cmd_complete_o       (),
        .event_tx_stretch_o         ()
    );

);

endmodule

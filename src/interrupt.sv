/*
Single interrupt request handling logic
*/
module interrupt (
    input  logic irq_i,         // IRQ input from source
    input  logic irq_force_i,   // Force IRQ input

    input  logic clr_i,         // Status clear from logic

    output logic sts_o,         // Status next state
    output logic sts_we_o,      // Status wrtie enable
    input  logic sts_i,         // Status state

    input  logic sts_ena_i,     // IRQ status nable input
    input  logic sig_ena_i,     // IRQ signal enable input

    output logic irq_o          // IRQ output
);

    // Interrupt request (masked)
    logic  irq;
    assign irq = (irq_i | irq_force_i) & sts_ena_i;

    // Status storage
    always_comb begin
        sts_o       = '0;
        sts_we_o    = '0;

        if (irq) begin
            sts_o       = '1;
            sts_we_o    = '1;
        end else if (clr_i) begin
            sts_o       = '0;
            sts_we_o    = '1;
        end
    end

    // Interrupt request output
    assign irq_o = sts_i & sig_ena_i;

endmodule

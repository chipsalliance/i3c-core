/*
Single interrupt request handling logic
*/
module interrupt # (
    parameter bit Edge = 1      // 1 - trigger on rising edge, 0 - trigger on high level
) (
    input  logic clk_i,
    input  logic rst_ni,

    input  logic irq_i,         // IRQ input from source
    input  logic irq_force_i,   // Force IRQ input

    input  logic clr_i,         // Status clear from logic

    output logic sts_o,         // Status next state
    output logic sts_we_o,      // Status write enable
    input  logic sts_i,         // Status state

    input  logic sts_ena_i,     // IRQ status enable input
    input  logic sig_ena_i,     // IRQ signal enable input

    output logic irq_o          // IRQ output
);

    logic  irq;
    logic  trg;

    // Interrupt request input
    assign irq = (irq_i | irq_force_i);

    // Trigger on edge
    generate if (Edge == 1'b1) begin
        logic irq_r;
        always_ff @(posedge clk_i) begin
            if (!rst_ni) begin
                irq_r <= '0;
                trg   <= '0;
            end else begin
                irq_r <= irq;
                trg   <= irq & !irq_r;
            end
        end

    // Trigger on level
    end else begin
        assign trg = irq;

    end endgenerate

    // Status storage control
    always_comb begin
        sts_o       = '0;
        sts_we_o    = '0;

        if (trg & sts_ena_i) begin
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

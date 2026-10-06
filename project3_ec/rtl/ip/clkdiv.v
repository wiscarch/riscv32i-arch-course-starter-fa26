// CPU clock divider with a run enable.
//
// The hart's interface has only i_clk -- no clock enable -- so slowing it down
// means producing a slower clock rather than gating an enable. A single-cycle
// design with LUT-based memories will not close timing anywhere near 50 MHz,
// so we divide down and let the student raise it once they know their Fmax.
//
// DIV_LOG2 = 2 gives CLOCK_50 / 4 = 12.5 MHz, which is deliberately
// conservative. The SDC file declares the result as a generated clock.
//
// When i_run drops the counter stops, freezing the CPU clock. That is how
// ebreak halts the processor: there is no stall input on the hart, so stopping
// its clock is the only way to hold it still.
//
// Reset overrides that and keeps the counter running. The hart and the MMIO
// block reset synchronously on this clock, so if it stopped during reset they
// would never see an edge while reset was asserted and would not reset at all.

`default_nettype none

module clkdiv #(
    parameter DIV_LOG2 = 2
) (
    input  wire i_clk,
    input  wire i_rst,
    input  wire i_run,
    output wire o_clk
);
    reg [DIV_LOG2-1:0] cnt = {DIV_LOG2{1'b0}};

    always @(posedge i_clk) begin
        if (i_rst || i_run)
            cnt <= cnt + 1'b1;
    end

    assign o_clk = cnt[DIV_LOG2-1];

endmodule

`default_nettype wire

// Watches the hart's retire interface for ebreak and traps.
//
// Both flags are sticky. Once set, the CPU clock stops and the board shows why:
//
//   halted  (ebreak)  -- all LEDs on, steady
//   trapped           -- all LEDs blinking
//
// A trap means an illegal instruction, a misaligned load/store, or a misaligned
// branch target. On a correct processor running these demos it should never
// fire, so if the LEDs are blinking, the processor is at fault, not the program.

`default_nettype none

module halt_ctrl (
    input  wire i_clk,              // CLOCK_50
    input  wire i_rst,

    input  wire i_retire_valid,
    input  wire i_retire_halt,
    input  wire i_retire_trap,

    output reg  o_halted,
    output reg  o_trapped,
    output wire o_cpu_run
);
    always @(posedge i_clk) begin
        if (i_rst) begin
            o_halted  <= 1'b0;
            o_trapped <= 1'b0;
        end else begin
            if (i_retire_valid && i_retire_halt) o_halted  <= 1'b1;
            if (i_retire_valid && i_retire_trap) o_trapped <= 1'b1;
        end
    end

    assign o_cpu_run = ~(o_halted | o_trapped);

endmodule

`default_nettype wire

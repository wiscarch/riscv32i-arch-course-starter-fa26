// DE1-SoC board top level.
//
// Reset is KEY1. No demo program reads it so it never collides with a
// program's own input.
//
// LEDs are driven by the running program, except when the CPU has stopped:
//
//   ebreak reached  -- all LEDs on, steady
//   trap taken      -- all LEDs blinking at about 2 Hz
//
// A trap means the processor hit an illegal instruction, a misaligned access,
// or a misaligned branch target. These demo programs do none of those, so
// blinking LEDs point at the processor rather than the software.

`default_nettype none

module de1soc_top #(
    parameter CLK_DIV_LOG2 = 2,                 // CLOCK_50 / 4 = 12.5 MHz
    parameter IMEM_WORDS   = 1024,              // 4 KB
    parameter DMEM_WORDS   = 1024,              // 4 KB
    parameter INIT_FILE    = "program.mem"
) (
    input  wire        CLOCK_50,
    input  wire [ 3:0] KEY,                     // active low, debounced on board
    input  wire [ 9:0] SW,
    output wire [ 9:0] LEDR,
    output wire [ 6:0] HEX0,
    output wire [ 6:0] HEX1,
    output wire [ 6:0] HEX2,
    output wire [ 6:0] HEX3,
    output wire [ 6:0] HEX4,
    output wire [ 6:0] HEX5
);
    // --------------------------------------------------------------- reset
    // Free-running power-on reset: hold for the first 64 cycles after
    // configuration, then release. KEY1 re-asserts it at any time.
    reg [5:0] por_cnt = 6'd0;
    reg       por_done = 1'b0;

    always @(posedge CLOCK_50) begin
        if (!por_done) begin
            por_cnt <= por_cnt + 1'b1;
            if (&por_cnt)
                por_done <= 1'b1;
        end
    end

    // KEY is active low, so a pressed button reads 0; Synchronise it to
    // CLOCK_50 
    reg [1:0] key1_sync = 2'b00;

    always @(posedge CLOCK_50)
        key1_sync <= {key1_sync[0], ~KEY[1]};

    wire manual_rst = key1_sync[1];
    wire rst        = ~por_done | manual_rst;

    // ----------------------------------------------------------- CPU clock
    wire cpu_run;
    wire cpu_clk;

    clkdiv #(
        .DIV_LOG2 (CLK_DIV_LOG2)
    ) u_clkdiv (
        .i_clk (CLOCK_50),
        .i_rst (rst),
        .i_run (cpu_run),
        .o_clk (cpu_clk)
    );

    // ------------------------------------------------------------- the SoC
    wire [ 9:0] ledr_prog;
    wire [23:0] hex_val;
    wire [ 5:0] hex_en;

    wire        retire_valid, retire_halt, retire_trap;
    wire [31:0] retire_pc, retire_inst;

    soc_core #(
        .IMEM_WORDS (IMEM_WORDS),
        .DMEM_WORDS (DMEM_WORDS),
        .INIT_FILE (INIT_FILE)
    ) u_core (
        .i_clk          (cpu_clk),
        .i_rst          (rst),

        .i_sw           (SW),
        .i_key_n        (KEY),

        .o_ledr         (ledr_prog),
        .o_hex_val      (hex_val),
        .o_hex_en       (hex_en),

        .o_retire_valid (retire_valid),
        .o_retire_halt  (retire_halt),
        .o_retire_trap  (retire_trap),
        .o_retire_pc    (retire_pc),
        .o_retire_inst  (retire_inst)
    );

    // ------------------------------------------------------ halt detection
    wire halted, trapped;

    halt_ctrl u_halt (
        .i_clk          (CLOCK_50),
        .i_rst          (rst),
        .i_retire_valid (retire_valid),
        .i_retire_halt  (retire_halt),
        .i_retire_trap  (retire_trap),
        .o_halted       (halted),
        .o_trapped      (trapped),
        .o_cpu_run      (cpu_run)
    );

    // --------------------------------------------------------------- LEDs
    // ~2 Hz from a 50 MHz clock: bit 23 toggles every 2^23 cycles (~168 ms),
    // bit 24 every ~336 ms. Use bit 24 for a visible blink.
    reg [24:0] blink;
    always @(posedge CLOCK_50)
        blink <= blink + 1'b1;

    assign LEDR = trapped ? {10{blink[24]}}
                : halted  ? 10'h3FF
                :           ledr_prog;

    // ---------------------------------------------------------- displays
    hex7seg u_hex0 (.i_val(hex_val[ 3: 0]), .i_enable(hex_en[0]), .o_seg(HEX0));
    hex7seg u_hex1 (.i_val(hex_val[ 7: 4]), .i_enable(hex_en[1]), .o_seg(HEX1));
    hex7seg u_hex2 (.i_val(hex_val[11: 8]), .i_enable(hex_en[2]), .o_seg(HEX2));
    hex7seg u_hex3 (.i_val(hex_val[15:12]), .i_enable(hex_en[3]), .o_seg(HEX3));
    hex7seg u_hex4 (.i_val(hex_val[19:16]), .i_enable(hex_en[4]), .o_seg(HEX4));
    hex7seg u_hex5 (.i_val(hex_val[23:20]), .i_enable(hex_en[5]), .o_seg(HEX5));

endmodule

`default_nettype wire

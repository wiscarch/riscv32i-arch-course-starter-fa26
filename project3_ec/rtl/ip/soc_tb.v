// Simulation testbench for the SoC.
//
// SIMULATION ONLY -- do not add this file to the Quartus project.
//
// Instantiates soc_core (the same module the board top level uses) and drives
// the switches and buttons the way a person would, then checks what appears on
// the LEDs and displays. Running a program here before flashing it is much
// faster than waiting for a Quartus compile to find out it does nothing.
//
//   iverilog -g2005 -o soc_tb.out -s soc_tb *.v <your rtl>/*.v
//   vvp soc_tb.out +PROG=echo
//
// Select which program's checks to run with +PROG=echo|calc|pong. The memory
// image still comes from program.mem, so build that program first.

`timescale 1ns / 1ps
`default_nettype none

module soc_tb ();

    // ------------------------------------------------------------ stimulus
    reg         clk = 1'b0;
    reg         rst = 1'b1;
    reg  [ 9:0] sw  = 10'd0;
    reg  [ 3:0] key_n = 4'hF;           // active low: all released

    wire [ 9:0] ledr;
    wire [23:0] hex_val;
    wire [ 5:0] hex_en;
    wire        retire_valid, retire_halt, retire_trap;
    wire [31:0] retire_pc, retire_inst;

    integer errors = 0;
    integer cycles = 0;

    soc_core #(
        .IMEM_WORDS (1024),
        .DMEM_WORDS (1024),
        .INIT_FILE ("program.mem")
    ) dut (
        .i_clk          (clk),
        .i_rst          (rst),
        .i_sw           (sw),
        .i_key_n        (key_n),
        .o_ledr         (ledr),
        .o_hex_val      (hex_val),
        .o_hex_en       (hex_en),
        .o_retire_valid (retire_valid),
        .o_retire_halt  (retire_halt),
        .o_retire_trap  (retire_trap),
        .o_retire_pc    (retire_pc),
        .o_retire_inst  (retire_inst)
    );

    always #5 clk = ~clk;

    always @(posedge clk) begin
        cycles <= cycles + 1;
        // A trap should never happen with these programs on a correct
        // processor. If one does, say so loudly and stop -- it means the
        // processor hit an illegal instruction or a misaligned access.
        if (retire_valid && retire_trap) begin
            $display("TRAP at pc=%08h inst=%08h", retire_pc, retire_inst);
            errors = errors + 1;
            $finish;
        end
    end

    // --------------------------------------------------------------- helpers
    task run_cycles(input integer n);
        integer i;
        begin
            for (i = 0; i < n; i = i + 1)
                @(posedge clk);
        end
    endtask

    task press(input integer idx, input integer hold);
        begin
            key_n[idx] = 1'b0;
            run_cycles(hold);
            key_n[idx] = 1'b1;
            run_cycles(hold);
        end
    endtask

    task check(input [255:0] what, input [31:0] got, input [31:0] want);
        begin
            if (got !== want) begin
                $display("  FAIL %0s: got %08h, want %08h", what, got, want);
                errors = errors + 1;
            end else begin
                $display("  ok   %0s = %08h", what, got);
            end
        end
    endtask

    // ------------------------------------------------------------------ main
    reg [63:0] prog;

    initial begin
        if (!$value$plusargs("PROG=%s", prog))
            prog = "echo";

        $display("=== soc_tb: %0s ===", prog);

        run_cycles(4);
        rst = 1'b0;
        run_cycles(20);

        case (prog)
        "echo": begin
            // LEDR should track the switches, and the low three hex digits
            // should show the same value.
            sw = 10'h155;
            run_cycles(50);
            check("ledr",        {22'd0, ledr},          32'h155);
            check("hex low 12",  {20'd0, hex_val[11:0]}, 32'h155);

            sw = 10'h2AA;
            run_cycles(50);
            check("ledr after change", {22'd0, ledr}, 32'h2AA);

            // Only the three switch digits are lit.
            check("hex_en", {26'd0, hex_en}, 32'h07);
        end

        "calc": begin
            // SW[3:0]=A, SW[7:4]=B, SW[9:8]=op. Bank 0, op 0 is ADD.
            // A=7, B=5, op=0  ->  result 12 (0xC)
            sw = 10'h057;
            run_cycles(200);
            check("op",     {28'd0, hex_val[23:20]}, 32'h0);
            check("ADD",    {20'd0, hex_val[11:0]},  32'h00C);
            check("hex_en", {26'd0, hex_en},         32'h27);

            // op = 1 -> SUB. 7 - 5 = 2.
            sw = 10'h157;
            run_cycles(200);
            check("SUB",    {20'd0, hex_val[11:0]},  32'h002);

            // op = 2 -> AND. 7 & 5 = 5.
            sw = 10'h257;
            run_cycles(200);
            check("AND",    {20'd0, hex_val[11:0]},  32'h005);

            // op = 3 -> OR. 7 | 5 = 7.
            sw = 10'h357;
            run_cycles(200);
            check("OR",     {20'd0, hex_val[11:0]},  32'h007);
        end

        "pong": begin
            // Attract mode sweeps a single LED. Exactly one should be lit.
            run_cycles(2000);
            if (ledr == 10'd0 || (ledr & (ledr - 1)) != 10'd0) begin
                $display("  FAIL attract: expected one lit LED, got %010b", ledr);
                errors = errors + 1;
            end else begin
                $display("  ok   attract: single LED at %010b", ledr);
            end
            // Scores start at zero on HEX5 and HEX0.
            check("score left",  {28'd0, hex_val[23:20]}, 32'h0);
            check("score right", {28'd0, hex_val[ 3: 0]}, 32'h0);
            check("hex_en",      {26'd0, hex_en},         32'h21);
        end

        default: begin
            $display("  unknown program %0s", prog);
            errors = errors + 1;
        end
        endcase

        $display("=== %0d error(s), %0d cycles ===", errors, cycles);
        if (errors != 0)
            $fatal(1, "FAILED");
        $finish;
    end

    // Safety net: these programs never halt on their own.
    initial begin
        #20_000_000;
        $display("timeout");
        $fatal(1, "TIMEOUT");
    end

endmodule

`default_nettype wire

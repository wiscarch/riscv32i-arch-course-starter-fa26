// Data memory: asynchronous-read, byte-writable.
//
// Reads are combinational (same cycle); writes land on the next rising edge.
// This matches the hart's dmem port exactly.
//
// Initialised from the same image as imem, so .rodata (string tables, switch
// jump tables) is present at reset with no copy loop in crt0.

`default_nettype none

module dmem #(
    parameter WORDS     = 1024,             // 4 KB
    parameter INIT_FILE = "program.mem"
) (
    input  wire        i_clk,
    input  wire [31:0] i_addr,
    input  wire        i_ren,
    input  wire        i_wen,
    input  wire [31:0] i_wdata,
    input  wire [ 3:0] i_mask,
    output wire [31:0] o_rdata
);
    localparam AW = $clog2(WORDS);

    reg [31:0] mem [0:WORDS-1];

    wire [AW-1:0] idx = i_addr[AW+1:2];

    initial $readmemh(INIT_FILE, mem);

    always @(posedge i_clk) begin
        if (i_wen) begin
            if (i_mask[0]) mem[idx][ 7: 0] <= i_wdata[ 7: 0];
            if (i_mask[1]) mem[idx][15: 8] <= i_wdata[15: 8];
            if (i_mask[2]) mem[idx][23:16] <= i_wdata[23:16];
            if (i_mask[3]) mem[idx][31:24] <= i_wdata[31:24];
        end
    end

    // Always return the whole word. The ISA spec leaves bytes outside the mask
    // undefined, so this is legal and cheaper than masking. i_ren is unused
    // here for the same reason -- a read has no side effects.
    assign o_rdata = mem[idx];

endmodule

`default_nettype wire

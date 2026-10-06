// Instruction memory.
//
// Initialised from the same image file as the data memory. Each ignores the
// region it never addresses, which is why one file serves both.

`default_nettype none

module imem #(
    parameter WORDS     = 1024,             // 4 KB
    parameter INIT_FILE = "program.mem"
) (
    input  wire [31:0] i_raddr,
    output wire [31:0] o_rdata
);
    localparam AW = $clog2(WORDS);

    reg [31:0] mem [0:WORDS-1];

    initial $readmemh(INIT_FILE, mem);

    // i_raddr is a byte address; drop the two low bits to index words.
    assign o_rdata = mem[i_raddr[AW+1:2]];

endmodule

`default_nettype wire

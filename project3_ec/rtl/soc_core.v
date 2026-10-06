// =============================================================================
//  THIS IS THE ONLY FILE YOU NEED TO EDIT.
// =============================================================================
// -----------------------------------------------------------------------------
//  WHAT CONNECTS TO WHAT
// -----------------------------------------------------------------------------
//
//  Your hart port        Connect to           Why
//  -------------------   ------------------   ---------------------------------
//  i_clk                 i_clk                the CPU clock, already divided
//                                             down from the board's 50 MHz
//  i_rst                 i_rst                synchronous, active high
//
//  o_imem_raddr          imem_raddr           your PC goes out here
//  i_imem_rdata          imem_rdata           the instruction comes back the
//                                             SAME cycle -- it is a
//                                             combinational read
//
//  o_dmem_addr           dmem_addr            word-aligned byte address
//  o_dmem_ren            dmem_ren             asserted for loads
//  o_dmem_wen            dmem_wen             asserted for stores
//  o_dmem_wdata          dmem_wdata           store data
//  o_dmem_mask           dmem_mask            which byte lanes (sb / sh / sw)
//  i_dmem_rdata          dmem_rdata           load data, also combinational
//
//  o_retire_valid        o_retire_valid       single-cycle: every cycle
//  o_retire_inst         o_retire_inst        used to report traps
//  o_retire_trap         o_retire_trap        lights the error pattern
//  o_retire_halt         o_retire_halt        ebreak stops the CPU clock
//  o_retire_pc           o_retire_pc          reported on a trap
//  o_retire_rs1_raddr    retire_rs1_raddr     \
//  o_retire_rs1_rdata    retire_rs1_rdata      |  not used by the board, but
//  o_retire_rs2_raddr    retire_rs2_raddr      |  your hart drives them
//  o_retire_rs2_rdata    retire_rs2_rdata      |  
//  o_retire_rd_waddr     retire_rd_waddr       |
//  o_retire_rd_wdata     retire_rd_wdata       |
//  o_retire_next_pc      retire_next_pc       /
//
// -----------------------------------------------------------------------------
//  HOW THE REST OF IT WORKS -- you do not need to change any of this
// -----------------------------------------------------------------------------
//
// Your data port is split by address. Anything with bit 31 set is a
// peripheral; everything else is memory:
//
//      o_dmem_addr[31] == 0   ->  dmem     (your program's data and stack)
//      o_dmem_addr[31] == 1   ->  mmio     (switches, buttons, LEDs, displays)
//
// Both memories read combinationally, because that is what your hart's
// interface requires. Neither is a block RAM -- a block RAM's read port is
// registered and could not return data in the same cycle. Look for that in the
// Quartus fitter report.
//
// =============================================================================

`default_nettype none

module soc_core #(
    parameter IMEM_WORDS = 1024,                // 4 KB
    parameter DMEM_WORDS = 1024,                // 4 KB
    parameter INIT_FILE  = "program.mem"
) (
    input  wire        i_clk,                   // CPU clock (already divided)
    input  wire        i_rst,                   // synchronous, active high

    // raw board inputs
    input  wire [ 9:0] i_sw,
    input  wire [ 3:0] i_key_n,                 // active low, as the board wires them

    // outputs toward the board
    output wire [ 9:0] o_ledr,
    output wire [23:0] o_hex_val,
    output wire [ 5:0] o_hex_en,

    // retire interface, forwarded so the board can show halts and traps
    output wire        o_retire_valid,
    output wire        o_retire_halt,
    output wire        o_retire_trap,
    output wire [31:0] o_retire_pc,
    output wire [31:0] o_retire_inst
);
    // ------------------------------------------------------------ hart wires
    // These are already declared for you. Connect your hart to them below.
    wire [31:0] imem_raddr, imem_rdata;
    wire [31:0] dmem_addr, dmem_wdata, dmem_rdata;
    wire        dmem_ren, dmem_wen;
    wire [ 3:0] dmem_mask;

    // Retire signals the board does not use, but your hart still drives.
    wire [ 4:0] retire_rs1_raddr, retire_rs2_raddr, retire_rd_waddr;
    wire [31:0] retire_rs1_rdata, retire_rs2_rdata, retire_rd_wdata;
    wire [31:0] retire_next_pc;

    // ----------------------------------------------------------------- split
    wire is_mmio = dmem_addr[31];

    wire        mem_ren  = dmem_ren  & ~is_mmio;
    wire        mem_wen  = dmem_wen  & ~is_mmio;
    wire        mmio_ren = dmem_ren  &  is_mmio;
    wire        mmio_wen = dmem_wen  &  is_mmio;

    wire [31:0] mem_rdata, mmio_rdata;

    assign dmem_rdata = is_mmio ? mmio_rdata : mem_rdata;

    // =========================================================================
    //  TODO: connect your processor.
    //
    //  Fill in each ( ) below. See the table at the top of this file.
    //  Example:   .i_clk (i_clk),
    // =========================================================================
    hart #(
        .RESET_ADDR (32'h0)                     // programs start at address 0
    ) u_hart (
        .i_clk              (          ),
        .i_rst              (          ),

        .o_imem_raddr       (          ),
        .i_imem_rdata       (          ),

        .o_dmem_addr        (          ),
        .o_dmem_ren         (          ),
        .o_dmem_wen         (          ),
        .o_dmem_wdata       (          ),
        .o_dmem_mask        (          ),
        .i_dmem_rdata       (          ),

        .o_retire_valid     (          ),
        .o_retire_inst      (          ),
        .o_retire_trap      (          ),
        .o_retire_halt      (          ),
        .o_retire_rs1_raddr (          ),
        .o_retire_rs1_rdata (          ),
        .o_retire_rs2_raddr (          ),
        .o_retire_rs2_rdata (          ),
        .o_retire_rd_waddr  (          ),
        .o_retire_rd_wdata  (          ),
        .o_retire_pc        (          ),
        .o_retire_next_pc   (          )
    );
    // =========================================================================
    //  END OF THE PART YOU EDIT
    // =========================================================================

    // ------------------------------------------------------------- memories
    imem #(
        .WORDS     (IMEM_WORDS),
        .INIT_FILE (INIT_FILE)
    ) u_imem (
        .i_raddr (imem_raddr),
        .o_rdata (imem_rdata)
    );

    dmem #(
        .WORDS     (DMEM_WORDS),
        .INIT_FILE (INIT_FILE)
    ) u_dmem (
        .i_clk   (i_clk),
        .i_addr  (dmem_addr),
        .i_ren   (mem_ren),
        .i_wen   (mem_wen),
        .i_wdata (dmem_wdata),
        .i_mask  (dmem_mask),
        .o_rdata (mem_rdata)
    );

    // ----------------------------------------------------------- peripherals
    mmio u_mmio (
        .i_clk       (i_clk),
        .i_rst       (i_rst),

        .i_addr      (dmem_addr),
        .i_ren       (mmio_ren),
        .i_wen       (mmio_wen),
        .i_wdata     (dmem_wdata),
        .o_rdata     (mmio_rdata),

        .i_sw_raw    (i_sw),
        .i_key_raw_n (i_key_n),

        .i_retire    (o_retire_valid),

        .o_ledr      (o_ledr),
        .o_hex_val   (o_hex_val),
        .o_hex_en    (o_hex_en)
    );

endmodule

`default_nettype wire

// One hex digit -> seven segments, active low (DE1-SoC wiring).
//
// Bit order is {g,f,e,d,c,b,a}; a 0 lights the segment.

`default_nettype none

module hex7seg (
    input  wire [3:0] i_val,
    input  wire       i_enable,      // 0 blanks the digit entirely
    output wire [6:0] o_seg
);
    reg [6:0] seg;

    always @(*) begin
        case (i_val)
            4'h0: seg = 7'b1000000;
            4'h1: seg = 7'b1111001;
            4'h2: seg = 7'b0100100;
            4'h3: seg = 7'b0110000;
            4'h4: seg = 7'b0011001;
            4'h5: seg = 7'b0010010;
            4'h6: seg = 7'b0000010;
            4'h7: seg = 7'b1111000;
            4'h8: seg = 7'b0000000;
            4'h9: seg = 7'b0010000;
            4'hA: seg = 7'b0001000;
            4'hB: seg = 7'b0000011;
            4'hC: seg = 7'b1000110;
            4'hD: seg = 7'b0100001;
            4'hE: seg = 7'b0000110;
            4'hF: seg = 7'b0001110;
        endcase
    end

    assign o_seg = i_enable ? seg : 7'b1111111;

endmodule

`default_nettype wire

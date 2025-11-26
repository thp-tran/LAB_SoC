`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11/26/2025 08:51:12 PM
// Design Name: 
// Module Name: cla_adder
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


/**
 * @param a first 1-bit input
 * @param b second 1-bit input
 * @param g whether a and b generate a carry
 * @param p whether a and b would propagate an incoming carry
 */
module gp1(input wire a, b,
           output wire g, p);
   assign g = a & b;
   assign p = a | b;
endmodule


/**
 * Computes aggregate generate/propagate signals over a 4-bit window.
 */
module gp4(input wire [3:0] gin, pin,
           input wire cin,
           output wire gout, pout,
           output wire [2:0] cout);

   assign cout[0] = gin[0] | (pin[0] & cin);
   assign cout[1] = gin[1] | (pin[1] & gin[0]) | (pin[1] & pin[0] & cin);
   assign cout[2] = gin[2] | (pin[2] & gin[1]) | (pin[2] & pin[1] & gin[0]) | (pin[2] & pin[1] & pin[0] & cin);

   assign gout = gin[3] | (pin[3] & gin[2]) | (pin[3] & pin[2] & gin[1]) | (pin[3] & pin[2] & pin[1] & gin[0]);
   assign pout = pin[3] & pin[2] & pin[1] & pin[0];
endmodule


/** Same as gp4 but for an 8-bit window instead */
/** Same as gp4 but for an 8-bit window instead */
module gp8(input wire [7:0] gin, pin,
           input wire cin,
           output wire gout, pout,
           output wire [6:0] cout);
    // cout[0]..cout[6] = carry vào bit1..bit7

    wire [2:0] cout_lo;      // c1,c2,c3
    wire [2:0] cout_hi;      // c5,c6,c7
    wire g_lo, p_lo, g_hi, p_hi;
    wire c4;

    // lower 4 bits (0..3)
    gp4 gp_lo (
        .gin (gin[3:0]),
        .pin (pin[3:0]),
        .cin (cin),
        .gout(g_lo),
        .pout(p_lo),
        .cout(cout_lo)
    );

    // carry vào bit4
    assign c4 = g_lo | (p_lo & cin);

    // upper 4 bits (4..7)
    gp4 gp_hi (
        .gin (gin[7:4]),
        .pin (pin[7:4]),
        .cin (c4),
        .gout(g_hi),
        .pout(p_hi),
        .cout(cout_hi)
    );

    // map đầy đủ c1..c7
    assign cout[0] = cout_lo[0]; // c1
    assign cout[1] = cout_lo[1]; // c2
    assign cout[2] = cout_lo[2]; // c3
    assign cout[3] = c4;         // c4
    assign cout[4] = cout_hi[0]; // c5
    assign cout[5] = cout_hi[1]; // c6
    assign cout[6] = cout_hi[2]; // c7

    // block generate/propagate
    assign gout = g_hi | (p_hi & g_lo);
    assign pout = p_hi & p_lo;
endmodule

/**
 * 32-bit hierarchical carry-lookahead adder
 */
/**
 * 32-bit hierarchical carry-lookahead adder
 */
module cla
  (input  wire [31:0] a, b,
   input  wire        cin,
   output wire [31:0] sum,
   output wire        cout_final);

    wire [31:0] g = a & b;
    wire [31:0] p = a | b;

    // mỗi gp8 trả 7 carry nội bộ
    wire [6:0] cout0, cout1, cout2, cout3;
    wire [3:0] G, P;         // block generate/propagate
    wire [32:0] c;           // c[0]..c[32], c[0]=cin, c[32]=cout_final

    assign c[0] = cin;

    // -------- block 0: bits [7:0] --------
    gp8 gp0(
        .gin (g[7:0]),
        .pin (p[7:0]),
        .cin (c[0]),
        .gout(G[0]),
        .pout(P[0]),
        .cout(cout0)
    );

    assign c[1] = cout0[0];
    assign c[2] = cout0[1];
    assign c[3] = cout0[2];
    assign c[4] = cout0[3];
    assign c[5] = cout0[4];
    assign c[6] = cout0[5];
    assign c[7] = cout0[6];
    assign c[8] = G[0] | (P[0] & c[0]);   // carry ra block0

    // -------- block 1: bits [15:8] --------
    gp8 gp1(
        .gin (g[15:8]),
        .pin (p[15:8]),
        .cin (c[8]),
        .gout(G[1]),
        .pout(P[1]),
        .cout(cout1)
    );

    assign c[9]  = cout1[0];
    assign c[10] = cout1[1];
    assign c[11] = cout1[2];
    assign c[12] = cout1[3];
    assign c[13] = cout1[4];
    assign c[14] = cout1[5];
    assign c[15] = cout1[6];
    assign c[16] = G[1] | (P[1] & c[8]);  // carry ra block1

    // -------- block 2: bits [23:16] --------
    gp8 gp2(
        .gin (g[23:16]),
        .pin (p[23:16]),
        .cin (c[16]),
        .gout(G[2]),
        .pout(P[2]),
        .cout(cout2)
    );

    assign c[17] = cout2[0];
    assign c[18] = cout2[1];
    assign c[19] = cout2[2];
    assign c[20] = cout2[3];
    assign c[21] = cout2[4];
    assign c[22] = cout2[5];
    assign c[23] = cout2[6];
    assign c[24] = G[2] | (P[2] & c[16]); // carry ra block2

    // -------- block 3: bits [31:24] --------
    gp8 gp3(
        .gin (g[31:24]),
        .pin (p[31:24]),
        .cin (c[24]),
        .gout(G[3]),
        .pout(P[3]),
        .cout(cout3)
    );

    assign c[25] = cout3[0];
    assign c[26] = cout3[1];
    assign c[27] = cout3[2];
    assign c[28] = cout3[3];
    assign c[29] = cout3[4];
    assign c[30] = cout3[5];
    assign c[31] = cout3[6];
    assign c[32] = G[3] | (P[3] & c[24]); // carry ra block3

    assign cout_final = c[32];

    // -------- tính sum --------
    genvar i;
    generate
        for (i = 0; i < 32; i = i + 1) begin : gen_sum
            assign sum[i] = a[i] ^ b[i] ^ c[i];
        end
    endgenerate

endmodule

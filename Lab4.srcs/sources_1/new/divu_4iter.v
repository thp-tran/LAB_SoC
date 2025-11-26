`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11/26/2025 03:48:51 PM
// Design Name: 
// Module Name: divu_4iter
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


// 4 iterations = 4 x divu_1iter
module divu_4iter #(
    parameter N = 32
)(
    input  [N:0]   rem_in,
    input  [N-1:0] div,
    input  [N-1:0] quo_in,
    output [N:0]   rem_out,
    output [N-1:0] quo_out
);
    wire [N:0]   r [0:4];
    wire [N-1:0] q [0:4];

    assign r[0] = rem_in;
    assign q[0] = quo_in;

    genvar i;
    generate
        for (i = 0; i < 4; i = i + 1) begin : ITER4
            divu_1iter #(N) u_iter (
                .rem_in (r[i]),
                .div    (div),
                .quo_in (q[i]),
                .rem_out(r[i+1]),
                .quo_out(q[i+1])
            );
        end
    endgenerate

    assign rem_out = r[4];
    assign quo_out = q[4];
endmodule


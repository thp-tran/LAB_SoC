`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11/26/2025 03:27:40 PM
// Design Name: 
// Module Name: divider_unsigned
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


module divider_unsigned #(
    parameter N = 32
)(
    input  [N-1:0] dividend,
    input  [N-1:0] divisor,
    output [N-1:0] quotient,
    output [N-1:0] remainder
);
    // Internal wires
    wire [N:0] rem [0:N];
    wire [N-1:0] quo [0:N];

    assign rem[0] = { (N+1){1'b0} }; // initial remainder = 0
    assign quo[0] = dividend;        // initial quotient input = dividend bits

    genvar i;
    generate
        for (i = 0; i < N; i = i + 1) begin : ITER
            divu_1iter #(N) stage (
                .rem_in(rem[i]),
                .div(divisor),
                .quo_in(quo[i]),
                .rem_out(rem[i+1]),
                .quo_out(quo[i+1])
            );
        end
    endgenerate

    assign quotient  = quo[N];
    assign remainder = rem[N][N-1:0];
endmodule

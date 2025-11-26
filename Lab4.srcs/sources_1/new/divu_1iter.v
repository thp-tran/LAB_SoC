`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11/26/2025 03:26:42 PM
// Design Name: 
// Module Name: divu_1iter
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


//module divu_1iter #(
//    parameter N = 32
//)(
//    input  [N:0] rem_in,      // current remainder (N+1 bits)
//    input  [N-1:0] div,       // divisor
//    input  [N-1:0] quo_in,    // current quotient (dividend bits)
//    output [N:0] rem_out,     // updated remainder
//    output [N-1:0] quo_out    // updated quotient
//);
//    wire [N:0] shifted_rem;
//    wire [N:0] sub_result;
//    wire ge;

//    // Shift left remainder and bring down MSB of quotient
//    assign shifted_rem = {rem_in[N-1:0], quo_in[N-1]};

//    // Subtract divisor
//    assign sub_result = shifted_rem - {1'b0, div};

//    // Check if remainder >= divisor
//    assign ge = !sub_result[N]; // 1 if remainder >= divisor

//    // Update remainder and quotient
//    assign rem_out = ge ? sub_result : shifted_rem;
//    assign quo_out = {quo_in[N-2:0], ge}; // shift left and append quotient bit
//endmodule

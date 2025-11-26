`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11/26/2025 03:53:34 PM
// Design Name: 
// Module Name: divider_unsigned_pipeline
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


module divider_unsigned_pipelined #(
    parameter N = 32,
    parameter STAGES = 8   // 8 pipeline stages
)(
    input               clk,
    input               rst,        // đồng bộ hoặc async tuỳ bạn
    input               valid_in,   // 1: dữ liệu đầu vào hợp lệ
    input  [N-1:0]      dividend,
    input  [N-1:0]      divisor,

    output              valid_out,  // sau 8 chu kỳ từ valid_in
    output [N-1:0]      quotient,
    output [N-1:0]      remainder
);
    // N phải = 32, STAGES = 8, mỗi stage làm 4 iterations

    localparam ITER_PER_STAGE = 4;

    // Pipeline registers cho từng stage
    reg [N:0]   rem_reg [0:STAGES];     // remainder (N+1 bits)
    reg [N-1:0] quo_reg [0:STAGES];     // quotient bits trong thuật toán
    reg [N-1:0] div_reg [0:STAGES];     // divisor "trôi" theo pipeline
    reg [STAGES:0] valid_reg;           // valid shift register

    integer k;

    // Stage 0: load input khi valid_in = 1
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            rem_reg[0]   <= {(N+1){1'b0}};
            quo_reg[0]   <= {N{1'b0}};
            div_reg[0]   <= {N{1'b0}};
            valid_reg[0] <= 1'b0;
        end else begin
            if (valid_in) begin
                rem_reg[0]   <= {(N+1){1'b0}}; // remainder ban đầu = 0
                quo_reg[0]   <= dividend;      // quo_in ban đầu = dividend
                div_reg[0]   <= divisor;
                valid_reg[0] <= 1'b1;
            end else begin
                // nếu không có dữ liệu mới thì valid_in = 0
                valid_reg[0] <= 1'b0;
            end
        end
    end

    // Wires cho output của từng stage combinational
    wire [N:0]   rem_next [0:STAGES-1];
    wire [N-1:0] quo_next [0:STAGES-1];

    genvar s;
    generate
        for (s = 0; s < STAGES; s = s + 1) begin : PIPE
            // Mỗi stage = 4 iterations
            divu_4iter #(N) u_stage (
                .rem_in (rem_reg[s]),
                .div    (div_reg[s]),
                .quo_in (quo_reg[s]),
                .rem_out(rem_next[s]),
                .quo_out(quo_next[s])
            );

            // Đăng ký kết quả cho stage tiếp theo
            always @(posedge clk or posedge rst) begin
                if (rst) begin
                    rem_reg[s+1]   <= {(N+1){1'b0}};
                    quo_reg[s+1]   <= {N{1'b0}};
                    div_reg[s+1]   <= {N{1'b0}};
                    valid_reg[s+1] <= 1'b0;
                end else begin
                    rem_reg[s+1]   <= rem_next[s];
                    quo_reg[s+1]   <= quo_next[s];
                    div_reg[s+1]   <= div_reg[s];    // divisor giữ nguyên
                    valid_reg[s+1] <= valid_reg[s];  // dịch valid bit
                end
            end
        end
    endgenerate

    assign valid_out = valid_reg[STAGES];
    assign quotient  = quo_reg[STAGES];
    assign remainder = rem_reg[STAGES][N-1:0];
endmodule


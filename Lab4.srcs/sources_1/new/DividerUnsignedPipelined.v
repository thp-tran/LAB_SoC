`timescale 1ns / 1ns

// quotient = dividend / divisor
module DividerUnsignedPipelined #(
    parameter N = 32
)(
    input             clk,
    input             rst,
    input             stall,
    input      [N-1:0] i_dividend,
    input      [N-1:0] i_divisor,
    output reg [N-1:0] o_remainder,
    output reg [N-1:0] o_quotient
);

  // 32 bit / 4 iter per stage => 8 stages
  localparam STAGES          = N/4;   // 8
  localparam ITERS_PER_STAGE = 4;

  // Pipeline registers: index 0..STAGES (0..8)
  reg [N-1:0] dividend_reg  [0:STAGES];   // 32-bit
  reg [N-1:0] divisor_reg   [0:STAGES];   // 32-bit
  reg [N:0]   remainder_reg [0:STAGES];   // 33-bit
  reg [N-1:0] quotient_reg  [0:STAGES];   // 32-bit

  integer i;

  // Stage 0: nạp input / khởi tạo
  always @(posedge clk or posedge rst) begin
    if (rst) begin
      dividend_reg[0]  <= {N{1'b0}};
      divisor_reg[0]   <= {N{1'b0}};
      remainder_reg[0] <= {(N+1){1'b0}};
      quotient_reg[0]  <= {N{1'b0}};
    end else if (!stall) begin
      // khởi tạo thuật toán chia
      dividend_reg[0]  <= i_dividend;     // dividend ban đầu
      divisor_reg[0]   <= i_divisor;      // divisor ban đầu
      remainder_reg[0] <= {(N+1){1'b0}};  // remainder = 0 (N+1 bit)
      quotient_reg[0]  <= {N{1'b0}};      // quotient = 0
    end
    // nếu stall = 1 thì giữ nguyên giá trị (pipeline freeze)
  end

  // 8 stage, mỗi stage = 4 x divu_1iter
  genvar s;
  generate
    for (s = 0; s < STAGES; s = s + 1) begin : STAGE
      // 4 iteration liên tiếp (cùng một stage)
      wire [N-1:0] d0, d1, d2, d3, d4;
      wire [N:0]   r0, r1, r2, r3, r4;
      wire [N-1:0] q0, q1, q2, q3, q4;

      assign d0 = dividend_reg[s];
      assign r0 = remainder_reg[s];
      assign q0 = quotient_reg[s];

      // iter 0
      divu_1iter #(.N(N)) u_iter0 (
        .i_remainder (r0),
        .i_divisor   (divisor_reg[s]),
        .i_dividend  (d0),
        .i_quotient  (q0),
        .o_remainder (r1),
        .o_dividend  (d1),
        .o_quotient  (q1)
      );

      // iter 1
      divu_1iter #(.N(N)) u_iter1 (
        .i_remainder (r1),
        .i_divisor   (divisor_reg[s]),
        .i_dividend  (d1),
        .i_quotient  (q1),
        .o_remainder (r2),
        .o_dividend  (d2),
        .o_quotient  (q2)
      );

      // iter 2
      divu_1iter #(.N(N)) u_iter2 (
        .i_remainder (r2),
        .i_divisor   (divisor_reg[s]),
        .i_dividend  (d2),
        .i_quotient  (q2),
        .o_remainder (r3),
        .o_dividend  (d3),
        .o_quotient  (q3)
      );

      // iter 3
      divu_1iter #(.N(N)) u_iter3 (
        .i_remainder (r3),
        .i_divisor   (divisor_reg[s]),
        .i_dividend  (d3),
        .i_quotient  (q3),
        .o_remainder (r4),
        .o_dividend  (d4),
        .o_quotient  (q4)
      );

      // Đăng ký kết quả sang stage s+1
      always @(posedge clk or posedge rst) begin
        if (rst) begin
          dividend_reg[s+1]  <= {N{1'b0}};
          remainder_reg[s+1] <= {(N+1){1'b0}};
          quotient_reg[s+1]  <= {N{1'b0}};
          divisor_reg[s+1]   <= {N{1'b0}};
        end else if (!stall) begin
          dividend_reg[s+1]  <= d4;
          remainder_reg[s+1] <= r4;
          quotient_reg[s+1]  <= q4;
          divisor_reg[s+1]   <= divisor_reg[s]; // divisor "chảy" theo pipeline
        end
        // nếu stall = 1 thì giữ nguyên (freeze pipeline)
      end
    end
  endgenerate

  // Output đăng ký từ stage cuối (stage 8)
  always @(posedge clk or posedge rst) begin
    if (rst) begin
      o_remainder <= {N{1'b0}};
      o_quotient  <= {N{1'b0}};
    end else if (!stall) begin
      // remainder_reg[STAGES] có N+1 bit, mình trả về N bit thấp
      o_remainder <= remainder_reg[STAGES][N-1:0];
      o_quotient  <= quotient_reg[STAGES];
    end
    // stall = 1 thì giữ nguyên output
  end

endmodule

    
    
module divu_1iter #(
    parameter N = 32
)(
    input      [N:0]   i_remainder,   // N+1 bit
    input      [N-1:0] i_divisor,     // N bit
    input      [N-1:0] i_dividend,    // N bit
    input      [N-1:0] i_quotient,    // N bit
    output reg [N:0]   o_remainder,   // N+1 bit
    output reg [N-1:0] o_dividend,    // N bit
    output reg [N-1:0] o_quotient     // N bit
);
    // remainder' = (remainder << 1) | MSB(dividend)
    wire [N:0] shifted_rem = { i_remainder[N-1:0], i_dividend[N-1] };

    // subtract divisor (mở rộng divisor lên N+1 bit)
    wire [N:0] sub_result  = shifted_rem - {1'b0, i_divisor};

    // ge = 1 nếu shifted_rem >= divisor  (sub_result không âm)
    wire       ge          = ~sub_result[N];

    always @* begin
        // dividend luôn dịch trái 1 bit mỗi vòng
        o_dividend = i_dividend << 1;

        if (ge) begin
            // remainder >= divisor -> bit quotient = 1, trừ divisor
            o_remainder = sub_result;
            o_quotient  = { i_quotient[N-2:0], 1'b1 };
        end else begin
            // remainder < divisor -> bit quotient = 0, giữ remainder
            o_remainder = shifted_rem;
            o_quotient  = { i_quotient[N-2:0], 1'b0 };
        end
    end
endmodule

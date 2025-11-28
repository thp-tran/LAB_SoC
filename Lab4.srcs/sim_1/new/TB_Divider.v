`timescale 1ns / 1ps

module tb_divider;

    // =========================
    // Tín hiệu kết nối DUT
    // =========================
    reg         clk;
    reg         rst;
    reg         stall;
    reg  [31:0] dividend;
    reg  [31:0] divisor;
    wire [31:0] quotient;
    wire [31:0] remainder;

    // =========================
    // Instantiate DUT
    // =========================
    DividerUnsignedPipelined dut (
        .clk        (clk),
        .rst        (rst),
        .stall      (stall),
        .i_dividend (dividend),
        .i_divisor  (divisor),
        .o_remainder(remainder),
        .o_quotient (quotient)
    );

    // =========================
    // Tạo clock 100 MHz
    // =========================
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;    // period = 10 ns
    end

    // =========================
    // Task chạy 1 test
    // =========================
    task run_one_test;
        input [31:0] a;
        input [31:0] b;
        input [31:0] exp_q;
        input [31:0] exp_r;
        begin
            $display("\n==============================");
            $display("  TEST: %0d / %0d", a, b);
            $display("==============================");

            // đặt input mới
            dividend = a;
            divisor  = b;

            // vì pipeline có 8 stage, chờ khoảng 12 cạnh dương cho chắc
            repeat (12) @(posedge clk);

            $display("Time %0t ns: quotient = %0d (0x%08h), remainder = %0d (0x%08h)",
                     $time, quotient, quotient, remainder, remainder);

            if (quotient !== exp_q || remainder !== exp_r) begin
                $display("  ==> ERROR: expected q = %0d, r = %0d", exp_q, exp_r);
            end else begin
                $display("  ==> OK");
            end
        end
    endtask

    // =========================
    // Init + chạy các test
    // =========================
    initial begin
        // Khởi tạo
        stall    = 1'b0;
        dividend = 32'd0;
        divisor  = 32'd1;  // tránh chia cho 0
        rst      = 1'b1;

        // Giữ reset một chút
        repeat (3) @(posedge clk);
        rst = 1'b0;

        // Đợi 1 vài clock cho ổn định
        repeat (2) @(posedge clk);

        // --------- TEST 1: 10 / 2 ---------
        // expected: q = 5, r = 0
        run_one_test(32'd10, 32'd2, 32'd5, 32'd0);

        // --------- TEST 2: 100 / 3 ---------
        // expected: q = 33, r = 1
        run_one_test(32'd100, 32'd3, 32'd33, 32'd1);

        // --------- TEST 3: 7 / 3 ----------
        // expected: q = 2, r = 1
        run_one_test(32'd7, 32'd3, 32'd2, 32'd1);

        // --------- TEST 4: 0 / 5 ----------
        // expected: q = 0, r = 0
        run_one_test(32'd0, 32'd5, 32'd0, 32'd0);

        // --------- TEST 5: 31 / 7 ---------
        // expected: q = 4, r = 3
        run_one_test(32'd31, 32'd7, 32'd4, 32'd3);

        $display("\n==== ALL TESTS DONE ====\n");
        $finish;
    end

endmodule

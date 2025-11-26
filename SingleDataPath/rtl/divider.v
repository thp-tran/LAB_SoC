// ============================================================
// Module: divider_unsigned
// Description: 32-bit combinational unsigned divider
// ============================================================
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
            divu_iter #(N) stage (
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

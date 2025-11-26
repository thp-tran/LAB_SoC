`timescale 1ns/1ps

module test_bench;

    reg clk_proc;
    reg clk_mem;
    reg rst;

    wire halt;

    Processor dut(
        .clock_proc(clk_proc),
        .clock_mem(clk_mem),
        .rst(rst),
        .halt(halt)
    );

    // CPU clock
    always #5 clk_proc = ~clk_proc;

    // Memory clock (shift 90 degrees)
    initial begin
        clk_mem = 0;
        #2.5;
        forever #5 clk_mem = ~clk_mem;
    end

    initial begin
        rst = 1;
        clk_proc = 0;

        #20 rst = 0;

        $display("\n===== RUN ADDI / ADD / SUB (NO LOOP) =====\n");

        repeat (20) begin
            @(posedge clk_proc);
            $display("PC=%h  INST=%h",
                dut.datapath.pcCurrent,
                dut.inst_from_imem,
            );
            #1; // IMPORTANT: wait for regfile write-back to complete

            if(dut.datapath.inst_sw) begin
                $display("  MEM[%0d] <= %0d",
                    $signed(dut.datapath.addr_to_dmem),
                    $signed(dut.datapath.rs2_data),
                );
            end else if(dut.datapath.inst_lw) begin
                $display("  R[%0d] <= MEM[%0d] = %0d",
                    dut.datapath.rd,
                    $signed(dut.datapath.addr_to_dmem),
                    $signed(dut.memory.mem_array[dut.datapath.addr_to_dmem >> 2])
                );
            end else begin
            $display("x1=%0d  x2=%0d  x3=%0d  x4=%0d x8=%0d x10=%0d\n HALT=%b",
                $signed(dut.datapath.rf.regs[1]),
                $signed(dut.datapath.rf.regs[2]),
                $signed(dut.datapath.rf.regs[3]),
                $signed(dut.datapath.rf.regs[4]),
                $signed(dut.datapath.rf.regs[8]),
                $signed(dut.datapath.rf.regs[10]),
                halt
            );
            end

            if (halt) begin
                $display("===== CPU HALTED =====");
                $finish;
            end
        end

        $display("===== TIMEOUT =====");
        $finish;
    end

endmodule

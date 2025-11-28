`timescale 1ns / 1ns

// registers are 32 bits in RV32
`define REG_SIZE 31

// RV opcodes are 7 bits
`define OPCODE_SIZE 6

// Don't forget your CLA and Divider
//`include "cla.v"
//`include "DividerUnsignedPipelined.v"

module RegFile (
  input      [        4:0] rd,
  input      [`REG_SIZE:0] rd_data,
  input      [        4:0] rs1,
  output reg [`REG_SIZE:0] rs1_data,
  input      [        4:0] rs2,
  output reg [`REG_SIZE:0] rs2_data,
  input                    clk,
  input                    we,
  input                    rst
);

  localparam NumRegs = 32;

  // Reg array
  reg [31:0] regs [0:NumRegs-1];

  integer i;

  always @(posedge clk or posedge rst) begin
    if (rst) begin
      // clear all registers
      for (i = 0; i < NumRegs; i = i + 1)
        regs[i] <= 32'b0;
    end else begin
      if (we && (rd != 0))
        regs[rd] <= rd_data;   // x0 cannot be written
    end
  end

  // Combinational read
  always @(*) begin
    rs1_data = regs[rs1];
    rs2_data = regs[rs2];
  end

endmodule

// ============================================================================

module DatapathMultiCycle (
    input                    clk,
    input                    rst,
    output reg               halt,
    output     [`REG_SIZE:0] pc_to_imem,
    input      [`REG_SIZE:0] inst_from_imem,
    // addr_to_dmem is a read-write port
    output reg [`REG_SIZE:0] addr_to_dmem,
    input      [`REG_SIZE:0] load_data_from_dmem,
    output reg [`REG_SIZE:0] store_data_to_dmem,
    output reg [        3:0] store_we_to_dmem
);

  // ================= ALU (CLA) =================
  reg [31:0] alu_a;
  reg [31:0] alu_b;
  reg        alu_cin;
  wire [31:0] alu_sum;

  cla alu_cla(
    .a   (alu_a),
    .b   (alu_b),
    .cin (alu_cin),
    .sum (alu_sum),
    .cout_final()
  );

  // ================= Instruction fields =================
  wire [           6:0] inst_funct7;
  wire [           4:0] inst_rs2;
  wire [           4:0] inst_rs1;
  wire [           2:0] inst_funct3;
  wire [           4:0] inst_rd;
  wire [`OPCODE_SIZE:0] inst_opcode;

  assign {inst_funct7, inst_rs2, inst_rs1, inst_funct3, inst_rd, inst_opcode} = inst_from_imem;

  // I, S, B, J immediates
  wire [11:0] imm_i;
  assign imm_i = inst_from_imem[31:20];
  wire [ 4:0] imm_shamt = inst_from_imem[24:20];

  wire [11:0] imm_s;
  assign imm_s = {inst_funct7, inst_rd};

  wire [12:0] imm_b;
  assign {imm_b[12], imm_b[10:1], imm_b[11], imm_b[0]} = {inst_funct7, inst_rd, 1'b0};

  wire [20:0] imm_j;
  assign {imm_j[20], imm_j[10:1], imm_j[11], imm_j[19:12], imm_j[0]} =
         {inst_from_imem[31:12], 1'b0};

  wire [`REG_SIZE:0] imm_i_sext = {{20{imm_i[11]}}, imm_i[11:0]};
  wire [`REG_SIZE:0] imm_s_sext = {{20{imm_s[11]}}, imm_s[11:0]};
  wire [`REG_SIZE:0] imm_b_sext = {{19{imm_b[12]}}, imm_b[12:0]};
  wire [`REG_SIZE:0] imm_j_sext = {{11{imm_j[20]}}, imm_j[20:0]};

  // ================= Opcodes & decode =================
  localparam [`OPCODE_SIZE:0] OpLoad    = 7'b00_000_11;
  localparam [`OPCODE_SIZE:0] OpStore   = 7'b01_000_11;
  localparam [`OPCODE_SIZE:0] OpBranch  = 7'b11_000_11;
  localparam [`OPCODE_SIZE:0] OpJalr    = 7'b11_001_11;
  localparam [`OPCODE_SIZE:0] OpMiscMem = 7'b00_011_11;
  localparam [`OPCODE_SIZE:0] OpJal     = 7'b11_011_11;

  localparam [`OPCODE_SIZE:0] OpRegImm  = 7'b00_100_11;
  localparam [`OPCODE_SIZE:0] OpRegReg  = 7'b01_100_11;
  localparam [`OPCODE_SIZE:0] OpEnviron = 7'b11_100_11;

  localparam [`OPCODE_SIZE:0] OpAuipc   = 7'b00_101_11;
  localparam [`OPCODE_SIZE:0] OpLui     = 7'b01_101_11;

  wire inst_lui    = (inst_opcode == OpLui    );
  wire inst_auipc  = (inst_opcode == OpAuipc  );
  wire inst_jal    = (inst_opcode == OpJal    );
  wire inst_jalr   = (inst_opcode == OpJalr   );

  wire inst_beq    = (inst_opcode == OpBranch ) & (inst_from_imem[14:12] == 3'b000);
  wire inst_bne    = (inst_opcode == OpBranch ) & (inst_from_imem[14:12] == 3'b001);
  wire inst_blt    = (inst_opcode == OpBranch ) & (inst_from_imem[14:12] == 3'b100);
  wire inst_bge    = (inst_opcode == OpBranch ) & (inst_from_imem[14:12] == 3'b101);
  wire inst_bltu   = (inst_opcode == OpBranch ) & (inst_from_imem[14:12] == 3'b110);
  wire inst_bgeu   = (inst_opcode == OpBranch ) & (inst_from_imem[14:12] == 3'b111);

  wire inst_lb     = (inst_opcode == OpLoad   ) & (inst_from_imem[14:12] == 3'b000);
  wire inst_lh     = (inst_opcode == OpLoad   ) & (inst_from_imem[14:12] == 3'b001);
  wire inst_lw     = (inst_opcode == OpLoad   ) & (inst_from_imem[14:12] == 3'b010);
  wire inst_lbu    = (inst_opcode == OpLoad   ) & (inst_from_imem[14:12] == 3'b100);
  wire inst_lhu    = (inst_opcode == OpLoad   ) & (inst_from_imem[14:12] == 3'b101);

  wire inst_sb     = (inst_opcode == OpStore  ) & (inst_from_imem[14:12] == 3'b000);
  wire inst_sh     = (inst_opcode == OpStore  ) & (inst_from_imem[14:12] == 3'b001);
  wire inst_sw     = (inst_opcode == OpStore  ) & (inst_from_imem[14:12] == 3'b010);

  wire inst_addi   = (inst_opcode == OpRegImm ) & (inst_from_imem[14:12] == 3'b000);
  wire inst_slti   = (inst_opcode == OpRegImm ) & (inst_from_imem[14:12] == 3'b010);
  wire inst_sltiu  = (inst_opcode == OpRegImm ) & (inst_from_imem[14:12] == 3'b011);
  wire inst_xori   = (inst_opcode == OpRegImm ) & (inst_from_imem[14:12] == 3'b100);
  wire inst_ori    = (inst_opcode == OpRegImm ) & (inst_from_imem[14:12] == 3'b110);
  wire inst_andi   = (inst_opcode == OpRegImm ) & (inst_from_imem[14:12] == 3'b111);

  wire inst_slli   = (inst_opcode == OpRegImm ) & (inst_from_imem[14:12] == 3'b001) &
                     (inst_from_imem[31:25] == 7'd0);
  wire inst_srli   = (inst_opcode == OpRegImm ) & (inst_from_imem[14:12] == 3'b101) &
                     (inst_from_imem[31:25] == 7'd0);
  wire inst_srai   = (inst_opcode == OpRegImm ) & (inst_from_imem[14:12] == 3'b101) &
                     (inst_from_imem[31:25] == 7'b0100000);

  wire inst_add    = (inst_opcode == OpRegReg ) & (inst_from_imem[14:12] == 3'b000) &
                     (inst_from_imem[31:25] == 7'd0);
  wire inst_sub    = (inst_opcode == OpRegReg ) & (inst_from_imem[14:12] == 3'b000) &
                     (inst_from_imem[31:25] == 7'b0100000);
  wire inst_sll    = (inst_opcode == OpRegReg ) & (inst_from_imem[14:12] == 3'b001) &
                     (inst_from_imem[31:25] == 7'd0);
  wire inst_slt    = (inst_opcode == OpRegReg ) & (inst_from_imem[14:12] == 3'b010) &
                     (inst_from_imem[31:25] == 7'd0);
  wire inst_sltu   = (inst_opcode == OpRegReg ) & (inst_from_imem[14:12] == 3'b011) &
                     (inst_from_imem[31:25] == 7'd0);
  wire inst_xor    = (inst_opcode == OpRegReg ) & (inst_from_imem[14:12] == 3'b100) &
                     (inst_from_imem[31:25] == 7'd0);
  wire inst_srl    = (inst_opcode == OpRegReg ) & (inst_from_imem[14:12] == 3'b101) &
                     (inst_from_imem[31:25] == 7'd0);
  wire inst_sra    = (inst_opcode == OpRegReg ) & (inst_from_imem[14:12] == 3'b101) &
                     (inst_from_imem[31:25] == 7'b0100000);
  wire inst_or     = (inst_opcode == OpRegReg ) & (inst_from_imem[14:12] == 3'b110) &
                     (inst_from_imem[31:25] == 7'd0);
  wire inst_and    = (inst_opcode == OpRegReg ) & (inst_from_imem[14:12] == 3'b111) &
                     (inst_from_imem[31:25] == 7'd0);

  wire inst_mul    = (inst_opcode == OpRegReg ) & (inst_from_imem[31:25] == 7'd1) &
                     (inst_from_imem[14:12] == 3'b000);
  wire inst_mulh   = (inst_opcode == OpRegReg ) & (inst_from_imem[31:25] == 7'd1) &
                     (inst_from_imem[14:12] == 3'b001);
  wire inst_mulhsu = (inst_opcode == OpRegReg ) & (inst_from_imem[31:25] == 7'd1) &
                     (inst_from_imem[14:12] == 3'b010);
  wire inst_mulhu  = (inst_opcode == OpRegReg ) & (inst_from_imem[31:25] == 7'd1) &
                     (inst_from_imem[14:12] == 3'b011);
  wire inst_div    = (inst_opcode == OpRegReg ) & (inst_from_imem[31:25] == 7'd1) &
                     (inst_from_imem[14:12] == 3'b100);
  wire inst_divu   = (inst_opcode == OpRegReg ) & (inst_from_imem[31:25] == 7'd1) &
                     (inst_from_imem[14:12] == 3'b101);
  wire inst_rem    = (inst_opcode == OpRegReg ) & (inst_from_imem[31:25] == 7'd1) &
                     (inst_from_imem[14:12] == 3'b110);
  wire inst_remu   = (inst_opcode == OpRegReg ) & (inst_from_imem[31:25] == 7'd1) &
                     (inst_from_imem[14:12] == 3'b111);

  wire inst_ecall  = (inst_opcode == OpEnviron) & (inst_from_imem[31:7] == 25'd0);
  wire inst_fence  = (inst_opcode == OpMiscMem);

  // ================= Divider control =================
  localparam DIV_WAIT = 12;   // số cycle chờ cho chắc (>= độ sâu pipeline)

  reg        div_busy;
  reg        div_done;
  reg  [3:0] div_count;
  reg [31:0] div_dividend_reg;
  reg [31:0] div_divisor_reg;

  wire [31:0] div_quotient;
  wire [31:0] div_remainder;

  wire is_div_op = inst_div | inst_divu | inst_rem | inst_remu;

  reg        div_is_signed;
  reg        dividend_sign;
  reg        divisor_sign;

  wire [31:0] div_quot_signed;
  wire [31:0] div_rem_signed;

  assign div_quot_signed = (div_is_signed && (dividend_sign ^ divisor_sign))
                           ? -div_quotient
                           :  div_quotient;

  assign div_rem_signed  = (div_is_signed && dividend_sign)
                           ? -div_remainder
                           :  div_remainder;

  // Divider instance (unsigned pipeline)
  DividerUnsignedPipelined divu_pipelined (
    .clk        (clk),
    .rst        (rst),
    .stall      (1'b0),
    .i_dividend (div_dividend_reg),
    .i_divisor  (div_divisor_reg),
    .o_remainder(div_remainder),
    .o_quotient (div_quotient)
  );

  // ================= Program Counter =================
  reg [`REG_SIZE:0] pcNext, pcCurrent;
  always @(posedge clk) begin
    if (rst) begin
      pcCurrent <= 32'd0;
    end else begin
      pcCurrent <= pcNext;
    end
  end
  assign pc_to_imem = pcCurrent;

  // ================= Cycle counters (optional) =================
  reg [`REG_SIZE:0] cycles_current, num_inst_current;
  always @(posedge clk) begin
    if (rst) begin
      cycles_current   <= 0;
      num_inst_current <= 0;
    end else begin
      cycles_current <= cycles_current + 1;
      num_inst_current <= num_inst_current + 1;
    end
  end

  // ================= Register File =================
  wire [`REG_SIZE:0] rs1_data;
  wire [`REG_SIZE:0] rs2_data;
  reg  we;
  reg  [`REG_SIZE:0] rd_data;
  wire [`REG_SIZE:0] alu_out;
  wire [4:0] rd;
  wire [4:0] rs1;
  wire [4:0] rs2;

  RegFile rf (
    .clk      (clk),
    .rst      (rst),
    .we       (we),
    .rd       (rd),
    .rd_data  (rd_data),
    .rs1      (rs1),
    .rs2      (rs2),
    .rs1_data (rs1_data),
    .rs2_data (rs2_data)
  );

  reg [2:0] alu_op;
  localparam ALU_ADD  = 3'b001;
  localparam ALU_SUB  = 3'b010;
  localparam ALU_ADDI = 3'b100;

  reg illegal_inst;

  // ====== Divider FSM (clocked) ======
  always @(posedge clk or posedge rst) begin
    if (rst) begin
      div_busy         <= 1'b0;
      div_done         <= 1'b0;
      div_count        <= 4'd0;
      div_dividend_reg <= 32'd0;
      div_divisor_reg  <= 32'd0;
      div_is_signed    <= 1'b0;
      dividend_sign    <= 1'b0;
      divisor_sign     <= 1'b0;
    end else begin
      if (!div_busy && is_div_op) begin
        // Bắt đầu lệnh chia
        div_busy   <= 1'b1;
        div_done   <= 1'b0;
        div_count  <= 4'd0;

        div_is_signed <= (inst_div | inst_rem);
        dividend_sign <= rs1_data[31];
        divisor_sign  <= rs2_data[31];

        if (inst_div | inst_rem) begin
          // Signed: gửi trị tuyệt đối xuống divider
          div_dividend_reg <= rs1_data[31] ? -rs1_data : rs1_data;
          div_divisor_reg  <= rs2_data[31] ? -rs2_data : rs2_data;
        end else begin
          // Unsigned
          div_dividend_reg <= rs1_data;
          div_divisor_reg  <= rs2_data;
        end

      end else if (div_busy && !div_done) begin
        // Đang chờ pipeline
        if (div_count == DIV_WAIT) begin
          div_done <= 1'b1;      // báo đã sẵn sàng write-back
        end else begin
          div_count <= div_count + 4'd1;
        end

      end else if (div_busy && div_done) begin
        // Sau khi đã ghi rd, đợi PC sang lệnh mới (không còn is_div_op)
        if (!is_div_op) begin
          div_busy  <= 1'b0;
          div_done  <= 1'b0;
          div_count <= 4'd0;
        end
      end
    end
  end

  // ====== Control / Next-state logic (combinational) ======
  always @(*) begin
    // Default values
    we                = 1'b0;
    rd_data           = 32'd0;
    addr_to_dmem      = 32'd0;
    store_data_to_dmem= 32'd0;
    store_we_to_dmem  = 4'b0000;
    pcNext            = pcCurrent + 4;
    illegal_inst      = 1'b0;
    alu_op            = 3'b000;

    // Ưu tiên xử lý DIV/REM
    if (div_busy && !div_done) begin
      // Đang chờ bộ chia → stall PC, không ghi rd
      pcNext = pcCurrent;
      we     = 1'b0;

    end else if (div_busy && div_done) begin
      // Cycle write-back
      pcNext = pcCurrent + 4;
      we     = 1'b1;

      if (inst_divu || inst_div) begin
        // quotient
        rd_data = div_is_signed ? div_quot_signed : div_quotient;
      end else if (inst_remu || inst_rem) begin
        // remainder
        rd_data = div_is_signed ? div_rem_signed : div_remainder;
      end

    end else if (is_div_op) begin
      // Cycle đầu tiên vừa detect lệnh chia: giữ PC, không ghi rd
      pcNext = pcCurrent;
      we     = 1'b0;

    end

    // ===== Không bận chia: decode bình thường =====
    else begin
      if (inst_lui) begin
        // đơn giản: imm[31:20] << 20 (giữ nguyên theo code cũ)
        rd_data = inst_from_imem[31:20] << 20;
        we      = 1'b1;
        pcNext  = pcCurrent + 4;

      end else if (inst_add) begin
        alu_op  = ALU_ADD;
        rd_data = alu_out;
        we      = 1'b1;
        pcNext  = pcCurrent + 4;

      end else if (inst_sub) begin
        alu_op  = ALU_SUB;
        rd_data = alu_out;
        we      = 1'b1;
        pcNext  = pcCurrent + 4;

      end else if (inst_addi) begin
        alu_op  = ALU_ADDI;
        rd_data = alu_out;
        we      = 1'b1;
        pcNext  = pcCurrent + 4;

      end else if (inst_jal) begin
        rd_data = pcCurrent + 4;
        we      = 1'b1;
        pcNext  = pcCurrent + imm_j_sext;

      end else if (inst_jalr) begin
        pcNext  = (rs1_data + imm_i_sext) & ~32'd1;
        rd_data = pcCurrent + 4;
        we      = 1'b1;

      end else if (inst_auipc) begin
        rd_data = pcCurrent + ({{12{inst_from_imem[31]}}, inst_from_imem[31:12]});
        we      = 1'b1;
        pcNext  = pcCurrent + 4;

      end else if (inst_sw) begin
        addr_to_dmem       = rs1_data + imm_s_sext;
        store_data_to_dmem = rs2_data;
        store_we_to_dmem   = 4'b1111;
        we                 = 1'b0;
        pcNext             = pcCurrent + 4;

      end else if (inst_lw) begin
        addr_to_dmem = rs1_data + imm_i_sext;
        rd_data      = load_data_from_dmem;
        we           = 1'b1;
        pcNext       = pcCurrent + 4;

      end else if (inst_beq) begin
        we = 1'b0;
        if (rs1_data == rs2_data)
          pcNext = pcCurrent + imm_b_sext;
        else
          pcNext = pcCurrent + 4;

      end else if (inst_bne) begin
        we = 1'b0;
        if (rs1_data != rs2_data)
          pcNext = pcCurrent + imm_b_sext;
        else
          pcNext = pcCurrent + 4;

      end else if (inst_blt) begin
        we = 1'b0;
        if ($signed(rs1_data) < $signed(rs2_data))
          pcNext = pcCurrent + imm_b_sext;
        else
          pcNext = pcCurrent + 4;

      end else if (inst_bge) begin
        we = 1'b0;
        if ($signed(rs1_data) >= $signed(rs2_data))
          pcNext = pcCurrent + imm_b_sext;
        else
          pcNext = pcCurrent + 4;

      end else if (inst_bltu) begin
        we = 1'b0;
        if (rs1_data < rs2_data)
          pcNext = pcCurrent + imm_b_sext;
        else
          pcNext = pcCurrent + 4;

      end else if (inst_bgeu) begin
        we = 1'b0;
        if (rs1_data >= rs2_data)
          pcNext = pcCurrent + imm_b_sext;
        else
          pcNext = pcCurrent + 4;

      end else if (inst_lb) begin
        addr_to_dmem = rs1_data + imm_i_sext;
        rd_data      = {{24{load_data_from_dmem[7]}}, load_data_from_dmem[7:0]};
        we           = 1'b1;
        pcNext       = pcCurrent + 4;

      end else if (inst_lh) begin
        addr_to_dmem = rs1_data + imm_i_sext;
        rd_data      = {{16{load_data_from_dmem[15]}}, load_data_from_dmem[15:0]};
        we           = 1'b1;
        pcNext       = pcCurrent + 4;

      end else if (inst_lbu) begin
        addr_to_dmem = rs1_data + imm_i_sext;
        rd_data      = {24'd0, load_data_from_dmem[7:0]};
        we           = 1'b1;
        pcNext       = pcCurrent + 4;

      end else if (inst_lhu) begin
        addr_to_dmem = rs1_data + imm_i_sext;
        rd_data      = {16'd0, load_data_from_dmem[15:0]};
        we           = 1'b1;
        pcNext       = pcCurrent + 4;

      end else if (inst_ecall) begin
        we      = 1'b0;
        rd_data = 32'd0;
        pcNext  = pcCurrent + 4;

      end else begin
        rd_data      = 32'd0;
        we           = 1'b0;
        illegal_inst = 1'b1;
      end
    end
  end

  // ====== ALU operand select ======
  always @(*) begin
    case (alu_op)
      ALU_ADD: begin
        alu_a  = rs1_data;
        alu_b  = rs2_data;
        alu_cin = 1'b0;
      end

      ALU_SUB: begin
        alu_a  = rs1_data;
        alu_b  = ~rs2_data;
        alu_cin = 1'b1;
      end

      ALU_ADDI: begin
        alu_a  = rs1_data;
        alu_b  = imm_i_sext;
        alu_cin = 1'b0;
      end

      default: begin
        alu_a  = 0;
        alu_b  = 0;
        alu_cin = 0;
      end
    endcase
  end

  assign alu_out = alu_sum;
  assign rd      = inst_rd;
  assign rs1     = inst_rs1;
  assign rs2     = inst_rs2;

  // ====== Halt on illegal instruction ======
  always @(posedge clk) begin
    if (rst) begin
      halt <= 1'b0;
    end else begin
      if (illegal_inst) begin
        halt <= 1'b1;
      end
    end
  end

endmodule

// ============================================================================

module MemorySingleCycle #(
    parameter NUM_WORDS = 512
) (
  input                    rst,
  input                    clock_mem,
  input      [`REG_SIZE:0] pc_to_imem,
  output reg [`REG_SIZE:0] inst_from_imem,
  input      [`REG_SIZE:0] addr_to_dmem,
  output reg [`REG_SIZE:0] load_data_from_dmem,
  input      [`REG_SIZE:0] store_data_to_dmem,
  input      [        3:0] store_we_to_dmem
);

  reg [`REG_SIZE:0] mem_array[0:NUM_WORDS-1];

  initial begin
    $readmemh("/home/hoang-quan/lab_Soc/Lab4/Lab4.srcs/sources_1/new/mem_initial_contents.hex",
               mem_array);
  end

  localparam AddrMsb = $clog2(NUM_WORDS) + 1;
  localparam AddrLsb = 2;

  always @(posedge clock_mem) begin
    inst_from_imem <= mem_array[pc_to_imem[AddrMsb:AddrLsb]];
  end

  always @(negedge clock_mem) begin
    if (store_we_to_dmem[0]) begin
      mem_array[addr_to_dmem[AddrMsb:AddrLsb]][7:0] <= store_data_to_dmem[7:0];
    end
    if (store_we_to_dmem[1]) begin
      mem_array[addr_to_dmem[AddrMsb:AddrLsb]][15:8] <= store_data_to_dmem[15:8];
    end
    if (store_we_to_dmem[2]) begin
      mem_array[addr_to_dmem[AddrMsb:AddrLsb]][23:16] <= store_data_to_dmem[23:16];
    end
    if (store_we_to_dmem[3]) begin
      mem_array[addr_to_dmem[AddrMsb:AddrLsb]][31:24] <= store_data_to_dmem[31:24];
    end
    load_data_from_dmem <= mem_array[addr_to_dmem[AddrMsb:AddrLsb]];
  end
endmodule

/*
Clock relationship:
        ____
 proc: |    |______
           ____
 mem:  ___|    |___
*/

module Processor (
    input  clock_proc,
    input  clock_mem,
    input  rst,
    output halt
);

  wire [`REG_SIZE:0] pc_to_imem, inst_from_imem;
  wire [`REG_SIZE:0] mem_data_addr, mem_data_loaded_value, mem_data_to_write;
  wire [        3:0] mem_data_we;

  wire [(8*32)-1:0] test_case; // for cocotb

  MemorySingleCycle #(
      .NUM_WORDS(8192)
  ) memory (
    .rst                 (rst),
    .clock_mem           (clock_mem),
    .pc_to_imem          (pc_to_imem),
    .inst_from_imem      (inst_from_imem),
    .addr_to_dmem        (mem_data_addr),
    .load_data_from_dmem (mem_data_loaded_value),
    .store_data_to_dmem  (mem_data_to_write),
    .store_we_to_dmem    (mem_data_we)
  );

  DatapathMultiCycle datapath (
    .clk                 (clock_proc),
    .rst                 (rst),
    .pc_to_imem          (pc_to_imem),
    .inst_from_imem      (inst_from_imem),
    .addr_to_dmem        (mem_data_addr),
    .store_data_to_dmem  (mem_data_to_write),
    .store_we_to_dmem    (mem_data_we),
    .load_data_from_dmem (mem_data_loaded_value),
    .halt                (halt)
  );

endmodule

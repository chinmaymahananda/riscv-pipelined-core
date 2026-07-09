// riscv_core.v -- 4-stage pipelined RV32I subset core (IF -> EX -> MEM -> WB)
// See docs/ARCHITECTURE.md for the full design writeup.
module riscv_core (
    input wire clk,
    input wire rst_n
);
    // ---------------- opcodes ----------------
    localparam OP_RTYPE  = 7'b0110011;
    localparam OP_ITYPE  = 7'b0010011;
    localparam OP_LOAD   = 7'b0000011;
    localparam OP_STORE  = 7'b0100011;
    localparam OP_BRANCH = 7'b1100011;
    localparam OP_JAL    = 7'b1101111;

    localparam ALU_ADD=4'd0, ALU_SUB=4'd1, ALU_AND=4'd2, ALU_OR=4'd3,
               ALU_XOR=4'd4, ALU_SLL=4'd5, ALU_SRL=4'd6, ALU_SLT=4'd7;

    // ================= IF =================
    reg [31:0] pc;
    wire [31:0] instr;
    wire [31:0] pc_plus4 = pc + 32'd4;

    imem u_imem (.pc(pc), .instr(instr));

    // ================= IF/EX pipeline register =================
    reg [31:0] if_ex_instr, if_ex_pc, if_ex_pc_plus4;

    // ================= EX stage: decode (combinational) =================
    wire [6:0] opcode = if_ex_instr[6:0];
    wire [4:0] rd     = if_ex_instr[11:7];
    wire [2:0] funct3 = if_ex_instr[14:12];
    wire [4:0] rs1    = if_ex_instr[19:15];
    wire [4:0] rs2    = if_ex_instr[24:20];
    wire [6:0] funct7 = if_ex_instr[31:25];

    wire [31:0] imm_i = {{20{if_ex_instr[31]}}, if_ex_instr[31:20]};
    wire [31:0] imm_s = {{20{if_ex_instr[31]}}, if_ex_instr[31:25], if_ex_instr[11:7]};
    wire [31:0] imm_b = {{19{if_ex_instr[31]}}, if_ex_instr[31], if_ex_instr[7], if_ex_instr[30:25], if_ex_instr[11:8], 1'b0};
    wire [31:0] imm_j = {{11{if_ex_instr[31]}}, if_ex_instr[31], if_ex_instr[19:12], if_ex_instr[20], if_ex_instr[30:21], 1'b0};

    wire is_rtype  = (opcode == OP_RTYPE);
    wire is_itype  = (opcode == OP_ITYPE);
    wire is_load   = (opcode == OP_LOAD);
    wire is_store  = (opcode == OP_STORE);
    wire is_branch = (opcode == OP_BRANCH);
    wire is_jal    = (opcode == OP_JAL);

    wire reg_write = is_rtype | is_itype | is_load | is_jal;
    wire mem_read  = is_load;
    wire mem_write = is_store;
    wire alu_src_imm = is_itype | is_load | is_store;  // 1 => use immediate as ALU operand B
    // wb_sel: 00 = alu_result, 01 = mem_rdata, 10 = pc_plus4 (JAL)
    wire [1:0] wb_sel = is_load ? 2'b01 : is_jal ? 2'b10 : 2'b00;

    reg [3:0] alu_op;
    always @(*) begin
        if (is_rtype) begin
            case (funct3)
                3'b000:  alu_op = funct7[5] ? ALU_SUB : ALU_ADD;
                3'b001:  alu_op = ALU_SLL;
                3'b010:  alu_op = ALU_SLT;
                3'b100:  alu_op = ALU_XOR;
                3'b101:  alu_op = ALU_SRL;
                3'b110:  alu_op = ALU_OR;
                3'b111:  alu_op = ALU_AND;
                default: alu_op = ALU_ADD;
            endcase
        end else if (is_itype) begin
            case (funct3)
                3'b000:  alu_op = ALU_ADD;
                3'b001:  alu_op = ALU_SLL;
                3'b010:  alu_op = ALU_SLT;
                3'b100:  alu_op = ALU_XOR;
                3'b101:  alu_op = ALU_SRL;
                3'b110:  alu_op = ALU_OR;
                3'b111:  alu_op = ALU_AND;
                default: alu_op = ALU_ADD;
            endcase
        end else if (is_branch) begin
            alu_op = ALU_SUB;   // zero flag => equality
        end else begin
            alu_op = ALU_ADD;   // LOAD/STORE address calc, JAL (unused)
        end
    end

    // ---------------- register file ----------------
    wire [31:0] reg_rdata1, reg_rdata2;
    wire        wb_we;
    wire [4:0]  wb_waddr;
    wire [31:0] wb_wdata;

    regfile u_regfile (
        .clk(clk), .rst_n(rst_n), .we(wb_we), .waddr(wb_waddr), .wdata(wb_wdata),
        .raddr1(rs1), .raddr2(rs2), .rdata1(reg_rdata1), .rdata2(reg_rdata2)
    );

    // ---------------- EX/MEM pipeline register (declared early: needed for forwarding) ----------------
    reg        ex_mem_reg_write, ex_mem_mem_read, ex_mem_mem_write;
    reg [1:0]  ex_mem_wb_sel;
    reg [31:0] ex_mem_alu_result, ex_mem_rs2_data, ex_mem_pc_plus4;
    reg [4:0]  ex_mem_rd;

    // ---------------- forwarding (EX/MEM -> EX only; MEM/WB -> EX is
    // already covered by the regfile's own write-first read) ----------------
    wire fwdA = ex_mem_reg_write && (ex_mem_rd != 5'd0) && (ex_mem_rd == rs1) && !ex_mem_mem_read;
    wire fwdB = ex_mem_reg_write && (ex_mem_rd != 5'd0) && (ex_mem_rd == rs2) && !ex_mem_mem_read;

    wire [31:0] rs1_data = fwdA ? ex_mem_alu_result : reg_rdata1;
    wire [31:0] rs2_data = fwdB ? ex_mem_alu_result : reg_rdata2;

    // ---------------- hazard detection: stall on load-use ----------------
    wire load_use_hazard = ex_mem_mem_read && (ex_mem_rd != 5'd0) &&
                           ((ex_mem_rd == rs1) || (ex_mem_rd == rs2));
    wire stall = load_use_hazard;

    // ---------------- ALU ----------------
    wire [31:0] alu_imm = is_store ? imm_s : imm_i;
    wire [31:0] alu_b   = alu_src_imm ? alu_imm : rs2_data;
    wire [31:0] alu_result;
    wire        alu_zero;
    alu u_alu (.a(rs1_data), .b(alu_b), .op(alu_op), .result(alu_result), .zero(alu_zero));

    // ---------------- branch / jump resolution ----------------
    wire branch_taken = is_branch && (
        (funct3 == 3'b000 && alu_zero)  ||   // BEQ
        (funct3 == 3'b001 && !alu_zero)      // BNE
    );
    wire jal_taken = is_jal;
    wire flush = branch_taken | jal_taken;
    wire [31:0] branch_target = if_ex_pc + imm_b;
    wire [31:0] jal_target    = if_ex_pc + imm_j;

    // ================= IF-stage sequential update =================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            pc <= 32'd0;
        else if (stall)
            pc <= pc;
        else if (flush)
            pc <= jal_taken ? jal_target : branch_target;
        else
            pc <= pc_plus4;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            if_ex_instr <= 32'h00000013; // NOP
            if_ex_pc <= 32'd0;
            if_ex_pc_plus4 <= 32'd4;
        end else if (stall) begin
            if_ex_instr <= if_ex_instr;
            if_ex_pc <= if_ex_pc;
            if_ex_pc_plus4 <= if_ex_pc_plus4;
        end else if (flush) begin
            if_ex_instr <= 32'h00000013; // squash wrong-path fetch
            if_ex_pc <= pc;
            if_ex_pc_plus4 <= pc_plus4;
        end else begin
            if_ex_instr <= instr;
            if_ex_pc <= pc;
            if_ex_pc_plus4 <= pc_plus4;
        end
    end

    // ================= EX/MEM pipeline register =================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n || stall) begin
            ex_mem_reg_write <= 1'b0;
            ex_mem_mem_read  <= 1'b0;
            ex_mem_mem_write <= 1'b0;
        end else begin
            ex_mem_reg_write <= reg_write;
            ex_mem_mem_read  <= mem_read;
            ex_mem_mem_write <= mem_write;
            ex_mem_wb_sel    <= wb_sel;
            ex_mem_alu_result<= alu_result;
            ex_mem_rs2_data  <= rs2_data;
            ex_mem_rd        <= rd;
            ex_mem_pc_plus4  <= if_ex_pc_plus4;
        end
    end

    // ================= MEM stage =================
    wire [31:0] dmem_rdata;
    dmem u_dmem (
        .clk(clk), .we(ex_mem_mem_write), .addr(ex_mem_alu_result),
        .wdata(ex_mem_rs2_data), .rdata(dmem_rdata)
    );

    // ================= MEM/WB pipeline register =================
    reg        mem_wb_reg_write;
    reg [1:0]  mem_wb_wb_sel;
    reg [31:0] mem_wb_alu_result, mem_wb_mem_rdata, mem_wb_pc_plus4;
    reg [4:0]  mem_wb_rd;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mem_wb_reg_write <= 1'b0;
        end else begin
            mem_wb_reg_write  <= ex_mem_reg_write;
            mem_wb_wb_sel     <= ex_mem_wb_sel;
            mem_wb_alu_result <= ex_mem_alu_result;
            mem_wb_mem_rdata  <= dmem_rdata;
            mem_wb_pc_plus4   <= ex_mem_pc_plus4;
            mem_wb_rd         <= ex_mem_rd;
        end
    end

    // ================= WB stage =================
    assign wb_we    = mem_wb_reg_write;
    assign wb_waddr = mem_wb_rd;
    assign wb_wdata = (mem_wb_wb_sel == 2'b01) ? mem_wb_mem_rdata :
                      (mem_wb_wb_sel == 2'b10) ? mem_wb_pc_plus4  :
                                                  mem_wb_alu_result;

endmodule


`timescale 1ns/1ps
module tb_riscv_core;
    reg clk = 0, rst_n = 0;
    integer i, errors;
    reg [31:0] golden [0:31];

    riscv_core dut (.clk(clk), .rst_n(rst_n));
    always #5 clk = ~clk;

    initial begin
        $readmemh("../sim/program.hex", dut.u_imem.mem);
        $readmemh("../sim/golden_regs.hex", golden);

        rst_n = 0;
        repeat (3) @(posedge clk);
        rst_n = 1;

        repeat (100) @(posedge clk);  // generous margin for 23 static instrs + stall + pipeline depth

        errors = 0;
        for (i = 1; i < 32; i = i + 1) begin
            if (dut.u_regfile.regs[i] !== golden[i]) begin
                errors = errors + 1;
                $display("MISMATCH x%0d: rtl=%0d golden=%0d", i, $signed(dut.u_regfile.regs[i]), $signed(golden[i]));
            end
        end

        if (errors == 0)
            $display("*** PASS: all 31 registers bit-exact match golden model ***");
        else
            $display("*** FAIL: %0d/31 registers mismatched ***", errors);

        $finish;
    end
endmodule

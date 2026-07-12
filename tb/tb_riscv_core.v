`timescale 1ns/1ps
module tb_riscv_core;
    reg clk = 0, rst_n = 0;
    integer i, errors;
    reg [31:0] golden [0:31];
    // registers actually written by sim/generate_test.py's program --
    // everything else is legitimately don''t-care (regfile isn''t reset,
    // see rtl/regfile.v).
    integer written_regs [0:14];

    riscv_core dut (.clk(clk), .rst_n(rst_n));
    always #5 clk = ~clk;

    initial begin
        written_regs[0]=1;  written_regs[1]=2;  written_regs[2]=3;  written_regs[3]=4;
        written_regs[4]=5;  written_regs[5]=6;  written_regs[6]=7;  written_regs[7]=8;
        written_regs[8]=9;  written_regs[9]=10; written_regs[10]=11; written_regs[11]=12;
        written_regs[12]=13; written_regs[13]=14; written_regs[14]=18;

        $readmemh("../sim/program.hex", dut.u_imem.mem);
        $readmemh("../sim/golden_regs.hex", golden);

        rst_n = 0;
        repeat (3) @(posedge clk);
        rst_n = 1;

        repeat (100) @(posedge clk);

        errors = 0;
        for (i = 0; i < 15; i = i + 1) begin
            if (dut.u_regfile.regs[written_regs[i]] !== golden[written_regs[i]]) begin
                errors = errors + 1;
                $display("MISMATCH x%0d: rtl=%0d golden=%0d", written_regs[i],
                          $signed(dut.u_regfile.regs[written_regs[i]]), $signed(golden[written_regs[i]]));
            end
        end

        if (errors == 0)
            $display("*** PASS: all 15 written registers bit-exact match golden model ***");
        else
            $display("*** FAIL: %0d/15 registers mismatched ***", errors);

        $finish;
    end
endmodule

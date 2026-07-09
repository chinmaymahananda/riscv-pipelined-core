// imem.v -- instruction ROM, word-addressed (PC[31:2] used as index),
// loaded via $readmemh in the testbench.
module imem #(parameter DEPTH = 256) (
    input  wire [31:0] pc,
    output wire [31:0] instr
);
    reg [31:0] mem [0:DEPTH-1];
    assign instr = mem[pc[31:2]];
endmodule

// dmem.v -- data RAM, word-addressed, synchronous write / combinational read
// (combinational read keeps the 3-stage pipeline''s EX-stage load timing simple:
// address computed and data available in the same cycle).
module dmem #(parameter DEPTH = 256) (
    input  wire        clk,
    input  wire        we,
    input  wire [31:0] addr,
    input  wire [31:0] wdata,
    output wire [31:0] rdata
);
    reg [31:0] mem [0:DEPTH-1];
    assign rdata = mem[addr[31:2]];
    always @(posedge clk) begin
        if (we) mem[addr[31:2]] <= wdata;
    end
endmodule

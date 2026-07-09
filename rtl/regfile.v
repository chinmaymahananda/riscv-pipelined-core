// regfile.v -- 32x32 register file, x0 hardwired to zero, write-first
// (same-cycle write-then-read on the same address returns the new value,
// which is what resolves the ALU-result RAW hazard without stalling).
// Full reset clears all registers to 0 -- avoids X-propagation in
// gate-level simulation later in the ASIC flow.
module regfile (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        we,
    input  wire [4:0]  waddr,
    input  wire [31:0] wdata,
    input  wire [4:0]  raddr1,
    input  wire [4:0]  raddr2,
    output wire [31:0] rdata1,
    output wire [31:0] rdata2
);
    reg [31:0] regs [1:31];  // x0 is not stored, always reads 0
    integer i;

    assign rdata1 = (raddr1 == 0) ? 32'd0 :
                    (we && waddr == raddr1) ? wdata : regs[raddr1];
    assign rdata2 = (raddr2 == 0) ? 32'd0 :
                    (we && waddr == raddr2) ? wdata : regs[raddr2];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 1; i < 32; i = i + 1) regs[i] <= 32'd0;
        end else if (we && waddr != 0) begin
            regs[waddr] <= wdata;
        end
    end
endmodule

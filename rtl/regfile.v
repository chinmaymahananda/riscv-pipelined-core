// regfile.v -- 32x32 register file, x0 hardwired to zero, write-first
// (same-cycle write-then-read on the same address returns the new value,
// which is what resolves the ALU-result RAW hazard without stalling).
// Deliberately NOT reset on rst_n: a full 31-register async reset roughly
// triples the reset fan-in for this block, and real register files
// commonly skip it -- software initializes whatever it actually uses.
// (An earlier version added a reset-all for-loop; that also broke Yosys's
// memory inference during synthesis -- "Multiple edge sensitive events" --
// which is the more concrete reason this version is the right call, not
// just a style preference.)
module regfile (
    input  wire        clk,
    input  wire        we,
    input  wire [4:0]  waddr,
    input  wire [31:0] wdata,
    input  wire [4:0]  raddr1,
    input  wire [4:0]  raddr2,
    output wire [31:0] rdata1,
    output wire [31:0] rdata2
);
    reg [31:0] regs [1:31];  // x0 is not stored, always reads 0

    assign rdata1 = (raddr1 == 0) ? 32'd0 :
                    (we && waddr == raddr1) ? wdata : regs[raddr1];
    assign rdata2 = (raddr2 == 0) ? 32'd0 :
                    (we && waddr == raddr2) ? wdata : regs[raddr2];

    always @(posedge clk) begin
        if (we && waddr != 0) regs[waddr] <= wdata;
    end
endmodule

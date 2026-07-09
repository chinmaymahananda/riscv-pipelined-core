"""
generate_test.py -- defines the test program, assembles it, runs the
independent golden interpreter on the assembled machine code, and
writes both program.hex (for $readmemh into imem) and golden_regs.hex
(expected final register file state) for the testbench to compare
against.
"""
from assembler import assemble, write_hex
from golden_model import run

prog = [
    ('ADDI', 1, 0, 5),        # 0:  x1 = 5
    ('ADDI', 2, 0, 10),       # 1:  x2 = 10
    ('ADD',  3, 1, 2),        # 2:  x3 = 15
    ('ADD',  4, 3, 3),        # 3:  x4 = 30   (forwarding: x3 produced by prev instr)
    ('SUB',  5, 4, 1),        # 4:  x5 = 25
    ('AND',  6, 4, 2),        # 5:  x6 = 10
    ('OR',   7, 1, 2),        # 6:  x7 = 15
    ('XOR',  8, 4, 1),        # 7:  x8 = 27
    ('SLL',  9, 1, 2),        # 8:  x9 = 5 << (10&0x1F) = 5120
    ('SLT', 10, 1, 2),        # 9:  x10 = 1  (5 < 10)
    ('SW',   4, 0, 0),        # 10: mem[0] = x4 (30)
    ('LW',  11, 0, 0),        # 11: x11 = mem[0] = 30
    ('ADD', 12, 11, 11),      # 12: x12 = 60  (load-use hazard: x11 used immediately)
    ('ADDI',13, 0, 100),      # 13: x13 = 100
    ('BEQ',  1, 1, 15),       # 14: always taken -> jump to index 15... wait see note below
]
# NOTE: fixed up below with explicit indices for clarity/correctness --
# see the real program list that follows.

prog = [
    ('ADDI', 1, 0, 5),        # 0:  x1 = 5
    ('ADDI', 2, 0, 10),       # 1:  x2 = 10
    ('ADD',  3, 1, 2),        # 2:  x3 = 15
    ('ADD',  4, 3, 3),        # 3:  x4 = 30
    ('SUB',  5, 4, 1),        # 4:  x5 = 25
    ('AND',  6, 4, 2),        # 5:  x6 = 10
    ('OR',   7, 1, 2),        # 6:  x7 = 15
    ('XOR',  8, 4, 1),        # 7:  x8 = 27
    ('SLL',  9, 1, 2),        # 8:  x9 = 5120
    ('SLT', 10, 1, 2),        # 9:  x10 = 1
    ('SW',   4, 0, 0),        # 10: mem[0] = 30
    ('LW',  11, 0, 0),        # 11: x11 = 30
    ('ADD', 12, 11, 11),      # 12: x12 = 60 (load-use hazard)
    ('ADDI',13, 0, 100),      # 13: x13 = 100
    ('BEQ',  1, 1, 16),       # 14: x1==x1 -> TAKEN, jump to index 16
    ('ADDI',14, 0, 999),      # 15: SKIPPED
    ('ADDI',14, 0, 111),      # 16: x14 = 111  (branch target)
    ('BEQ',  1, 2, 19),       # 17: x1(5)==x2(10)? false -> NOT taken, falls to 18
    ('ADDI',15, 0, 222),      # 18: x15 = 222  (executes, branch not taken)
    ('JAL', 16, 21),          # 19: x16 = pc(19*4)+4 = 80, jump to index 21
    ('ADDI',17, 0, 888),      # 20: SKIPPED
    ('ADDI',18, 0, 77),       # 21: x18 = 77  (jump target)
    ('JAL',  0, 22),          # 22: infinite self-loop (halt idiom)
]

words = assemble(prog)
write_hex(words, 'program.hex')

regs, mem = run(words)
with open('golden_regs.hex', 'w') as f:
    for i in range(32):
        f.write(f"{regs[i] & 0xFFFFFFFF:08x}\n")

print("Golden register values (non-zero only):")
for i in range(32):
    if regs[i] != 0:
        print(f"  x{i} = {regs[i]}")
print(f"mem[0] = {mem[0]}")

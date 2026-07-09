"""
golden_model.py -- independent RV32I interpreter. Decodes raw 32-bit
machine code words (does NOT reuse assembler.py's mnemonic info) and
executes them against a behavioral register-file + memory model. This
is deliberately a from-scratch decode/execute implementation so it can
catch assembler bugs AND RTL bugs independently -- it isn't just a
restatement of the RTL's logic.
"""
import sys

def sign_extend(val, bits):
    if val & (1 << (bits - 1)):
        val -= (1 << bits)
    return val

def run(words, max_steps=2000, mem_size=256):
    regs = [0] * 32
    mem = [0] * mem_size
    pc = 0
    steps = 0
    prev_pc = -1
    while steps < max_steps:
        idx = pc // 4
        if idx >= len(words):
            break
        instr = words[idx]
        opcode = instr & 0x7F
        rd     = (instr >> 7) & 0x1F
        funct3 = (instr >> 12) & 0x7
        rs1    = (instr >> 15) & 0x1F
        rs2    = (instr >> 20) & 0x1F
        funct7 = (instr >> 25) & 0x7F

        next_pc = pc + 4

        if opcode == 0b0110011:  # R-type
            a, b = regs[rs1], regs[rs2]
            if funct3 == 0b000:
                result = (a - b) if funct7 == 0b0100000 else (a + b)
            elif funct3 == 0b001: result = a << (b & 0x1F)
            elif funct3 == 0b010: result = 1 if sign_extend(a,32) < sign_extend(b,32) else 0
            elif funct3 == 0b100: result = a ^ b
            elif funct3 == 0b101: result = (a & 0xFFFFFFFF) >> (b & 0x1F)
            elif funct3 == 0b110: result = a | b
            elif funct3 == 0b111: result = a & b
            else: raise ValueError(f"bad funct3 {funct3:03b} at pc={pc}")
            if rd != 0: regs[rd] = result & 0xFFFFFFFF

        elif opcode == 0b0010011:  # I-type ALU
            imm = sign_extend(instr >> 20, 12)
            a = regs[rs1]
            if funct3 == 0b000: result = a + imm
            elif funct3 == 0b001: result = a << (imm & 0x1F)
            elif funct3 == 0b010: result = 1 if sign_extend(a,32) < imm else 0
            elif funct3 == 0b100: result = a ^ (imm & 0xFFFFFFFF)
            elif funct3 == 0b101: result = (a & 0xFFFFFFFF) >> (imm & 0x1F)
            elif funct3 == 0b110: result = a | (imm & 0xFFFFFFFF)
            elif funct3 == 0b111: result = a & (imm & 0xFFFFFFFF)
            else: raise ValueError(f"bad funct3 {funct3:03b} at pc={pc}")
            if rd != 0: regs[rd] = result & 0xFFFFFFFF

        elif opcode == 0b0000011:  # LW
            imm = sign_extend(instr >> 20, 12)
            addr = (regs[rs1] + imm) & 0xFFFFFFFF
            word_idx = (addr // 4) % mem_size
            if rd != 0: regs[rd] = mem[word_idx]

        elif opcode == 0b0100011:  # SW
            imm11_5 = (instr >> 25) & 0x7F
            imm4_0  = (instr >> 7) & 0x1F
            imm = sign_extend((imm11_5 << 5) | imm4_0, 12)
            addr = (regs[rs1] + imm) & 0xFFFFFFFF
            word_idx = (addr // 4) % mem_size
            mem[word_idx] = regs[rs2] & 0xFFFFFFFF

        elif opcode == 0b1100011:  # BRANCH
            imm12 = (instr >> 31) & 0x1
            imm10_5 = (instr >> 25) & 0x3F
            imm4_1 = (instr >> 8) & 0xF
            imm11 = (instr >> 7) & 0x1
            offset = sign_extend((imm12 << 12) | (imm11 << 11) | (imm10_5 << 5) | (imm4_1 << 1), 13)
            taken = False
            if funct3 == 0b000: taken = (regs[rs1] == regs[rs2])       # BEQ
            elif funct3 == 0b001: taken = (regs[rs1] != regs[rs2])     # BNE
            if taken: next_pc = pc + offset

        elif opcode == 0b1101111:  # JAL
            imm20 = (instr >> 31) & 0x1
            imm19_12 = (instr >> 12) & 0xFF
            imm11 = (instr >> 20) & 0x1
            imm10_1 = (instr >> 21) & 0x3FF
            offset = sign_extend((imm20 << 20) | (imm19_12 << 12) | (imm11 << 11) | (imm10_1 << 1), 21)
            if rd != 0: regs[rd] = pc + 4
            next_pc = pc + offset

        else:
            raise ValueError(f"unknown opcode {opcode:07b} at pc={pc}")

        # detect the JAL x0,0 (self-loop) halt idiom
        if next_pc == pc and opcode == 0b1101111:
            break

        prev_pc = pc
        pc = next_pc & 0xFFFFFFFF
        steps += 1

    return regs, mem

if __name__ == '__main__':
    hexfile = sys.argv[1] if len(sys.argv) > 1 else 'program.hex'
    words = [int(l.strip(), 16) for l in open(hexfile) if l.strip()]
    regs, mem = run(words)
    for i in range(32):
        print(f"x{i}={regs[i]}")

"""
assembler.py -- tiny assembler for this core's RV32I subset.
Encodes a list of (mnemonic, *operands) tuples into 32-bit RV32I machine
code words. Registers given as plain ints (0-31). Immediates as signed
Python ints. Branch/jump targets given as absolute instruction INDEX
(not byte address) for convenience -- converted to a byte-offset
immediate here.
"""

def r_type(funct7, rs2, rs1, funct3, rd, opcode):
    return (funct7 << 25) | (rs2 << 20) | (rs1 << 15) | (funct3 << 12) | (rd << 7) | opcode

def i_type(imm, rs1, funct3, rd, opcode):
    return ((imm & 0xFFF) << 20) | (rs1 << 15) | (funct3 << 12) | (rd << 7) | opcode

def s_type(imm, rs2, rs1, funct3, opcode):
    imm11_5 = (imm >> 5) & 0x7F
    imm4_0  = imm & 0x1F
    return (imm11_5 << 25) | (rs2 << 20) | (rs1 << 15) | (funct3 << 12) | (imm4_0 << 7) | opcode

def b_type(imm, rs2, rs1, funct3, opcode):
    # imm is a byte offset, must be even
    imm12   = (imm >> 12) & 0x1
    imm10_5 = (imm >> 5) & 0x3F
    imm4_1  = (imm >> 1) & 0xF
    imm11   = (imm >> 11) & 0x1
    return (imm12 << 31) | (imm10_5 << 25) | (rs2 << 20) | (rs1 << 15) | (funct3 << 12) | (imm4_1 << 8) | (imm11 << 7) | opcode

def j_type(imm, rd, opcode):
    imm20    = (imm >> 20) & 0x1
    imm10_1  = (imm >> 1) & 0x3FF
    imm11    = (imm >> 11) & 0x1
    imm19_12 = (imm >> 12) & 0xFF
    return (imm20 << 31) | (imm19_12 << 12) | (imm11 << 20) | (imm10_1 << 21) | (rd << 7) | opcode

OP_RTYPE, OP_ITYPE, OP_LOAD, OP_STORE, OP_BRANCH, OP_JAL = 0b0110011, 0b0010011, 0b0000011, 0b0100011, 0b1100011, 0b1101111

def assemble(prog):
    """prog: list of (mnemonic, args...). Branch/jal targets are given as
    instruction INDEX in this same list (converted to byte offset here)."""
    words = []
    for idx, instr in enumerate(prog):
        mnem = instr[0]
        if mnem == 'ADD':    _, rd, rs1, rs2 = instr; words.append(r_type(0b0000000, rs2, rs1, 0b000, rd, OP_RTYPE))
        elif mnem == 'SUB':  _, rd, rs1, rs2 = instr; words.append(r_type(0b0100000, rs2, rs1, 0b000, rd, OP_RTYPE))
        elif mnem == 'AND':  _, rd, rs1, rs2 = instr; words.append(r_type(0b0000000, rs2, rs1, 0b111, rd, OP_RTYPE))
        elif mnem == 'OR':   _, rd, rs1, rs2 = instr; words.append(r_type(0b0000000, rs2, rs1, 0b110, rd, OP_RTYPE))
        elif mnem == 'XOR':  _, rd, rs1, rs2 = instr; words.append(r_type(0b0000000, rs2, rs1, 0b100, rd, OP_RTYPE))
        elif mnem == 'SLL':  _, rd, rs1, rs2 = instr; words.append(r_type(0b0000000, rs2, rs1, 0b001, rd, OP_RTYPE))
        elif mnem == 'SRL':  _, rd, rs1, rs2 = instr; words.append(r_type(0b0000000, rs2, rs1, 0b101, rd, OP_RTYPE))
        elif mnem == 'SLT':  _, rd, rs1, rs2 = instr; words.append(r_type(0b0000000, rs2, rs1, 0b010, rd, OP_RTYPE))
        elif mnem == 'ADDI': _, rd, rs1, imm = instr; words.append(i_type(imm, rs1, 0b000, rd, OP_ITYPE))
        elif mnem == 'ANDI': _, rd, rs1, imm = instr; words.append(i_type(imm, rs1, 0b111, rd, OP_ITYPE))
        elif mnem == 'ORI':  _, rd, rs1, imm = instr; words.append(i_type(imm, rs1, 0b110, rd, OP_ITYPE))
        elif mnem == 'XORI': _, rd, rs1, imm = instr; words.append(i_type(imm, rs1, 0b100, rd, OP_ITYPE))
        elif mnem == 'SLTI': _, rd, rs1, imm = instr; words.append(i_type(imm, rs1, 0b010, rd, OP_ITYPE))
        elif mnem == 'LW':   _, rd, imm, rs1 = instr; words.append(i_type(imm, rs1, 0b010, rd, OP_LOAD))
        elif mnem == 'SW':   _, rs2, imm, rs1 = instr; words.append(s_type(imm, rs2, rs1, 0b010, OP_STORE))
        elif mnem == 'BEQ':  _, rs1, rs2, tgt = instr; words.append(('BEQ', rs1, rs2, tgt, idx))
        elif mnem == 'BNE':  _, rs1, rs2, tgt = instr; words.append(('BNE', rs1, rs2, tgt, idx))
        elif mnem == 'JAL':  _, rd, tgt = instr; words.append(('JAL', rd, tgt, idx))
        elif mnem == 'NOP':  words.append(0x00000013)
        else: raise ValueError(f"unknown mnemonic {mnem}")

    # second pass: resolve branch/jal targets now that we know all indices
    resolved = []
    for w in words:
        if isinstance(w, tuple):
            if w[0] == 'BEQ':
                _, rs1, rs2, tgt, idx = w
                offset = (tgt - idx) * 4
                resolved.append(b_type(offset, rs2, rs1, 0b000, OP_BRANCH))
            elif w[0] == 'BNE':
                _, rs1, rs2, tgt, idx = w
                offset = (tgt - idx) * 4
                resolved.append(b_type(offset, rs2, rs1, 0b001, OP_BRANCH))
            elif w[0] == 'JAL':
                _, rd, tgt, idx = w
                offset = (tgt - idx) * 4
                resolved.append(j_type(offset, rd, OP_JAL))
        else:
            resolved.append(w)
    return resolved

def write_hex(words, path, depth=256):
    with open(path, 'w') as f:
        for w in words:
            f.write(f"{w & 0xFFFFFFFF:08x}\n")
        for _ in range(depth - len(words)):
            f.write("00000013\n")  # pad with NOPs

/*
 * calc -- a live 4-bit calculator. "Your ALU, on the board."
 *
 * Every operation below maps to exactly one native RV32I instruction, so a
 * student can point at a switch setting and then at the corresponding box on
 * their own schematic. The result updates continuously -- there is no compute
 * button -- which makes it easy to sweep an operand and watch the ALU track.
 *
 *   SW[3:0]   operand A
 *   SW[7:4]   operand B
 *   SW[9:8]   operation within the current bank
 *   KEY0      switch banks (bank 0 = ops 0-3, bank 1 = ops 4-7)
 *
 *   HEX5      operation number 0-7
 *   HEX4..3   blank, so the result is the only number on the right
 *   HEX2..0   result, 12 bits, two's complement
 *   LEDR      low 10 bits of the result in binary
 *
 *   op 0 ADD   a + b            op 4 XOR  a ^ b
 *   op 1 SUB   a - b            op 5 SLL  a << b
 *   op 2 AND   a & b            op 6 SRL  a >> b        (logical)
 *   op 3 OR    a | b            op 7 SLT  a < b         (signed)
 *
 * SLT is the interesting one: the switches give unsigned nibbles, so a signed
 * comparison of them would be indistinguishable from an unsigned one. The
 * operands are therefore sign-extended from 4 to 32 bits first, which is done
 * with a left shift followed by an arithmetic right shift -- slli + srai, two
 * more native instructions and a good thing to find in the disassembly.
 *
 * ISA notes: no multiply, divide or modulo anywhere. The shift amounts come
 * from a 4-bit field so they are always in range. Roughly 72 instructions.
 *
 * Build: riscv64-unknown-elf-gcc -march=rv32i -mabi=ilp32 -Os -nostdlib
 *        -ffreestanding -fno-builtin
 */

/* ------------------------------------------------------------------ *
 * Memory-mapped I/O. Duplicated in each program for now; this block
 * moves to a shared io.h once the peripheral set settles.
 * ------------------------------------------------------------------ */
#define MMIO_BASE   0x80000000u

#define LEDR        (*(volatile unsigned int *)(MMIO_BASE + 0x00))  /* W, 10 bits           */
#define SW          (*(volatile unsigned int *)(MMIO_BASE + 0x04))  /* R, 10 bits           */
#define KEY_EDGE    (*(volatile unsigned int *)(MMIO_BASE + 0x0C))  /* R, sticky press latch*/
#define KEY_ACK     (*(volatile unsigned int *)(MMIO_BASE + 0x10))  /* W, write-1-to-clear  */
#define HEX_VAL     (*(volatile unsigned int *)(MMIO_BASE + 0x14))  /* W, 24b -> 6 nibbles  */
#define HEX_EN      (*(volatile unsigned int *)(MMIO_BASE + 0x20))  /* W, 6b digit enable   */

#define KEY0        0x1u

#define OP_ADD  0u
#define OP_SUB  1u
#define OP_AND  2u
#define OP_OR   3u
#define OP_XOR  4u
#define OP_SLL  5u
#define OP_SRL  6u
#define OP_SLT  7u

/*
 * Take and clear any latched button presses. The latch is sticky in hardware
 * so a press is never missed between polls, and clearing is an explicit
 * write rather than a read side effect -- a read-to-clear register would
 * misbehave on a pipelined processor that can replay a load.
 */
static unsigned int key_take(void)
{
    unsigned int e = KEY_EDGE & 0x0Fu;
    if (e)
        KEY_ACK = e;
    return e;
}

/* Sign-extend the low 4 bits of v to a full 32-bit signed value. */
static int sext4(unsigned int v)
{
    return ((int)(v << 28)) >> 28;
}

static unsigned int apply(unsigned int op, unsigned int a, unsigned int b)
{
    switch (op) {
    case OP_ADD: return a + b;
    case OP_SUB: return a - b;
    case OP_AND: return a & b;
    case OP_OR:  return a | b;
    case OP_XOR: return a ^ b;
    case OP_SLL: return a << b;
    case OP_SRL: return a >> b;
    case OP_SLT: return (sext4(a) < sext4(b)) ? 1u : 0u;
    default:     return 0u;
    }
}

int main(void)
{
    unsigned int bank = 0u;

    /* HEX5 and HEX2..0; HEX4 and HEX3 stay dark. */
    HEX_EN = 0x27u;   /* 0b100111 */

    for (;;) {
        unsigned int sw = SW & 0x3FFu;

        /* KEY0 toggles between the two banks of four operations. */
        if (key_take() & KEY0)
            bank ^= 1u;

        unsigned int a  = sw & 0x0Fu;
        unsigned int b  = (sw >> 4) & 0x0Fu;
        unsigned int op = ((sw >> 8) & 0x03u) | (bank << 2);

        unsigned int result = apply(op, a, b);

        LEDR = result & 0x3FFu;

        HEX_VAL = (op << 20) | (result & 0xFFFu);
    }

    return 0;   /* not reached */
}

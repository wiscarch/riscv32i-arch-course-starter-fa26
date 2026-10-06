/*
 * echo -- board bring-up test.
 *
 * The first program to flash on a new board. It exercises every input and
 * output path with almost no logic in between, so if something is wrong with
 * the wrapper, the pin assignments or the student's load/store path, it shows
 * up here rather than inside a real program.
 *
 *   SW[9:0]  -> LEDR[9:0]        (binary view, updates live)
 *   SW[9:0]  -> HEX2..HEX0       (same value in hex)
 *
 * Expected behaviour: flip a switch, the matching LED lights and the hex
 * digits track it. The buttons are unused (KEY1 is the board reset).
 *
 * ISA notes: compiles to lw/sw/slli/or/jal only. No calls, no data section.
 * Roughly 22 instructions.
 *
 * Build: riscv64-unknown-elf-gcc -march=rv32i -mabi=ilp32 -Os -nostdlib
 *        -ffreestanding -fno-builtin
 */

/* ------------------------------------------------------------------ *
 * Memory-mapped I/O. Duplicated in each program for now; this block
 * moves to a shared io.h once the peripheral set settles.
 * ------------------------------------------------------------------ */
#define MMIO_BASE   0x80000000u

#define LEDR        (*(volatile unsigned int *)(MMIO_BASE + 0x00))  /* W, 10 bits            */
#define SW          (*(volatile unsigned int *)(MMIO_BASE + 0x04))  /* R, 10 bits            */
#define HEX_VAL     (*(volatile unsigned int *)(MMIO_BASE + 0x14))  /* W, 24b -> 6 nibbles   */
#define HEX_EN      (*(volatile unsigned int *)(MMIO_BASE + 0x20))  /* W, 6b digit enable    */

int main(void)
{
    /* HEX2..0 show the switches; HEX5..3 stay dark. */
    HEX_EN = 0x07u;   /* 0b000111 */

    for (;;) {
        unsigned int sw  = SW  & 0x3FFu;   /* 10 switches */

        /* Binary on the LEDs, hex on the displays -- the same number shown
           two ways, which is a surprisingly effective thing to point at. */
        LEDR = sw;

        HEX_VAL = sw;
    }

    return 0;   /* not reached */
}

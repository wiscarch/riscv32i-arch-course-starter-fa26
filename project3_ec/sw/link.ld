/*
 * Flat 4 KB image for the FPGA demo SoC.
 *
 * The same image is loaded into both the instruction and data memories; each
 * one simply ignores the region it never addresses. That keeps the toolchain
 * to a single output file and means crt0 needs no .data copy loop.
 *
 *   0x0000  .text     (fetched via the imem port)
 *   ....    .rodata   (loaded via the dmem port)
 *   ....    .bss      (zeroed by crt0)
 *   0x1000  stack top, grows down
 */

OUTPUT_ARCH(riscv)
ENTRY(_start)

MEMORY
{
    RAM (rwx) : ORIGIN = 0x00000000, LENGTH = 4K
}

SECTIONS
{
    .text : {
        KEEP(*(.text.init))          /* crt0 must land at address 0 */
        *(.text .text.*)
    } > RAM

    .rodata : ALIGN(4) {
        *(.rodata .rodata.*)
        *(.srodata .srodata.*)
    } > RAM

    /*
     * .data must be empty. A reset restarts the processor but does not reload
     * memory, so an initialised mutable global would come back holding
     * whatever the previous run left there. Constants belong in .rodata;
     * mutable state belongs in .bss or a local, initialised at runtime.
     * The build checks this and fails if anything lands here.
     */
    .data : ALIGN(4) {
        *(.data .data.*)
        *(.sdata .sdata.*)
    } > RAM

    .bss (NOLOAD) : ALIGN(4) {
        __bss_start = .;
        *(.bss .bss.*)
        *(.sbss .sbss.*)
        *(COMMON)
        . = ALIGN(4);
        __bss_end = .;
    } > RAM

    __stack_top = ORIGIN(RAM) + LENGTH(RAM);

    /DISCARD/ : { *(.comment) *(.note.*) *(.riscv.attributes) }
}

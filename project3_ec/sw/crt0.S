# crt0 -- the C runtime, in full.
#
# Three jobs: give C a stack, zero .bss, call main. If main ever returns we
# execute ebreak, which is how this ISA halts.
#
# Worth pointing students at: this is the entire "runtime" a freestanding C
# program needs. Remove the stack setup and any function call crashes; remove
# the .bss loop and uninitialised globals hold garbage.

    .section .text.init, "ax"
    .globl _start
_start:
    la      sp, __stack_top         # auipc + addi

    la      t0, __bss_start
    la      t1, __bss_end
1:  bgeu    t0, t1, 2f
    sw      zero, 0(t0)
    addi    t0, t0, 4
    j       1b
2:
    call    main                    # auipc + jalr

    ebreak                          # halt: main returned
3:  j       3b                      # belt and braces

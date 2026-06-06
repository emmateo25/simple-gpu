/* Startup code for E203 RISC-V bare-metal firmware.
 *
 * Execution begins here after the mask ROM at 0x00001000 jumps to ITCM (0x80000000).
 * This file must be listed before main.c on the compiler command line so the linker
 * places .text.start at the very beginning of ITCM.
 *
 * Memory layout (from link.ld):
 *   ITCM  0x80000000  16 KB  text + rodata + data (LMA = runtime addr, writable BRAM)
 *   DTCM  0x90000000   8 KB  bss + stack (zero-initialised here; stack grows down)
 */

    .section .text.start,"ax",@progbits
    .globl  _start
    .type   _start, @function
_start:
    /* ---- stack pointer ---- */
    la      sp, __stack_top      /* end of DTCM */

    /* ---- zero .bss (DTCM region) ---- */
    la      t0, __bss_start
    la      t1, __bss_end
    beq     t0, t1, .Lmain
.Lbss:
    sw      zero, 0(t0)
    addi    t0, t0, 4
    blt     t0, t1, .Lbss

    /* ---- call main ---- */
.Lmain:
    call    main

    /* ---- hang if main ever returns ---- */
.Lhang:
    j       .Lhang

    .size _start, . - _start

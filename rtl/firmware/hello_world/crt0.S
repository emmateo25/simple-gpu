.section .init
.global _start
_start:
    /* stack = top of DTCM (8 KB) */
    lui  sp, 0x90002
    addi sp, sp, 0

    /* clear BSS */
    la   a0, _bss_start
    la   a1, _bss_end
1:  bge  a0, a1, 2f
    sw   zero, 0(a0)
    addi a0, a0, 4
    j    1b
2:
    call main

_hang:
    j _hang

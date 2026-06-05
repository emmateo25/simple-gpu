MEMORY {
    ITCM (rxai!w) : ORIGIN = 0x80000000, LENGTH = 16K
    DTCM (wai!rx) : ORIGIN = 0x90000000, LENGTH = 8K
}

SECTIONS {
    .text : {
        *(.init)
        *(.text*)
        *(.rodata*)
    } > ITCM

    .data : {
        *(.data*)
    } > DTCM

    .bss : {
        _bss_start = .;
        *(.bss*)
        *(COMMON)
        _bss_end = .;
    } > DTCM
}

/*
 * Linker script for E203 bare-metal firmware.
 *
 * E203 memory map (from config.v):
 *   ITCM  0x80000000  16 KB  (E203_CFG_ITCM_ADDR_WIDTH = 14, 2^14 = 16384 bytes)
 *   DTCM  0x90000000   8 KB  (E203_CFG_DTCM_ADDR_WIDTH = 13, 2^13 = 8192 bytes)
 *
 * All code, read-only data, and read-write data are placed together in ITCM.
 * ITCM is initialised from ram.hex via $readmemh in e203_itcm_ram.v, so the
 * entire image (text + rodata + data) is pre-loaded before the CPU starts.
 *
 * .bss (zero-initialised data) is in DTCM and zeroed by crt0.S.
 * The stack occupies the top of DTCM and grows downwards.
 */

MEMORY
{
    ITCM (rwx) : ORIGIN = 0x80000000, LENGTH = 16K
    DTCM (rw)  : ORIGIN = 0x90000000, LENGTH = 8K
}

ENTRY(_start)

SECTIONS
{
    /* ---- code + read-only + initialised data → all stored in ITCM ---- */
    .text : ALIGN(4)
    {
        *(.text.start)          /* crt0 _start must be first */
        *(.text .text.*)
        *(.rodata .rodata.*)
        *(.data .data.*)        /* writable data: ITCM is a RAM, so this is fine */
        . = ALIGN(4);
    } > ITCM

    /* ---- zero-initialised data → DTCM ---- */
    .bss : ALIGN(4)
    {
        __bss_start = .;
        *(.bss .bss.*)
        *(COMMON)
        . = ALIGN(4);
        __bss_end = .;
    } > DTCM

    /* Stack at the very top of DTCM, growing downwards */
    __stack_top = ORIGIN(DTCM) + LENGTH(DTCM);

    /DISCARD/ :
    {
        *(.comment)
        *(.note .note.*)
        *(.eh_frame)
    }
}

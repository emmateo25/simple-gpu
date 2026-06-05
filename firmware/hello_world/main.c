#include <stdint.h>
#include "font8x8.h"

/* GPU peripheral: my_periph_example at ICB address 0x1001_4000 */
#define GPU_DATA_REG  (*(volatile uint32_t *)0x10014004UL)

/* Display resolution: 80 columns x 60 rows of 8x8 characters */
#define COLS 80
#define ROWS 60

/* Small delay to let the register_splitter finish writing 4 bytes
   (4 pixel-clock cycles @ ~25 MHz << 1 system-clock cycle @ 18 MHz,
   so even 1 NOP is enough; 8 give comfortable margin). */
static inline void delay(void) {
    int i;
    for (i = 0; i < 8; i++)
        __asm__ volatile("nop");
}

/* Write one character to the GPU BRAM.
   Must be called in left-to-right, top-to-bottom order (col 0..79, row 0..59).
   The register_splitter auto-increments the BRAM write address.            */
static void put_char(uint8_t ch) {
    const uint8_t *g = font8x8[ch & 0x7F];

    /* rows 0-3: 4 bytes packed MSB-first into one 32-bit word */
    GPU_DATA_REG = ((uint32_t)g[0] << 24) | ((uint32_t)g[1] << 16) |
                   ((uint32_t)g[2] <<  8) |  (uint32_t)g[3];
    delay();

    /* rows 4-7 */
    GPU_DATA_REG = ((uint32_t)g[4] << 24) | ((uint32_t)g[5] << 16) |
                   ((uint32_t)g[6] <<  8) |  (uint32_t)g[7];
    delay();
}

/* Write a null-terminated string starting at (col, row).
   Wraps at COLS; stops when the string ends (rest of screen = spaces). */
static void render(const char *msg) {
    int pos = 0;
    int len = 0;
    while (msg[len]) len++;

    for (int row = 0; row < ROWS; row++) {
        for (int col = 0; col < COLS; col++) {
            uint8_t ch = (pos < len) ? (uint8_t)msg[pos++] : ' ';
            put_char(ch);
        }
    }
}

int main(void) {
    render(
        "                                                                                "
        "   SIMPLE GPU - RISCV E203 - TANG PRIMER 20K                                   "
        "                                                                                "
        "   Hello, World!                                                                "
        "                                                                                "
        "   ABCDEFGHIJKLMNOPQRSTUVWXYZ  0123456789                                      "
    );

    while (1) {} /* hang: keep displaying */
    return 0;
}

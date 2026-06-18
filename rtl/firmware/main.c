#include <stdint.h>
#include "font8x8.h"

//======== SCREEN GEOMETRY DEFINITIONS ========
//grid boundaries: 640x480 resolution divided into 8x8 character font cells (80 column by 60 rows)
#define MAX_COLUMNS 80 //horizontal grid blocks: 640 / 8
#define MAX_ROWS 60 //vertical grid blocks: 480 / 8

//======== PHYSICAL HARDWARE MEMORY-MAPPED REGISTERS ========
// Addresses from ICB bus matrix in e203_subsys_perips.v:
//   o4 = UART0    → 0x10013000
//   o5 = GPU      → 0x10014000
//   o3 = GPIO     → 0x10012000
#define MY_GPU_BASE_ADDR  0x10014000  // GPU peripheral (o5 slot)
#define E203_UART_BASE    0x10013000  // UART0 (o4 slot)
#define E203_GPIO_BASE    0x10012000  // GPIO (o3 slot)

/*breakdown pointer interface (from right to left)
    base + offset: calculates the exact physical address destination
    (uint32_t*): treat the number as a 32-bit address pointer
    volatile: forces CPU to execute bus transfer
    "*" deferences the pointer, turning it into an assignable register variable
*/
#define GPU_ADDR_REG  (*(volatile uint32_t*)(MY_GPU_BASE_ADDR + 0x000))  // target BRAM byte address
#define GPU_DATA_REG  (*(volatile uint32_t*)(MY_GPU_BASE_ADDR + 0x004))  // data write channel
#define GPU_CTRL_REG  (*(volatile uint32_t*)(MY_GPU_BASE_ADDR + 0x008))  // control/scroll port

// SiFive UART0 registers
#define UART_TXDATA   (*(volatile uint32_t*)(E203_UART_BASE + 0x00))  // TX data (bit 31 = full)
#define UART_RX_REG   (*(volatile uint32_t*)(E203_UART_BASE + 0x04))  // RX data (bit 31 = empty)
#define UART_TXCTRL   (*(volatile uint32_t*)(E203_UART_BASE + 0x08))  // TX control (bit 0 = txen)
#define UART_RXCTRL   (*(volatile uint32_t*)(E203_UART_BASE + 0x0C))  // RX control (bit 0 = rxen)
#define UART_DIV      (*(volatile uint32_t*)(E203_UART_BASE + 0x18))  // baud divider

// GPIO IOF registers (for UART pin mux)
#define GPIO_IOF_EN   (*(volatile uint32_t*)(E203_GPIO_BASE + 0x38))  // IOF enable
#define GPIO_IOF_SEL  (*(volatile uint32_t*)(E203_GPIO_BASE + 0x3C))  // IOF select (0=IOF0)


//======== UART INITIALIZATION ========
// Must be called before any UART use.
// Configures GPIO IOF, baud rate, and enables TX/RX.
void uart_init(void) {
    // GPIO[16]=RX and GPIO[17]=TX must be routed through IOF0 (UART function)
    GPIO_IOF_SEL &= ~((1u << 16) | (1u << 17)); // select IOF0 (UART) for pins 16,17
    GPIO_IOF_EN  |=  ((1u << 16) | (1u << 17)); // enable IOF mux for pins 16,17

    // Baud rate: 18 MHz / (155+1) = 115,385 Hz ≈ 115,200 baud
    UART_DIV = 155;

    // Enable TX and RX
    UART_TXCTRL = 0x1; // txen = 1
    UART_RXCTRL = 0x1; // rxen = 1
}

//======== UART CHARACTER CAPTURE VIA POLLING ========
uint8_t uart_receive_char(void) { //waits for a character and returns it
    // while bit 31 is 1, FIFO is empty
    while (UART_RX_REG & 0x80000000){ //loop that checks the 31st bit for a change
        //waits dynamically until key on the host PC is pressed
    }
    //loop breaks, the data is extracted (only the bottom 8 bits = ASCII code)
    return (uint8_t)(UART_RX_REG & 0xFF);
}

//======== TERMINAL LINE CLEANING HELPER FUNCTION ========
//wipes out specific row by overwriting blank glyph (all zeros) for all 80 columns
void clear_screen_line(uint32_t row) {
    for (uint32_t col = 0; col < MAX_COLUMNS; col++) {
        //each character cell = 8 consecutive BRAM bytes; compute the byte address
        uint32_t base_byte = ((row * MAX_COLUMNS) + col) * 8;

        //write first 4 bytes (font rows 0-3): set address then send data
        GPU_ADDR_REG = base_byte;        // splitter will write at base_byte..base_byte+3
        GPU_DATA_REG = 0x00000000;       // blank rows 0-3

        //write second 4 bytes (font rows 4-7): advance address then send data
        GPU_ADDR_REG = base_byte + 4;    // splitter will write at base_byte+4..base_byte+7
        GPU_DATA_REG = 0x00000000;       // blank rows 4-7
    }
}

//======== STAGE 2 HELPERS ========

static void write_char_to_bram(uint8_t ch, uint32_t row, uint32_t col) {
    uint32_t word0 = ((uint32_t)font8x8_basic[ch][0] << 24) |
                     ((uint32_t)font8x8_basic[ch][1] << 16) |
                     ((uint32_t)font8x8_basic[ch][2] << 8)  |
                     ((uint32_t)font8x8_basic[ch][3]);
    uint32_t word1 = ((uint32_t)font8x8_basic[ch][4] << 24) |
                     ((uint32_t)font8x8_basic[ch][5] << 16) |
                     ((uint32_t)font8x8_basic[ch][6] << 8)  |
                     ((uint32_t)font8x8_basic[ch][7]);
    uint32_t base_byte = ((row * MAX_COLUMNS) + col) * 8;
    GPU_ADDR_REG = base_byte;
    GPU_DATA_REG = word0;
    GPU_ADDR_REG = base_byte + 4;
    GPU_DATA_REG = word1;
}

static void write_string_to_bram(const char *str, uint32_t row, uint32_t col) {
    for (uint32_t i = 0; str[i] != '\0'; i++) {
        write_char_to_bram((uint8_t)str[i], row, col);
        col++;
        if (col >= MAX_COLUMNS) { col = 0; row++; }
    }
}

// Busy-wait using RISC-V mcycle CSR (counts at the CPU/system clock rate).
// At 18 MHz: pass 180 000 000 for a 10-second hold.
static void delay_mcycles(uint32_t cycles) {
    uint32_t start, now;
    asm volatile("csrr %0, mcycle" : "=r"(start));
    do {
        asm volatile("csrr %0, mcycle" : "=r"(now));
    } while ((uint32_t)(now - start) < cycles);
}

int main(void) {
    //======== HARDWARE INITIALIZATION ========
    uart_init();                    // configure GPIO IOF, baud rate, enable UART
    init_lowercase_font_fallback(); //copies A-Z glyphs into a-z slots at runtime

    //======== CURSOR INITIALIZATION ========
    //cursor variables as flashing terminal cursor (start from top-left corner of the screen)
    uint32_t cursor_col = 0;
    uint32_t cursor_row = 0;

    //======== POWER-UP SCREEN CLEARING ========
    //clear display grid area with clear_screen_line function
    //to prevent glitch text or random memory noise when the FPGA powers up
    for (uint32_t r = 0; r < MAX_ROWS; r++) {
        clear_screen_line(r);
    }

    //======== STAGE 2: STATIC TEXT DISPLAY ========
    // Write "SIMPLE GPU" at top-left (row 0, col 0).
    // Lowercase is remapped to uppercase by init_lowercase_font_fallback,
    // so the string renders as SIMPLE GPU either way.
    write_string_to_bram("SIMPLE GPU", 0, 0);

    // Hold Stage 2 for 10 seconds (18 MHz × 10 = 180 000 000 mcycle ticks).
    delay_mcycles(180000000u);

    // Clear the screen before entering the interactive terminal.
    for (uint32_t r = 0; r < MAX_ROWS; r++) {
        clear_screen_line(r);
    }

    //======== MAIN TERMINAL LOOP ========
    //infinite loop (embedded system have no operating system to exit to)
    //so, it runs until power is cutted off
    while(1){
        uint8_t incoming_ascii = uart_receive_char(); //read out incoming user byte from the terminal

        //check if user hits return (carriage return '\r') o enter (carriage newline '\n')
        if (incoming_ascii == '\n' || incoming_ascii == '\r') {
            cursor_col = 0; //return the horizontal cursor back to the far left margin
            cursor_row++; //advance the cursor down to the next row 

            //handle vertical boundary checks (if enter is pressed at row 60)
            if (cursor_row >= MAX_ROWS) {
                cursor_row = MAX_ROWS - 1; //force the position locked onto the last row
                GPU_CTRL_REG = 0x01; //command hardware register to scroll up
                clear_screen_line(cursor_row); //clean out old text on this line
            }
            continue; //skips the loop logic and waits for a new character
        }

        //======== DATA PACKING FOR THE 32-BIT ICB BUS ========
        //fetches row slices from "font8x8.h"
        //condense rows 0 to 3 into the first 32-bit transaction frame
        uint32_t word0 =((uint32_t)font8x8_basic[incoming_ascii][0] << 24) |
                        ((uint32_t)font8x8_basic[incoming_ascii][1] << 16) |
                        ((uint32_t)font8x8_basic[incoming_ascii][2] << 8)  |
                        ((uint32_t)font8x8_basic[incoming_ascii][3]);

        //condense rows 4 to 7 into the second 32-bit transaction frame
        uint32_t word1 =((uint32_t)font8x8_basic[incoming_ascii][4] << 24) |
                        ((uint32_t)font8x8_basic[incoming_ascii][5] << 16) |
                        ((uint32_t)font8x8_basic[incoming_ascii][6] << 8)  |
                        ((uint32_t)font8x8_basic[incoming_ascii][7]);

        //======== BUS SHIPMENT TRANSACTIONS ========
        //compute BRAM byte address: each cell = 8 bytes, byte 0 = (row*80+col)*8
        uint32_t base_byte = ((cursor_row * MAX_COLUMNS) + cursor_col) * 8;

        GPU_ADDR_REG = base_byte;    // splitter loads this as start address for word0
        GPU_DATA_REG = word0;        // font rows 0-3 → splitter writes BRAM bytes 0..3

        GPU_ADDR_REG = base_byte + 4; // advance address for word1
        GPU_DATA_REG = word1;         // font rows 4-7 → splitter writes BRAM bytes 4..7

        //======== LINE WRAPPING CONDITIONS and MANAGEMENT LOGIC ========               
        cursor_col++; //move cursor to the right for the next character
        if (cursor_col >= MAX_COLUMNS) { //when reaches the last column
            cursor_col = 0; //moves to the first column
            cursor_row++; //moves to the next line

            //check if reach the bottom of the screen (row 60)
            if (cursor_row >= MAX_ROWS) {
                cursor_row = MAX_ROWS - 1; //cursor locked to last row
                GPU_CTRL_REG = 0x01; //trigger linux terminal shift
                clear_screen_line(cursor_row);
            }
        }
    }
    return 0;
}

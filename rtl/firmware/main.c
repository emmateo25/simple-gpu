#include <stdint.h>
#include "font8x8.h"

//======== SCREEN GEOMETRY DEFINITIONS ========
//grid boundaries: 640x480 resolution divided into 8x8 character font cells (80 column by 60 rows)
#define MAX_COLUMNS 80 //horizontal grid blocks: 640 / 8
#define MAX_ROWS 60 //vertical grid blocks: 480 / 8

//======== PHYSICAL HARDWARE MEMORY-MAPPED REGISTERS ========
//CHIEDI BASE ADDRESS a chi fa SoCTop
#define MY_GPU_BASE_ADDR 0x10014000 // target address of the GPU on the ICB Bus
#define E203_UART_BASE 0x1001300 // base address of the E203-s build-in UART

/*breakdown pointer interface (from right to left)    
    base + offset: calculates the exact physical address destination
    (uint32_t*): treat the number as a 32-bit address pointer
    volatile: forces CPU to execute bus transfer
    "*" deferences the pointer, turning it into an assignable register variable 
*/
#define GPU_ADDR_REG (*(volatile uint32_t*)(MY_GPU_BASE_ADDR + 0x000))  //target cell address
#define GPU_DATA_REG (*(volatile uint32_t*)(MY_GPU_BASE_ADDR + 0x004))  //data write channel
#define GPU_CTRL_REG (*(volatile uint32_t*)(MY_GPU_BASE_ADDR + 0x008))  //control/scroll port

#define UART_RX_REG (*(volatile uint32_t*)(E203_UART_BASE + 0x04)) //RX data register


//======== UART CHARACTER CAPTURE VIA POLLING ========
uint8_t uart_receive_char(void) { //waits for a character and returns it
    // while bit 31 is 1, FIFO is empty
    while (UART_RX_REG & 0x800000000){ //loop that checks the 31st bit for a change
        //waits dynamically until key on the host PC is pressed
    }
    //loop breaks, the data is extracted (only the bottom 8 bits = ASCII code)
    return (uint8_t)(UART_RX_REG & 0xFF);
}

//======== TERMINAL LINE CLEANING HELPER FUNCTION ========
//wipes out specific row by overwriting ' ' (hex code 0x20) for all the 80 columns
void clear_screen_line(uint32_t row) {  //uint32_t = index number row that will be cleared
    for (uint32_t col = 0; col < MAX_COLUMNS; col++) { //loop through every horizontal block position of a specific row
        uint32_t target_cell = (row * MAX_COLUMNS) + col; //transform 2D grid into 1D memory array index
        //pack rows into 32-bit variables to ship across ICB Bus
        uint32_t space_word0 = 0x00000000; //holds rows 0, 1, 2, 3
        uint32_t space_word1 = 0x00000000; //holds rows 4, 5, 6, 7

        //write flat grid index into GPU Address Register, to force the physical address wire 
        //on the ICB Bus to prepare the memory inside cell number [target_cell]
        GPU_ADDR_REG = target_cell;

        //handles the first 32-bit block (cointain rows 0-3) down the data wires
        //when the Verilog code sees a write on this register, it catches it 
        //and hands it over the Dual-Port RAM
        GPU_DATA_REG = space_word0;

        //handles the second 32-bit block (cointain rows 4-7) down the data wires
        //'register_splitter' module takes these bytes and overwrites the 
        //8x8 font grid area inside the video memory for this block
        GPU_DATA_REG = space_word1;
    }
}

int main(void) {
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
        //map current text cursor grid position to unique memory  address cell = (row * 80) + column
        uint32_t cell_address = (cursor_row * MAX_COLUMNS) + cursor_col;
        GPU_ADDR_REG = cell_address; // inform peripheral of target cell (for future addr-based hw)
        GPU_DATA_REG = word0;        // font rows 0-3 → splitter writes BRAM bytes 0..3
        GPU_DATA_REG = word1;        // font rows 4-7 → splitter writes BRAM bytes 4..7

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

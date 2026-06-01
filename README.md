# simple-gpu
intelligent chip final project

**Membri:** Emma Teodorani, Camilla Malossi, Ginevra Boltim

**Descrizione:** 
Design a HDMI display module for RISC-V, mounted on the ICB bus of Hummingbird E203, can display ASCII characters received from UART.

**Basic Requirments**
1-HDMI signal can be output from Tang primer 20k board, displaying color strips at power-up;
2-After diplay color strips for 5 seconds, the LCD monitor can display black/white charactors showing some info like the content you can receive through UART at power up(with the demo system of e203).
3-Supporting display resolution at least 640 x 480 @60Hz.
4-Display ASCII charactors received from UART.

**NOTE: With the limit of internal SRAM in GW2A-18 FPGA, the charactors to be displayed can be monochrome. Even for this requirments, a image of 640 x 480 resolution will still consume 38.4KB SRAM, while the total available SRAM for Tang primer 20k is about 100KB. **

**Bonus Requirments**
1-achieve higher display resolution;
2-The position of charactor can be assigned by software.
3-Can acts like a linux terminal, that is, as you input charactors through UART from PC, the display position can automatically shift.

**NOTE: These tasks must be achieved on FPGA board. **

**Link alla documentazione:**

## Suddivisione compiti

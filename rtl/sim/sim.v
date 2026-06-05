`timescale 1ns/10ps
`define USING_IVERILOG
//`define USING_VCS

module sys_tb_top();
//clock and reset signals 
reg clk;
reg rst_n;
reg lfextclk;

//signal assignments
wire hfclk = clk;
wire uart_rx;
wire [31:0] gpio;
assign uart_rx = gpio[17];

// Waveform generation for Icarus Verilog
`ifdef USING_IVERILOG
initial begin
    $dumpfile("waveout.vcd");
    $dumpvars(0, sys_tb_top);
end
`endif

// Waveform generation for VCS
`ifdef USING_VCS
initial begin
$fsdbDumpfile("test.fsdb");
$fsdbDumpvars;
end
`endif

//simulation end condition 
initial begin
    // Run the simulation for a certain amount of time or until a specific condition is met
    #150ms; // Run for 150 milliseconds
    $finish; // End the simulation
end

//initial conditions 
initial begin 
    clk<=0;
    lfextclk<=0;
    rst_n<=0;
    #320us rst_n<=1; // Release reset after 320 microseconds
end

//clock generation:27 MHz
always begin 
    #18.5185ns clk <= ~clk; // Toggle clock every 18.5185 nanoseconds for a 27 MHz clock
end

//Low frequency clock generation: 33 kHz
always begin
    #33 lfextclk <= ~lfextclk; // Toggle low frequency clock every 33 microseconds for a 33 kHz clock
end

//UART data transfer setup 
int uart_tx_period=1e9/115200; // Calculate the period for 115200 baud rate
int uart_rx_period=8750; // Calculate the period for receiving data at 115200 baud rate (10 bits per character)

//UART signal declaration 
reg [31:0] gpio_in; //default value bit 16 is set to 1, which indicates that the UART is ready to receive data
reg [31:0] gpio_out; //bit 17 is uart rx

reg [7:0] uart_rx_byte; // Variable to hold the received byte from UART

//UART transmissio task 
task uart_tx_data (input bit [7:0] tx_data);
    //1 bit start bit 
    gpio_in[16] = 1'b0;
    #uart_tx_period;
    // 8 bit data: LSB first
    for (int i = 0; i < 8; i++) begin
        gpio_in[16] = tx_data[i];
        #uart_tx_period;
    end
    // 1 bit stop bit
    gpio_in[16] = 1'b1;
    #uart_tx_period;
endtask

// Reading file and sending data to e203 core
initial begin
    reg [7:0] sim_data[3:0];
    gpio_in[16] = 1'b1; // UART TX idle state is high
    $readmemh("./input.txt", sim_data); // Load data from input.txt into sim_data array

    #7ms; // Wait for system to stabilize
    
    foreach (sim_data[x]) begin
        $display("tx_data[%x] = %x", x, sim_data[x]); // Display data being sent
        uart_tx_data(sim_data[x]); // Transmit each byte via UART
    end
end


// Instantiating the e203_soc_demo module
e203_soc_demo uut (
    .clk_in (clk),
    .tck (),
    .tms (),
    .tdi (),
    .tdo (),
    .gpio_in (gpio_in),
    .gpio_out (gpio_out),
    .qspi_in (),
    .qspi_out (),
    .qspi_sck (),
    .qspi_cs (),
    .erstn (rst_n),
    .dbgmode0_n (1'b1),
    .dbgmode1_n (1'b1),
    .dbgmode3_n (1'b1),
    .bootrom_n (1'b0),
    .aon_pmu_dwakeup_n (),
    .aon_pmu_padrst (),
    .aon_pmu_vddpaden ()
);
endmodule
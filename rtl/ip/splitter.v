// SPLITTER
//. TEST

/*
`timescale 1ns / 1ps

module tb_register_splitter();

reg         clk;
reg  [31:0] data_in_32;
wire [7:0]  data_out_8;
wire [15:0] address;
wire        write_enable;

// Istanza del modulo
register_splitter uut (
    .clk(clk),
    .data_in_32(data_in_32),
    .data_out_8(data_out_8),
    .address(address),
    .write_enable(write_enable)
);

// Clock: periodo 10ns
initial begin
    clk = 1'b0;
    forever #5 clk = ~clk;
end

// Test: un solo dato di esempio
initial begin
    // Inizializza
    data_in_32 = 32'd0;
    
    // Aspetta qualche ciclo
    #20;
    
    // Inserisci un dato di esempio (es. 0x12345678)
    data_in_32 = 32'h12345678;
    
    // Aspetta che il modulo processi tutti i 4 byte
    #60;
    
    // Fine simulazione
    $finish;
end

// Dumpfile per Surfer (formato VCD)
initial begin
    $dumpfile("splitter.vcd");
    $dumpvars(0, tb_register_splitter);
end

endmodule

*/


module register_splitter (
    input wire clk,
    input wire [31:0] data_in_32,
    output reg [7:0] data_out_8,
    output reg [15:0] address,
    output reg write_enable
);

reg [7:0] reg_array [0:3]; // Array to hold the 4 bytes of the 32-bit input
reg [15:0] addr_counter = 0; //keeps track of the memory address where the next byte will be written
reg data_valid = 1'b0; //flag for indicating validity of output from reg_array
reg [31:0] prev_data_in_32 = 32'd0; // Register to hold previous data_in_32
reg [1:0] byte_index = 2'b00; // To track which byte we are writing from reg_array

// Always block for data splitting and flagging
always @(posedge clk) begin
    if (data_in_32 != prev_data_in_32) begin // Detect new data
    reg_array[3] <= {data_in_32[0], data_in_32[1], data_in_32[2], data_in_32[3],
                     data_in_32[4], data_in_32[5], data_in_32[6], data_in_32[7]};
    reg_array[2] <= {data_in_32[8], data_in_32[9], data_in_32[10], data_in_32[11],
                     data_in_32[12], data_in_32[13], data_in_32[14], data_in_32[15]};
    reg_array[1] <= {data_in_32[16], data_in_32[17], data_in_32[18], data_in_32[19],
                     data_in_32[20], data_in_32[21], data_in_32[22], data_in_32[23]};
    reg_array[0] <= {data_in_32[24], data_in_32[25], data_in_32[26], data_in_32[27],
                     data_in_32[28], data_in_32[29], data_in_32[30], data_in_32[31]};
    data_valid <= 1'b1; // Mark data as valid
    prev_data_in_32 <= data_in_32; // Update previous data
    byte_index <= 2'b00; // Reset byte index for new data
    end
end

// Always block for output and address increment
always @(posedge clk) begin
    if (data_valid) begin
    data_out_8 <= reg_array[byte_index];
    address <= addr_counter;
    write_enable <= 1'b1;    // Enable write for each byte

    byte_index <= byte_index + 2'b01; // Increment byte index and address counter
    addr_counter <= addr_counter + 1;

    if (byte_index == 2'b11) begin    // Reset data_valid after processing 4 bytes, it works thanks to the non-blocking 
    data_valid <= 1'b0;
    end

    end else begin
    write_enable <= 1'b0;    // Disable write if no new data
    end
end
endmodule
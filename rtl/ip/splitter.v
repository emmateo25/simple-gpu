// register_splitter
// Receives a 32-bit word from the ICB peripheral and sequentially writes its
// four bytes into the dual-port BRAM one byte per clock cycle.
//
// Byte ordering: MSB first.
//   cycle 0: data_in_32[31:24]  (font row 0 if word0 layout used in firmware)
//   cycle 1: data_in_32[23:16]  (font row 1)
//   cycle 2: data_in_32[15:8]   (font row 2)
//   cycle 3: data_in_32[7:0]    (font row 3)
// The address counter increments by 1 each cycle so the four bytes land in
// four consecutive BRAM locations.

module register_splitter (
    input  wire        clk,
    input  wire [31:0] data_in_32,
    output reg  [7:0]  data_out_8,
    output reg  [15:0] address,
    output reg         write_enable
);

// Internal byte array: index 0 = MSB byte, index 3 = LSB byte
reg [7:0]  reg_array [0:3];

reg [15:0] addr_counter;
reg        data_valid;
reg [31:0] prev_data_in_32;
reg [1:0]  byte_index;

initial begin
    addr_counter     = 16'd0;
    data_valid       = 1'b0;
    prev_data_in_32  = 32'd0;
    byte_index       = 2'b00;
end

// Detect new data and latch the four bytes (MSB-first, no bit reversal)
always @(posedge clk) begin
    if (data_in_32 != prev_data_in_32) begin
        reg_array[0]    <= data_in_32[31:24];  // most-significant byte first
        reg_array[1]    <= data_in_32[23:16];
        reg_array[2]    <= data_in_32[15:8];
        reg_array[3]    <= data_in_32[7:0];    // least-significant byte last
        prev_data_in_32 <= data_in_32;
        data_valid      <= 1'b1;
        byte_index      <= 2'b00;
    end
end

// Output bytes sequentially and advance the BRAM write address
always @(posedge clk) begin
    if (data_valid) begin
        data_out_8   <= reg_array[byte_index];
        address      <= addr_counter;
        write_enable <= 1'b1;

        addr_counter <= addr_counter + 16'd1;
        byte_index   <= byte_index + 2'b01;

        if (byte_index == 2'b11)
            data_valid <= 1'b0;   // all 4 bytes sent; clear flag
    end else begin
        write_enable <= 1'b0;
    end
end

endmodule


// ======== TESTBENCH (commented out) ========
/*
`timescale 1ns / 1ps

module tb_register_splitter();

reg         clk;
reg  [31:0] data_in_32;
wire [7:0]  data_out_8;
wire [15:0] address;
wire        write_enable;

register_splitter uut (
    .clk          (clk),
    .data_in_32   (data_in_32),
    .data_out_8   (data_out_8),
    .address      (address),
    .write_enable (write_enable)
);

initial clk = 1'b0;
always #5 clk = ~clk;   // 100 MHz test clock

initial begin
    data_in_32 = 32'd0;
    #20;
    data_in_32 = 32'h12345678;  // expect bytes: 0x12, 0x34, 0x56, 0x78
    #60;
    $finish;
end

initial begin
    $dumpfile("splitter.vcd");
    $dumpvars(0, tb_register_splitter);
end

endmodule
*/

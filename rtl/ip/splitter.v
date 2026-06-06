// register_splitter
// Receives a 32-bit word from the ICB peripheral and sequentially writes its
// four bytes into the dual-port BRAM one byte per clock cycle.
//
// Triggering: write_strobe must pulse for one clock cycle to start a transfer.
// This replaces the previous change-detection scheme, which silently dropped
// writes when the same 32-bit value was sent twice (e.g. blanking with 0x00).
//
// Addressing: addr_in carries the BRAM byte address for byte[0] of this word,
// set by the CPU before each GPU_DATA_REG write.  The remaining three bytes
// land at addr_in+1, addr_in+2, addr_in+3 automatically.
//
// Byte ordering: MSB first.
//   cycle 0: data_in_32[31:24]  → addr_in+0
//   cycle 1: data_in_32[23:16]  → addr_in+1
//   cycle 2: data_in_32[15:8]   → addr_in+2
//   cycle 3: data_in_32[7:0]    → addr_in+3

module register_splitter (
    input  wire        clk,
    input  wire [31:0] data_in_32,
    input  wire        write_strobe,  // 1-cycle pulse: start a new 4-byte write
    input  wire [15:0] addr_in,       // BRAM byte address for the first byte
    output reg  [7:0]  data_out_8,
    output reg  [15:0] address,
    output reg         write_enable
);

// Internal byte array: index 0 = MSB byte, index 3 = LSB byte
reg [7:0]  reg_array [0:3];
reg [15:0] addr_base;
reg        data_valid;
reg [1:0]  byte_index;

initial begin
    data_valid  = 1'b0;
    byte_index  = 2'b00;
    addr_base   = 16'd0;
end

// Single always block.
// Priority:
//   1. write_strobe && !data_valid  → latch new data + address, arm data_valid
//   2. data_valid                   → output one byte per cycle
//   3. idle                         → deassert write_enable
always @(posedge clk) begin
    if (write_strobe && !data_valid) begin
        // Latch new 32-bit word and starting BRAM byte address
        reg_array[0] <= data_in_32[31:24];
        reg_array[1] <= data_in_32[23:16];
        reg_array[2] <= data_in_32[15:8];
        reg_array[3] <= data_in_32[7:0];
        addr_base    <= addr_in;
        data_valid   <= 1'b1;
        byte_index   <= 2'b00;
        write_enable <= 1'b0;  // hold write low this cycle; output starts next cycle
    end else if (data_valid) begin
        data_out_8   <= reg_array[byte_index];
        address      <= addr_base + {14'd0, byte_index};
        write_enable <= 1'b1;
        byte_index   <= byte_index + 2'b01;
        if (byte_index == 2'b11)
            data_valid <= 1'b0;   // all 4 bytes sent; clear flag
    end else begin
        write_enable <= 1'b0;
    end
end

endmodule

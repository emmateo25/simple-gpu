// ICB peripheral for the simple GPU.
// Exposes three 32-bit memory-mapped registers to the RISC-V CPU:
//
//   Offset 0x000  GPU_ADDR_REG  – target character-cell address
//   Offset 0x004  GPU_DATA_REG  – 32-bit font data (rows 0-3 or 4-7)
//   Offset 0x008  GPU_CTRL_REG  – control / scroll command register
//
// io_pad_out is wired to GPU_DATA_REG so the register_splitter can forward
// each write to the dual-port BRAM.  GPU_ADDR_REG and GPU_CTRL_REG are
// available for read-back but are not yet forwarded to hardware scroll logic
// (that is an extended-feature task).

module my_periph_example(
    input                   clk,
    input                   rst_n,

    // ICB command channel
    input                   i_icb_cmd_valid,
    output                  i_icb_cmd_ready,
    input  [31:0]           i_icb_cmd_addr,
    input                   i_icb_cmd_read,
    input  [31:0]           i_icb_cmd_wdata,

    // ICB response channel
    output                  i_icb_rsp_valid,
    input                   i_icb_rsp_ready,
    output [31:0]           i_icb_rsp_rdata,

    output                  io_interrupts_0_0,  // interrupt line (unused, tied low)
    output [31:0]           io_pad_out,         // GPU_DATA_REG value to register splitter
    output                  io_data_strobe,     // 1-cycle pulse each time GPU_DATA_REG is written
    output [15:0]           io_bram_addr        // GPU_ADDR_REG value (BRAM byte address from firmware)
);

// ---- internal registers ----
reg [31:0] gpu_addr_reg;   // offset 0x000
reg [31:0] gpu_data_reg;   // offset 0x004
reg [31:0] gpu_ctrl_reg;   // offset 0x008

reg [31:0] icb_data_out;
reg        icb_rsp_valid_r;
reg        io_data_strobe_r;  // registered wr_data: 1-cycle pulse when GPU_DATA_REG written

// ---- address decode helpers ----
wire addr_sel_addr = i_icb_cmd_valid && (i_icb_cmd_addr[11:0] == 12'h000);
wire addr_sel_data = i_icb_cmd_valid && (i_icb_cmd_addr[11:0] == 12'h004);
wire addr_sel_ctrl = i_icb_cmd_valid && (i_icb_cmd_addr[11:0] == 12'h008);

wire wr_addr = addr_sel_addr && !i_icb_cmd_read;
wire wr_data = addr_sel_data && !i_icb_cmd_read;
wire wr_ctrl = addr_sel_ctrl && !i_icb_cmd_read;

wire rd_addr = addr_sel_addr &&  i_icb_cmd_read;
wire rd_data = addr_sel_data &&  i_icb_cmd_read;
wire rd_ctrl = addr_sel_ctrl &&  i_icb_cmd_read;

// ---- ICB handshake: no-wait-state slave ----
// cmd_ready is always 1 so the CPU never stalls
assign i_icb_cmd_ready = 1'b1;

// rsp_valid is asserted one cycle after a valid command
assign i_icb_rsp_valid = icb_rsp_valid_r;
assign i_icb_rsp_rdata = icb_data_out;

// interrupt unused
assign io_interrupts_0_0 = 1'b0;

// GPU_DATA_REG drives the register splitter
assign io_pad_out      = gpu_data_reg;
// data strobe: pulses 1 cycle after GPU_DATA_REG is written (registered wr_data)
assign io_data_strobe  = io_data_strobe_r;
// BRAM byte address: firmware writes the exact byte address into GPU_ADDR_REG
assign io_bram_addr    = gpu_addr_reg[15:0];

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        gpu_addr_reg      <= 32'd0;
        gpu_data_reg      <= 32'd0;
        gpu_ctrl_reg      <= 32'd0;
        icb_data_out      <= 32'd0;
        icb_rsp_valid_r   <= 1'b0;
        io_data_strobe_r  <= 1'b0;
    end else begin
        icb_rsp_valid_r  <= 1'b0;  // default: deassert response valid each cycle
        io_data_strobe_r <= 1'b0;  // default: strobe low; set to 1 only when data is written

        // --- writes ---
        if (wr_addr) gpu_addr_reg <= i_icb_cmd_wdata;
        if (wr_data) begin
            gpu_data_reg     <= i_icb_cmd_wdata;
            io_data_strobe_r <= 1'b1;  // pulse for exactly 1 cycle
        end
        if (wr_ctrl) gpu_ctrl_reg <= i_icb_cmd_wdata;

        // --- reads ---
        if (rd_addr) icb_data_out <= gpu_addr_reg;
        if (rd_data) icb_data_out <= gpu_data_reg;
        if (rd_ctrl) icb_data_out <= gpu_ctrl_reg;

        // assert response valid on any valid command
        if (i_icb_cmd_valid)
            icb_rsp_valid_r <= 1'b1;
    end
end

endmodule

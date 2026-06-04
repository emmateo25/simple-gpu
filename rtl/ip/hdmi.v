module hdmi(
    input  wire        clk,               // pixel clock (25.2 MHz from PLL)
    input  wire        rst_n,             // active-low asynchronous reset
    input  wire [7:0]  ram_data,          // 8-bit character row byte from dual-port BRAM
    output wire [15:0] address_read_dbp,  // read address to dual-port BRAM (combinatorial)
    output reg         hsync,             // horizontal sync — active-LOW (VGA standard)
    output reg         vsync,             // vertical sync   — active-LOW (VGA standard)
    output reg         de,                // data enable: HIGH inside active 640×480 window
    output wire [23:0] hdmi_data          // 24-bit RGB to TMDS encoders
);

// ======== VGA 640×480 @ 60 Hz timing (pixel clock = 25.175 MHz ≈ 25.2 MHz) ========
// Counter structure: back-porch → active → front-porch → sync → (repeat)
//   Horizontal: 0..47 = BP, 48..687 = active, 688..703 = FP, 704..799 = sync
//   Vertical  : 0..32 = BP, 33..512 = active, 513..522 = FP, 523..524 = sync
parameter H_ACTIVE      = 640;
parameter H_FRONT_PORCH = 16;
parameter H_SYNC_PULSE  = 96;
parameter H_BACK_PORCH  = 48;
parameter H_TOTAL       = 800;   // BP+active+FP+sync = 48+640+16+96

parameter V_ACTIVE      = 480;
parameter V_FRONT_PORCH = 10;
parameter V_SYNC_PULSE  = 2;
parameter V_BACK_PORCH  = 33;
parameter V_TOTAL       = 525;   // 33+480+10+2

// Derived thresholds (used for sync pulses — include back-porch offset)
localparam H_SYNC_START = H_BACK_PORCH + H_ACTIVE + H_FRONT_PORCH; // 704
localparam H_SYNC_END   = H_SYNC_START + H_SYNC_PULSE;              // 800
localparam V_SYNC_START = V_BACK_PORCH + V_ACTIVE + V_FRONT_PORCH; // 523
localparam V_SYNC_END   = V_SYNC_START + V_SYNC_PULSE;              // 525

// ======== 5-second color-bar boot timer ========
// 5 s × 25.2 MHz = 126 000 000 pixel clocks → needs 27 bits
parameter COLOR_BAR_CYCLES = 27'd126_000_000;

// ======== scan counters ========
reg [11:0] h_count;  // 0 .. H_TOTAL-1
reg [11:0] v_count;  // 0 .. V_TOTAL-1

// ======== mode flags ========
reg show_color_bars;
reg show_image;
reg [26:0] color_bar_timer;

// ======== color-bar RGB from sub-module ========
wire [7:0] color_bar_r, color_bar_g, color_bar_b;

// ======== scan counter + sync + DE + timer ========
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        h_count         <= 12'd0;
        v_count         <= 12'd0;
        hsync           <= 1'b1;
        vsync           <= 1'b1;
        de              <= 1'b0;
        color_bar_timer <= 27'd0;
        show_color_bars <= 1'b1;
        show_image      <= 1'b0;
    end else begin
        // --- horizontal / vertical counters ---
        if (h_count == H_TOTAL - 1) begin
            h_count <= 12'd0;
            v_count <= (v_count == V_TOTAL - 1) ? 12'd0 : v_count + 12'd1;
        end else begin
            h_count <= h_count + 12'd1;
        end

        // --- hsync: active-LOW pulse at H_SYNC_START..H_SYNC_END-1 ---
        // (back-porch offset is included in H_SYNC_START = 704)
        hsync <= ~((h_count >= H_SYNC_START) && (h_count < H_SYNC_END));

        // --- vsync: active-LOW pulse at V_SYNC_START..V_SYNC_END-1 ---
        vsync <= ~((v_count >= V_SYNC_START) && (v_count < V_SYNC_END));

        // --- data enable: active area 640×480 ---
        de <= ((h_count >= H_BACK_PORCH) && (h_count < H_BACK_PORCH + H_ACTIVE)) &&
              ((v_count >= V_BACK_PORCH) && (v_count < V_BACK_PORCH + V_ACTIVE));

        // --- 5-second color-bar timer ---
        if (show_color_bars) begin
            if (color_bar_timer < COLOR_BAR_CYCLES - 1) begin
                color_bar_timer <= color_bar_timer + 27'd1;
            end else begin
                color_bar_timer <= 27'd0;
                show_color_bars <= 1'b0;
                show_image      <= 1'b1;
            end
        end
    end
end

// ======== BRAM read address (combinatorial, 1-cycle look-ahead) ========
// The BRAM (Gowin_DPB port B, oceb=0) has 1-cycle read latency.
// By issuing the address for pixel (h_count+1) NOW, the data arrives
// exactly when that pixel is being rendered on the next clock.
//
// Memory layout (written by firmware):
//   byte_addr = (char_row × 80 + char_col) × 8 + char_pixel_row
//   where char_row = pixel_y >> 3, char_col = pixel_x >> 3,
//         char_pixel_row = pixel_y[2:0]
//
// Pixel coordinates for the NEXT pixel (look-ahead by 1):
//   pixel_x_next = h_count + 1 - H_BACK_PORCH
//   pixel_y_cur  = v_count - V_BACK_PORCH
//
// Active area for next pixel: h_count+1 in [H_BP, H_BP+H_ACT) → h_count in [H_BP-1, H_BP+H_ACT-1)
wire in_active_h_next = ((h_count >= H_BACK_PORCH - 1) && (h_count < H_BACK_PORCH + H_ACTIVE - 1));
wire in_active_v      = ((v_count >= V_BACK_PORCH)      && (v_count < V_BACK_PORCH + V_ACTIVE));

// pixel_x_next and pixel_y — explicit 10-bit arithmetic to avoid implicit truncation warnings.
// H_BACK_PORCH=48, V_BACK_PORCH=33; all values fit in 10 bits (max 640 / 480).
wire [9:0] px_next = h_count[9:0] - 10'd48  + 10'd1;  // 0..639 (next pixel column)
wire [9:0] py      = v_count[9:0] - 10'd33;            // 0..479 (current pixel row)

// byte address = (char_row×80 + char_col)×8 + char_pixel_row
// All terms fit in 16 bits: max = (59×80+79)×8+7 = 38399 < 65536
// Explicit 16-bit intermediate to avoid synthesis truncation warning EX3791.
wire [15:0] char_addr      = {10'd0, py[8:3]} * 16'd80 + {9'd0, px_next[9:3]};
wire [15:0] rd_addr_active = (char_addr << 3) | {13'd0, py[2:0]};

assign address_read_dbp = (in_active_h_next && in_active_v) ? rd_addr_active : 16'd0;

// ======== pixel bit selector ========
// With 1-cycle BRAM latency and 1-cycle look-ahead, ram_data at cycle C holds
// the correct byte for the pixel at h_count[C] - H_BACK_PORCH.
// H_BACK_PORCH = 48 = 6×8, so (h_count - 48)[2:0] = h_count[2:0] (mod-8 is unchanged).
// Bit 7 is the leftmost pixel in the font byte (MSB first).
wire [2:0] bit_sel = 3'd7 - h_count[2:0];

// ======== RGB output multiplexer ========
reg [23:0] hdmi_data_reg;
always @* begin
    if (show_color_bars)
        hdmi_data_reg = {color_bar_r, color_bar_g, color_bar_b};
    else
        hdmi_data_reg = ram_data[bit_sel] ? 24'hFFFFFF : 24'h000000;
end
assign hdmi_data = hdmi_data_reg;

// ======== color_bar_hor sub-module ========
color_bar_hor u_color_bar (
    .I_pxl_clk  (clk),
    .I_rst_n    (rst_n),
    .I_h_total  (H_TOTAL),
    .I_h_sync   (H_SYNC_PULSE),
    .I_h_bporch (H_BACK_PORCH),
    .I_h_fporch (H_FRONT_PORCH),
    .I_h_res    (H_ACTIVE),
    .I_v_total  (V_TOTAL),
    .I_v_sync   (V_SYNC_PULSE),
    .I_v_bporch (V_BACK_PORCH),
    .I_v_fporch (V_FRONT_PORCH),
    .I_v_res    (V_ACTIVE),
    .I_h_count  (h_count),
    .I_v_count  (v_count),
    .I_hs_pol   (1'b0),
    .I_vs_pol   (1'b0),
    .I_de       (de),
    .O_data_r   (color_bar_r),
    .O_data_g   (color_bar_g),
    .O_data_b   (color_bar_b)
);

endmodule

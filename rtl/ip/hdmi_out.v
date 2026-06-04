// HDMI physical output layer for Gowin GW2A-18 (Tang Primer 20k)
//
// Serialises three 10-bit TMDS words and a fixed clock pattern into four
// LVDS differential pairs using Gowin OSER10 (10:1 DDR serialiser) and
// ELVDS_OBUF (LVDS output buffer) primitives.
//
// Channel assignment (DVI/HDMI convention):
//   D0 (hdmi_d0_p/n) = Blue  channel — also carries HSYNC/VSYNC control codes
//   D1 (hdmi_d1_p/n) = Green channel
//   D2 (hdmi_d2_p/n) = Red   channel
//   CLK (hdmi_clk_p/n) = pixel clock recovered by the sink
//
// OSER10 serialises D0..D9 with D0 first, which matches the TMDS bit order
// (LSB transmitted first per DVI spec).
//
// Clocking:
//   pclk    — pixel clock (25.2 MHz)
//   tmds_clk — 5× pixel clock (126 MHz) used as OSER10 fast clock

module hdmi_out (
    input  wire        pclk,          // pixel clock  (25.2 MHz)
    input  wire        tmds_clk,      // TMDS bit clock (5× pclk = 126 MHz)
    input  wire        rst_n,         // active-low reset (synced to pclk domain)
    input  wire [9:0]  tmds_b,        // TMDS-encoded blue  channel (10 b)
    input  wire [9:0]  tmds_g,        // TMDS-encoded green channel (10 b)
    input  wire [9:0]  tmds_r,        // TMDS-encoded red   channel (10 b)
    // Physical HDMI differential outputs
    output wire        hdmi_clk_p, hdmi_clk_n,
    output wire        hdmi_d0_p,  hdmi_d0_n,   // blue
    output wire        hdmi_d1_p,  hdmi_d1_n,   // green
    output wire        hdmi_d2_p,  hdmi_d2_n    // red
);

// The TMDS clock channel carries the pattern 1111100000 repeated, which
// allows the sink to recover the pixel clock independently of the data.
localparam [9:0] CLK_TOKEN = 10'b1111100000;

wire ser_clk, ser_d0, ser_d1, ser_d2;
wire rst = ~rst_n;  // OSER10 uses active-high reset

// ---- OSER10 serialisers ----
// Each serialiser takes 10-bit parallel TMDS input and one DDR serial output.
// FCLK = 5× PCLK; the serialiser outputs 2 bits per FCLK cycle (DDR).

OSER10 u_ser_clk (
    .Q    (ser_clk),
    .D0   (CLK_TOKEN[0]), .D1(CLK_TOKEN[1]), .D2(CLK_TOKEN[2]),
    .D3   (CLK_TOKEN[3]), .D4(CLK_TOKEN[4]), .D5(CLK_TOKEN[5]),
    .D6   (CLK_TOKEN[6]), .D7(CLK_TOKEN[7]), .D8(CLK_TOKEN[8]),
    .D9   (CLK_TOKEN[9]),
    .PCLK (pclk), .FCLK(tmds_clk), .RESET(rst)
);

OSER10 u_ser_d0 (
    .Q    (ser_d0),
    .D0   (tmds_b[0]), .D1(tmds_b[1]), .D2(tmds_b[2]),
    .D3   (tmds_b[3]), .D4(tmds_b[4]), .D5(tmds_b[5]),
    .D6   (tmds_b[6]), .D7(tmds_b[7]), .D8(tmds_b[8]),
    .D9   (tmds_b[9]),
    .PCLK (pclk), .FCLK(tmds_clk), .RESET(rst)
);

OSER10 u_ser_d1 (
    .Q    (ser_d1),
    .D0   (tmds_g[0]), .D1(tmds_g[1]), .D2(tmds_g[2]),
    .D3   (tmds_g[3]), .D4(tmds_g[4]), .D5(tmds_g[5]),
    .D6   (tmds_g[6]), .D7(tmds_g[7]), .D8(tmds_g[8]),
    .D9   (tmds_g[9]),
    .PCLK (pclk), .FCLK(tmds_clk), .RESET(rst)
);

OSER10 u_ser_d2 (
    .Q    (ser_d2),
    .D0   (tmds_r[0]), .D1(tmds_r[1]), .D2(tmds_r[2]),
    .D3   (tmds_r[3]), .D4(tmds_r[4]), .D5(tmds_r[5]),
    .D6   (tmds_r[6]), .D7(tmds_r[7]), .D8(tmds_r[8]),
    .D9   (tmds_r[9]),
    .PCLK (pclk), .FCLK(tmds_clk), .RESET(rst)
);

// ---- ELVDS differential output buffers ----
ELVDS_OBUF u_buf_clk (.I(ser_clk), .O(hdmi_clk_p), .OB(hdmi_clk_n));
ELVDS_OBUF u_buf_d0  (.I(ser_d0),  .O(hdmi_d0_p),  .OB(hdmi_d0_n));
ELVDS_OBUF u_buf_d1  (.I(ser_d1),  .O(hdmi_d1_p),  .OB(hdmi_d1_n));
ELVDS_OBUF u_buf_d2  (.I(ser_d2),  .O(hdmi_d2_p),  .OB(hdmi_d2_n));

endmodule

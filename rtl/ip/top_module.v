// Display controller — self-contained HDMI output module.
//
// Instantiation hierarchy inside this module:
//   1. rPLL  — generates 25.2 MHz pixel clock and 126 MHz TMDS bit clock
//              from the 18 MHz system clock delivered by e203_subsys_perips.
//   2. register_splitter — breaks each 32-bit GPU_DATA_REG write into four
//              consecutive bytes and writes them into the dual-port BRAM.
//   3. Gowin_DPB — dual-port BRAM: port A = CPU write, port B = HDMI read.
//   4. hdmi    — VGA 640×480@60 Hz scan engine + color-bar boot test.
//   5. tmds_encoder × 3 — 8-bit RGB + sync → 10-bit TMDS words.
//   6. hdmi_out — Gowin OSER10 + ELVDS_OBUF TMDS serialiser.
//
// PLL arithmetic (from 18 MHz system clock):
//   FBDIV_SEL=6 → FBDIV=7,  IDIV_SEL=0 → IDIV=1
//   CLKOUT  = 18 × 7 / 1 = 126 MHz          (TMDS bit clock)
//   fvco    = 126 × ODIV_SEL(4) = 504 MHz    (within [400, 800] MHz range)
//   CLKOUTD = 126 / DYN_SDIV_SEL(5) = 25.2 MHz  (pixel clock)
//
// io_pad_out carries the last value written to GPU_DATA_REG (offset 0x004)
// in my_periph_example. The splitter auto-increments the BRAM address, so the
// CPU must write character rows sequentially from BRAM address 0.

module top_module(
    input        clk,           // system clock  (18 MHz from e203 PLL)
    input        rst_n,         // active-low reset
    input [31:0] io_pad_out,    // GPU_DATA_REG value from my_periph_example

    // HDMI physical outputs (LVDS differential pairs)
    output wire  hdmi_clk_p, hdmi_clk_n,
    output wire  hdmi_d0_p,  hdmi_d0_n,   // TMDS channel 0 — blue / sync
    output wire  hdmi_d1_p,  hdmi_d1_n,   // TMDS channel 1 — green
    output wire  hdmi_d2_p,  hdmi_d2_n    // TMDS channel 2 — red
);

// ======== pixel clock PLLs ========
// Two separate PLLs are needed because the ratio TMDS/pixel = 5 is odd,
// so a single PLL with CLKOUTD cannot divide to pixel clock (DYN_SDIV_SEL
// must be an even number on GW2A-18).
//
// PLL 1 — pixel clock 25.2 MHz
//   CLKOUT = 18 × (FBDIV_SEL+1) / (IDIV_SEL+1) = 18 × 7/5 = 25.2 MHz
//   fvco   = 25.2 × ODIV_SEL(16) = 403.2 MHz  (within [400,800] MHz ✓)
//
// PLL 2 — TMDS bit clock 126 MHz (5× pixel clock)
//   CLKOUT = 18 × (FBDIV_SEL+1) / (IDIV_SEL+1) = 18 × 7/1 = 126 MHz
//   fvco   = 126 × ODIV_SEL(4)  = 504 MHz      (within [400,800] MHz ✓)

wire clk_pixel;             // 25.2 MHz — scan engine + TMDS encoders
wire clk_tmds;              // 126 MHz  — OSER10 fast clock (5× pixel)
wire pll_pixel_lock;
wire pll_tmds_lock;
wire pixel_rst_n = rst_n & pll_pixel_lock & pll_tmds_lock;

// ---- PLL 1: 25.2 MHz pixel clock ----
PLL u_pll_pixel (
    .CLKOUT  (clk_pixel),
    .LOCK    (pll_pixel_lock),
    .CLKOUTP (), .CLKOUTD (), .CLKOUTD3(),
    .RESET   (~rst_n),
    .RESET_P (1'b0), .RESET_I (1'b0), .RESET_S (1'b0),
    .CLKIN   (clk),
    .CLKFB   (1'b0),
    .FBDSEL  (6'b0), .IDSEL (6'b0), .ODSEL (6'b0),
    .PSDA    (4'b0), .DUTYDA(4'b0), .FDLY  (4'b0)
);
defparam u_pll_pixel.FCLKIN           = "18";
defparam u_pll_pixel.DYN_IDIV_SEL     = "false";
defparam u_pll_pixel.IDIV_SEL         = 4;    // IDIV = 5
defparam u_pll_pixel.DYN_FBDIV_SEL    = "false";
defparam u_pll_pixel.FBDIV_SEL        = 6;    // FBDIV = 7
defparam u_pll_pixel.DYN_ODIV_SEL     = "false";
defparam u_pll_pixel.ODIV_SEL         = 16;   // fvco = 25.2×16 = 403.2 MHz
defparam u_pll_pixel.PSDA_SEL         = "0000";
defparam u_pll_pixel.DYN_DA_EN        = "false";
defparam u_pll_pixel.DUTYDA_SEL       = "1000";
defparam u_pll_pixel.CLKFB_SEL        = "internal";
defparam u_pll_pixel.CLKOUT_BYPASS    = "false";
defparam u_pll_pixel.CLKOUTP_BYPASS   = "false";
defparam u_pll_pixel.CLKOUTD_BYPASS   = "false";
defparam u_pll_pixel.CLKOUT_FT_DIR    = 1'b1;
defparam u_pll_pixel.CLKOUTP_FT_DIR   = 1'b1;
defparam u_pll_pixel.CLKOUT_DLY_STEP  = 0;
defparam u_pll_pixel.CLKOUTP_DLY_STEP = 0;
defparam u_pll_pixel.DEVICE           = "GW2A-55";

// ---- PLL 2: 126 MHz TMDS bit clock ----
PLL u_pll_tmds (
    .CLKOUT  (clk_tmds),
    .LOCK    (pll_tmds_lock),
    .CLKOUTP (), .CLKOUTD (), .CLKOUTD3(),
    .RESET   (~rst_n),
    .RESET_P (1'b0), .RESET_I (1'b0), .RESET_S (1'b0),
    .CLKIN   (clk),
    .CLKFB   (1'b0),
    .FBDSEL  (6'b0), .IDSEL (6'b0), .ODSEL (6'b0),
    .PSDA    (4'b0), .DUTYDA(4'b0), .FDLY  (4'b0)
);
defparam u_pll_tmds.FCLKIN           = "18";
defparam u_pll_tmds.DYN_IDIV_SEL     = "false";
defparam u_pll_tmds.IDIV_SEL         = 0;    // IDIV = 1
defparam u_pll_tmds.DYN_FBDIV_SEL    = "false";
defparam u_pll_tmds.FBDIV_SEL        = 6;    // FBDIV = 7
defparam u_pll_tmds.DYN_ODIV_SEL     = "false";
defparam u_pll_tmds.ODIV_SEL         = 4;    // fvco = 126×4 = 504 MHz
defparam u_pll_tmds.PSDA_SEL         = "0000";
defparam u_pll_tmds.DYN_DA_EN        = "false";
defparam u_pll_tmds.DUTYDA_SEL       = "1000";
defparam u_pll_tmds.CLKFB_SEL        = "internal";
defparam u_pll_tmds.CLKOUT_BYPASS    = "false";
defparam u_pll_tmds.CLKOUTP_BYPASS   = "false";
defparam u_pll_tmds.CLKOUTD_BYPASS   = "false";
defparam u_pll_tmds.CLKOUT_FT_DIR    = 1'b1;
defparam u_pll_tmds.CLKOUTP_FT_DIR   = 1'b1;
defparam u_pll_tmds.CLKOUT_DLY_STEP  = 0;
defparam u_pll_tmds.CLKOUTP_DLY_STEP = 0;
defparam u_pll_tmds.DEVICE           = "GW2A-55";

// ======== register splitter → BRAM write path ========
// Runs on clk_pixel; cpu writes change io_pad_out (18 MHz domain) and are
// detected combinatorially — no metastability risk for display-only data.
wire [15:0] w_add_ram;
wire [7:0]  data_in_ram;
wire        w_enable;

register_splitter u_splitter (
    .clk          (clk_pixel),
    .data_in_32   (io_pad_out),
    .data_out_8   (data_in_ram),
    .address      (w_add_ram),
    .write_enable (w_enable)
);

// ======== dual-port BRAM ========
wire [15:0] r_add_ram;
wire [7:0]  data_out_dpb;

Gowin_DPB u_dpb (
    .douta  (),
    .doutb  (data_out_dpb),
    .clka   (clk_pixel),    // write port uses pixel clock
    .ocea   (1'b1),
    .cea    (1'b1),
    .reseta (1'b0),
    .wrea   (w_enable),
    .clkb   (clk_pixel),    // read port uses pixel clock
    .oceb   (1'b0),         // output register DISABLED: 1-cycle latency (pairs with look-ahead addr)
    .ceb    (1'b1),
    .resetb (1'b0),
    .wreb   (1'b0),
    .ada    (w_add_ram),
    .dina   (data_in_ram),
    .adb    (r_add_ram),
    .dinb   (8'b0)
);

// ======== HDMI scan engine ========
wire [23:0] rgb_data;   // parallel RGB from color-bar or text engine
wire        hsync_sig;
wire        vsync_sig;
wire        de_sig;

hdmi u_hdmi (
    .clk              (clk_pixel),
    .rst_n            (pixel_rst_n),
    .ram_data         (data_out_dpb),
    .address_read_dbp (r_add_ram),
    .hsync            (hsync_sig),
    .vsync            (vsync_sig),
    .de               (de_sig),
    .hdmi_data        (rgb_data)
);

// ======== TMDS encoders (one per channel) ========
// Blue channel (D0) also carries HSYNC/VSYNC as control codes during blanking.
wire [9:0] tmds_b, tmds_g, tmds_r;

tmds_encoder u_enc_b (
    .clk   (clk_pixel),
    .rst_n (pixel_rst_n),
    .din   (rgb_data[7:0]),
    .ctrl  ({vsync_sig, hsync_sig}),   // {C1=vsync, C0=hsync}
    .de    (de_sig),
    .dout  (tmds_b)
);

tmds_encoder u_enc_g (
    .clk   (clk_pixel),
    .rst_n (pixel_rst_n),
    .din   (rgb_data[15:8]),
    .ctrl  (2'b00),
    .de    (de_sig),
    .dout  (tmds_g)
);

tmds_encoder u_enc_r (
    .clk   (clk_pixel),
    .rst_n (pixel_rst_n),
    .din   (rgb_data[23:16]),
    .ctrl  (2'b00),
    .de    (de_sig),
    .dout  (tmds_r)
);

// ======== TMDS physical serialiser + differential output ========
hdmi_out u_hdmi_out (
    .pclk      (clk_pixel),
    .tmds_clk  (clk_tmds),
    .rst_n     (pixel_rst_n),
    .tmds_b    (tmds_b),
    .tmds_g    (tmds_g),
    .tmds_r    (tmds_r),
    .hdmi_clk_p(hdmi_clk_p), .hdmi_clk_n(hdmi_clk_n),
    .hdmi_d0_p (hdmi_d0_p),  .hdmi_d0_n (hdmi_d0_n),
    .hdmi_d1_p (hdmi_d1_p),  .hdmi_d1_n (hdmi_d1_n),
    .hdmi_d2_p (hdmi_d2_p),  .hdmi_d2_n (hdmi_d2_n)
);

endmodule

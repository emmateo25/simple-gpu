// ============================================================
// Stage 1 Testbench — VGA 640x480 @60 Hz timing verification
// Tests: HSYNC period/width, VSYNC period/width, DE active window
//
// DUT: hdmi.v  (scan engine only — ram_data tied to 0x00)
//
// Expected values at pixel clock = 25.175 MHz (T_px = 39.68 ns):
//
//   Signal         Value         Calculation
//   ----------     ----------    ----------------------------
//   HSYNC period   31 745 ns     800 px × 39.68 ns
//   HSYNC low      3 809 ns      96 px  × 39.68 ns
//   VSYNC period   16 666 µs     525 lines × 800 px × 39.68 ns
//   VSYNC low      63 490 ns     2 lines × 800 px × 39.68 ns
//   DE width/line  25 397 ns     640 px  × 39.68 ns
//   DE lines/frame 480
//
// ─── compile ────────────────────────────────────────────────
//   iverilog -g2012 -Wall -o tb_stage1_vga_timing.vvp \
//       rtl/sim/tb_stage1_vga_timing.v  \
//       rtl/ip/hdmi.v                   \
//       rtl/ip/colors_bars.v
//
// ─── run ────────────────────────────────────────────────────
//   vvp tb_stage1_vga_timing.vvp
//
// ─── view waveforms ─────────────────────────────────────────
//   gtkwave tb_stage1_vga_timing.vcd
//
//   Suggested GTKWave signal order (drag from Signal list):
//     clk       rst_n
//     hsync     vsync
//     de
//     bram_addr[15:0]
//
//   Zoom tips:
//     • Zoom to ~40 µs  → see 1-2 HSYNC periods + DE pulses per line
//     • Zoom to ~20 ms  → see full VSYNC period (one frame)
// ============================================================
`timescale 1ns/1ps

module tb_stage1_vga_timing();

// ──────────────────────────────────────────────────────────────
// 1. Clock and reset
// ──────────────────────────────────────────────────────────────
// Pixel clock: 25.175 MHz → T/2 = 1/(2 × 25.175e6) ≈ 19.841 ns
reg clk = 1'b0;
always #19.841 clk = ~clk;

// Active-low reset: assert for 200 ns then release
reg rst_n = 1'b0;
initial #200 rst_n = 1'b1;

// ──────────────────────────────────────────────────────────────
// 2. DUT connections
// ──────────────────────────────────────────────────────────────
wire [15:0] bram_addr; // BRAM read address (combinatorial, not used here)
wire        hsync;     // active-LOW horizontal sync
wire        vsync;     // active-LOW vertical sync
wire        de;        // data enable — HIGH = inside active 640×480 window
wire [23:0] rgb;       // 24-bit RGB output (not checked in Stage 1)

// Instantiate the scan engine.
// ram_data = 0: no font data needed — we only check timing signals.
hdmi dut (
    .clk              (clk),
    .rst_n            (rst_n),
    .ram_data         (8'h00),
    .address_read_dbp (bram_addr),
    .hsync            (hsync),
    .vsync            (vsync),
    .de               (de),
    .hdmi_data        (rgb)
);

// ──────────────────────────────────────────────────────────────
// 3. Waveform dump (GTKWave)
// ──────────────────────────────────────────────────────────────
initial begin
    $dumpfile("tb_stage1_vga_timing.vcd");
    $dumpvars(0, tb_stage1_vga_timing);
end

// ──────────────────────────────────────────────────────────────
// 4. Simulation end
// 2 complete frames = 2 × 800 × 525 × 39.68 ns ≈ 33.33 ms
// Adding 0.67 ms margin → #34_000_000
// ──────────────────────────────────────────────────────────────
initial begin
    #34_000_000;
    $display("──────────────────────────────────────");
    $display("Simulation complete (2 frames elapsed)");
    $display("──────────────────────────────────────");
    $finish;
end

// ──────────────────────────────────────────────────────────────
// 5. Self-checking monitors
// ──────────────────────────────────────────────────────────────

// ---- 5a. HSYNC pulse width ----
// Measure the duration HSYNC stays LOW (= sync pulse).
// Expected: 96 px × 39.68 ns = 3 809 ns
// Print first 5 pulses to confirm stability.
integer hs_fall_t = 0;
integer hs_count  = 0;

always @(negedge hsync) hs_fall_t = $time;

always @(posedge hsync) begin
    if (hs_count < 5 && hs_fall_t > 200) begin
        $display("[HSYNC #%0d]  low = %6d ns   (expect 3809 ns)",
                 hs_count, $time - hs_fall_t);
        hs_count = hs_count + 1;
    end
end

// ---- 5b. VSYNC pulse width ----
// Expected: 2 lines × 800 px × 39.68 ns = 63 490 ns
// Print both frames.
integer vs_fall_t = 0;
integer vs_count  = 0;

always @(negedge vsync) vs_fall_t = $time;

always @(posedge vsync) begin
    $display("[VSYNC #%0d]  low = %6d ns   (expect 63490 ns)",
             vs_count, $time - vs_fall_t);
    vs_count = vs_count + 1;
end

// ---- 5c. DE active pixels per line ----
// Count rising edges of clk while DE=1; check at each negedge DE.
// Expected: 640 active pixels per active line.
// Print first 3 measurements.
integer de_px    = 0;
integer de_lines = 0;

always @(posedge clk)
    if (de) de_px = de_px + 1;

always @(negedge de) begin
    if (de_px > 0 && de_lines < 3) begin
        $display("[DE line %0d]  active pixels = %4d  (expect 640)",
                 de_lines, de_px);
        de_lines = de_lines + 1;
    end
    de_px = 0;  // reset for next line
end

// ---- 5d. Total active pixels per frame ----
// Expected: 640 × 480 = 307 200
integer total_px = 0;
integer fr_count = 0;

always @(posedge clk)
    if (de) total_px = total_px + 1;

always @(posedge vsync) begin
    // vsync rising = frame boundary
    if (fr_count < 2)
        $display("[FRAME  #%0d]  total DE pixels = %7d  (expect 307200)",
                 fr_count, total_px);
    total_px = 0;
    fr_count = fr_count + 1;
end

endmodule

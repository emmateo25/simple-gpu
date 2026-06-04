// ============================================================
// Stage 2 Testbench — RGB color bar pattern verification
// Tests: correct RGB value in each of the 8 color bands,
//        band boundary transitions, DE/sync alignment with color
//
// DUT: hdmi.v + color_bar_hor (instantiated inside hdmi.v)
//
// Color band layout (480 active lines / 8 = 60 lines per band):
//   Band  v_active (v_count-33)  Expected RGB
//   ----  ---------------------  ------------
//    0       0 ..  59            WHITE   = 0xFFFFFF
//    1      60 .. 119            YELLOW  = 0xFFFF00
//    2     120 .. 179            CYAN    = 0x00FFFF
//    3     180 .. 239            GREEN   = 0x00FF00
//    4     240 .. 299            MAGENTA = 0xFF00FF
//    5     300 .. 359            RED     = 0xFF0000
//    6     360 .. 419            BLUE    = 0x0000FF
//    7     420 .. 479            BLACK   = 0x000000
//
// Sampling strategy:
//   rgb is sampled at posedge clk where h_count == 399 (center of
//   active line).  At that moment, color_bar registers settled one
//   cycle earlier (I_de=1 at h_count=398→399), so rgb is stable
//   and correct for the current v_count.
//
// Checks performed (10 total per simulation):
//   • Band midpoints: v_active = 30, 90, 150, 210, 270, 330, 390, 450
//   • Band 0→1 boundary: v_active = 59 (last WHITE line)
//                        v_active = 60 (first YELLOW line)
//
// ─── compile ────────────────────────────────────────────────
//   iverilog -g2012 -Wall -o tb_stage2_color_bars.vvp   \
//       rtl/sim/tb_stage2_color_bars.v                  \
//       rtl/ip/hdmi.v                                   \
//       rtl/ip/colors_bars.v
//
// ─── run ────────────────────────────────────────────────────
//   vvp tb_stage2_color_bars.vvp
//
// ─── view waveforms ─────────────────────────────────────────
//   gtkwave tb_stage2_color_bars.vcd
//
//   Recommended GTKWave signal list (in order):
//     clk                               -- pixel clock
//     rst_n                             -- reset
//     hsync                             -- active-LOW HSYNC
//     vsync                             -- active-LOW VSYNC
//     de                                -- data enable (HIGH = active pixel)
//     dut.v_count[11:0]   (Decimal)     -- current scanline (0..524)
//     rgb[23:0]           (Hex)         -- full 24-bit colour word
//     rgb[23:16]          (Hex) → "R"  -- red channel
//     rgb[15:8]           (Hex) → "G"  -- green channel
//     rgb[7:0]            (Hex) → "B"  -- blue channel
//
//   Zoom tips:
//     • Full frame (~17 ms): rgb steps through 8 distinct values —
//       each band is a 60-line plateau visible as a flat segment.
//     • Zoom to any band boundary (~3 µs wide): verify the rgb
//       value changes exactly when v_count crosses the threshold.
//     • During VSYNC (v_count 523-524): rgb = 0x000000 (DE=0).
// ============================================================
`timescale 1ns/1ps

module tb_stage2_color_bars();

// ──────────────────────────────────────────────────────────────
// 1. Clock and reset (identical to Stage 1)
// ──────────────────────────────────────────────────────────────
reg clk = 1'b0;
always #19.841 clk = ~clk;      // 25.175 MHz pixel clock

reg rst_n = 1'b0;
initial #200 rst_n = 1'b1;

// ──────────────────────────────────────────────────────────────
// 2. DUT connections
// ──────────────────────────────────────────────────────────────
wire [15:0] bram_addr;
wire        hsync, vsync, de;
wire [23:0] rgb;

hdmi dut (
    .clk              (clk),
    .rst_n            (rst_n),
    .ram_data         (8'h00),   // not needed in color-bar mode
    .address_read_dbp (bram_addr),
    .hsync            (hsync),
    .vsync            (vsync),
    .de               (de),
    .hdmi_data        (rgb)
);

// ──────────────────────────────────────────────────────────────
// 3. Waveform dump
//    level-0 dumps ALL hierarchy → dut internals (v_count, h_count,
//    show_color_bars, color_bar_r/g/b) appear in GTKWave.
// ──────────────────────────────────────────────────────────────
initial begin
    $dumpfile("tb_stage2_color_bars.vcd");
    $dumpvars(0, tb_stage2_color_bars);
end

// ──────────────────────────────────────────────────────────────
// 4. Simulation end: 1 complete frame  (800×525×39.68 ns ≈ 16.67 ms)
// ──────────────────────────────────────────────────────────────
initial begin
    #17_000_000;
    $display("─────────────────────────────────────────────────────");
    $display("TOTAL: %0d passed, %0d failed (out of %0d checks)",
             pass_count, fail_count, check_count);
    $display(fail_count == 0 ? "ALL PASS" : "*** FAILURES — see above ***");
    $display("─────────────────────────────────────────────────────");
    $finish;
end

// ──────────────────────────────────────────────────────────────
// 5. Helper: expected RGB from vertical active position (0..479)
//    Must match the thresholds in colors_bars.v exactly.
// ──────────────────────────────────────────────────────────────
function [23:0] expected_rgb;
    input [9:0] vap;     // v_active_pos = v_count - 33
    begin
        if      (vap <  60) expected_rgb = 24'hFFFFFF; // WHITE
        else if (vap < 120) expected_rgb = 24'hFFFF00; // YELLOW
        else if (vap < 180) expected_rgb = 24'h00FFFF; // CYAN
        else if (vap < 240) expected_rgb = 24'h00FF00; // GREEN
        else if (vap < 300) expected_rgb = 24'hFF00FF; // MAGENTA
        else if (vap < 360) expected_rgb = 24'hFF0000; // RED
        else if (vap < 420) expected_rgb = 24'h0000FF; // BLUE
        else                expected_rgb = 24'h000000; // BLACK
    end
endfunction

// Helper: human-readable name for a 24-bit color
function [63:0] color_name;   // 8 ASCII chars packed in 64 bits
    input [23:0] c;
    begin
        case (c)
            24'hFFFFFF: color_name = "WHITE   ";
            24'hFFFF00: color_name = "YELLOW  ";
            24'h00FFFF: color_name = "CYAN    ";
            24'h00FF00: color_name = "GREEN   ";
            24'hFF00FF: color_name = "MAGENTA ";
            24'hFF0000: color_name = "RED     ";
            24'h0000FF: color_name = "BLUE    ";
            24'h000000: color_name = "BLACK   ";
            default:    color_name = "????????";
        endcase
    end
endfunction

// ──────────────────────────────────────────────────────────────
// 6. Self-checking: sample rgb at the center of specific lines
//
// Trigger: posedge clk AND h_count (read before update) == 399
//          AND de (read before update) == 1
//
// Pipeline note:
//   • de is registered in hdmi.v: it becomes 1 after the edge where
//     h_count=48 (first active pixel).
//   • color_bar registers update when I_de (= de) is 1 — this means
//     they first update at the edge after de went 1 (i.e. h_count≈49).
//   • Sampling at h_count=399 is ≫ 1 cycle after pipeline settle. ✓
// ──────────────────────────────────────────────────────────────
integer check_count = 0;
integer pass_count  = 0;
integer fail_count  = 0;

// Lines to check: band midpoints + band-0/1 boundary (10 lines total)
function is_check_line;
    input [9:0] vap;
    begin
        is_check_line = (vap == 10'd30  ||   // band 0 midpoint (WHITE)
                         vap == 10'd59  ||   // last line of band 0
                         vap == 10'd60  ||   // first line of band 1
                         vap == 10'd90  ||   // band 1 midpoint (YELLOW)
                         vap == 10'd150 ||   // band 2 midpoint (CYAN)
                         vap == 10'd210 ||   // band 3 midpoint (GREEN)
                         vap == 10'd270 ||   // band 4 midpoint (MAGENTA)
                         vap == 10'd330 ||   // band 5 midpoint (RED)
                         vap == 10'd390 ||   // band 6 midpoint (BLUE)
                         vap == 10'd450);    // band 7 midpoint (BLACK)
    end
endfunction

reg [9:0]  vap_s;      // v_active_pos for current sample
reg [23:0] exp_s;      // expected RGB for current sample

always @(posedge clk) begin
    if (de && (dut.h_count == 12'd399)) begin

        vap_s = dut.v_count[9:0] - 10'd33;  // 0..479
        exp_s = expected_rgb(vap_s);

        if (is_check_line(vap_s)) begin
            check_count = check_count + 1;
            if (rgb == exp_s) begin
                $display("[PASS] band=%0d  v_act=%3d  %s  rgb=%h",
                         vap_s / 10'd60, vap_s,
                         color_name(exp_s), rgb);
                pass_count = pass_count + 1;
            end else begin
                $display("[FAIL] band=%0d  v_act=%3d  %s  got=%h  exp=%h  <--",
                         vap_s / 10'd60, vap_s,
                         color_name(exp_s), rgb, exp_s);
                fail_count = fail_count + 1;
            end
        end
    end
end

// ──────────────────────────────────────────────────────────────
// 7. Band-transition monitor
//    Prints one line at the FIRST active pixel of each new band
//    (v_active_pos = 0, 60, 120, 180, 240, 300, 360, 420) by
//    checking at h_count == 55 (pipeline already settled).
//    Complements GTKWave with exact transition timestamps.
// ──────────────────────────────────────────────────────────────
reg [9:0] vap_t;

always @(posedge clk) begin
    if (de && (dut.h_count == 12'd55)) begin
        vap_t = dut.v_count[9:0] - 10'd33;
        // Fire when v_active_pos is a multiple of 60 (= band boundary)
        if ((vap_t == 10'd0)   || (vap_t == 10'd60)  ||
            (vap_t == 10'd120) || (vap_t == 10'd180) ||
            (vap_t == 10'd240) || (vap_t == 10'd300) ||
            (vap_t == 10'd360) || (vap_t == 10'd420)) begin
            $display("[BAND] t=%0t ns  band=%0d  v_act=%3d  rgb=%h  (%s)",
                     $time, vap_t / 10'd60, vap_t,
                     rgb, color_name(rgb));
        end
    end
end

endmodule

// color_bar_hor
// Generates a horizontal colour-bar test pattern (8 bands, one per primary/mix colour).
// The bar colour changes based on the vertical scan position, creating coloured
// horizontal stripes across the screen.
//
// NOTE: I_hs_pol and I_vs_pol are accepted as inputs for interface completeness but
//       are not used internally (the module only inspects I_de and I_v_count).
//
// NOTE on synthesis: the division I_v_res/8 is used to compute segment_height.
//       Because I_v_res is a parameter constant (480) the synthesiser resolves this
//       to a constant (60) and no divider hardware is inferred.  If I_v_res were a
//       runtime signal a divider would be needed; in that case replace with a
//       right-shift or a hardcoded constant.

module color_bar_hor (
    input  wire         I_pxl_clk,      // pixel clock
    input  wire         I_rst_n,        // active-low reset
    input  wire [31:0]  I_h_total,      // total horizontal pixels per line
    input  wire [31:0]  I_h_sync,       // horizontal sync pulse width
    input  wire [31:0]  I_h_bporch,     // horizontal back porch
    input  wire [31:0]  I_h_fporch,     // horizontal front porch
    input  wire [31:0]  I_h_res,        // horizontal active pixels
    input  wire [31:0]  I_v_total,      // total vertical lines per frame
    input  wire [31:0]  I_v_sync,       // vertical sync pulse width
    input  wire [31:0]  I_v_bporch,     // vertical back porch
    input  wire [31:0]  I_v_fporch,     // vertical front porch
    input  wire [31:0]  I_v_res,        // vertical active lines
    input  wire [11:0]  I_h_count,      // current horizontal counter
    input  wire [11:0]  I_v_count,      // current vertical counter
    input  wire         I_hs_pol,       // hsync polarity (unused, for interface symmetry)
    input  wire         I_vs_pol,       // vsync polarity (unused, for interface symmetry)
    input  wire         I_de,           // data enable: high inside active video area
    output reg  [7:0]   O_data_r,       // red channel output
    output reg  [7:0]   O_data_g,       // green channel output
    output reg  [7:0]   O_data_b        // blue channel output
);

// ---- colour definitions (24-bit RGB) ----
localparam [23:0] WHITE   = 24'hFFFFFF;
localparam [23:0] YELLOW  = 24'hFFFF00;
localparam [23:0] CYAN    = 24'h00FFFF;
localparam [23:0] GREEN   = 24'h00FF00;
localparam [23:0] MAGENTA = 24'hFF00FF;
localparam [23:0] RED     = 24'hFF0000;
localparam [23:0] BLUE    = 24'h0000FF;
localparam [23:0] BLACK   = 24'h000000;

// Each colour band is V_ACTIVE/8 = 480/8 = 60 lines high.
// Comparison thresholds are constants so no hardware divider is inferred.
localparam SEG = 60;  // lines per colour band (480/8)

// Vertical position within the active area (0..479)
wire [9:0] v_active_pos = I_v_count[9:0] - I_v_bporch[9:0];

always @(posedge I_pxl_clk or negedge I_rst_n) begin
    if (!I_rst_n) begin
        {O_data_r, O_data_g, O_data_b} <= BLACK;
    end else if (I_de) begin
        // Select colour band using constant comparisons (no hardware divider)
        if      (v_active_pos <   SEG) {O_data_r, O_data_g, O_data_b} <= WHITE;
        else if (v_active_pos < 2*SEG) {O_data_r, O_data_g, O_data_b} <= YELLOW;
        else if (v_active_pos < 3*SEG) {O_data_r, O_data_g, O_data_b} <= CYAN;
        else if (v_active_pos < 4*SEG) {O_data_r, O_data_g, O_data_b} <= GREEN;
        else if (v_active_pos < 5*SEG) {O_data_r, O_data_g, O_data_b} <= MAGENTA;
        else if (v_active_pos < 6*SEG) {O_data_r, O_data_g, O_data_b} <= RED;
        else if (v_active_pos < 7*SEG) {O_data_r, O_data_g, O_data_b} <= BLUE;
        else                           {O_data_r, O_data_g, O_data_b} <= BLACK;
    end else begin
        {O_data_r, O_data_g, O_data_b} <= BLACK;
    end
end

endmodule


// ======== TESTBENCH (commented out) ========
/*
`timescale 1ns / 1ps

module tb_minimal();

localparam H_TOTAL  = 800;
localparam V_TOTAL  = 525;
localparam H_BPORCH = 48;
localparam H_RES    = 640;
localparam V_BPORCH = 33;
localparam V_RES    = 480;

reg clk   = 0;
reg rst_n = 0;
reg [11:0] h = 0;
reg [11:0] v = 0;
reg de = 0;
wire [7:0] r, g, b;

always #20 clk = ~clk;

always @(posedge clk) begin
    if (h < H_TOTAL-1) h <= h + 1;
    else begin
        h <= 0;
        v <= (v < V_TOTAL-1) ? v + 1 : 0;
    end
    de <= (h >= H_BPORCH && h < H_BPORCH + H_RES &&
           v >= V_BPORCH && v < V_BPORCH + V_RES);
end

color_bar_hor uut (
    .I_pxl_clk(clk), .I_rst_n(rst_n),
    .I_h_total(H_TOTAL), .I_h_sync(96), .I_h_bporch(48), .I_h_fporch(16), .I_h_res(640),
    .I_v_total(V_TOTAL), .I_v_sync(2),  .I_v_bporch(33), .I_v_fporch(10), .I_v_res(480),
    .I_h_count(h), .I_v_count(v), .I_de(de),
    .I_hs_pol(1'b0), .I_vs_pol(1'b0),
    .O_data_r(r), .O_data_g(g), .O_data_b(b)
);

initial begin
    $dumpfile("waveform.vcd");
    $dumpvars(0, tb_minimal);
    #50 rst_n = 1;
    #10000000 $finish;
end

endmodule
*/

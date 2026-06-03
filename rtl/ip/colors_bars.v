module color_bar_hor (
    input wire    I_pxl_clk,    // Pixel clock
    input wire    I_rst_n,    // Active-low reset
    input wire [31:0] I_h_total,    // Total horizontal pixels per line
    input wire [31:0] I_h_sync,    // Horizontal sync pulse width (pixels)
    input wire [31:0] I_h_bporch,    // Horizontal back porch (pixels)
    input wire [31:0] I_h_fporch,    // Horizontal front porch (pixels)
    input wire [31:0] I_h_res,    // Horizontal active video area (pixels)
    input wire [31:0] I_v_total,    // Total vertical lines per frame
    input wire [31:0] I_v_sync,    // Vertical sync pulse width (lines)
    input wire [31:0] I_v_bporch,    // Vertical back porch (lines)
    input wire [31:0] I_v_fporch,    // Vertical front porch (lines)
    input wire [31:0] I_v_res,    // Vertical active video area (lines)
    input wire [11:0] I_h_count,
    input wire [11:0] I_v_count,
    input wire    I_hs_pol,    // HSYNC polarity (1 for active high)
    input wire    I_vs_pol,    // VSYNC polarity (1 for active high)
    input wire    I_de,
    output reg [7:0] O_data_r,    // Red color component
    output reg [7:0] O_data_g,    // Green color component
    output reg [7:0] O_data_b    // Blue color component
);

// Color Definitions
localparam [23:0] WHITE    = 24'hFFFFFF;
localparam [23:0] YELLOW   = 24'hFFFF00;
localparam [23:0] CYAN    = 24'h00FFFF;
localparam [23:0] GREEN   = 24'h00FF00;
localparam [23:0] MAGENTA  = 24'hFF00FF;
localparam [23:0] RED     = 24'hFF0000;
localparam [23:0] BLUE    = 24'h0000FF;
localparam [23:0] BLACK   = 24'h000000;

// Calculate the height of each color bar segment
wire [9:0] segment_height = I_v_res / 8;

// Color Bar Pattern Generation

always @(posedge I_pxl_clk or negedge I_rst_n) begin
    if (!I_rst_n) begin
    // Initialize outputs on reset
    {O_data_r, O_data_g, O_data_b} <= BLACK;

    end else if (I_de) begin // Only update colors when data enable is active
    // Determine which color to output based on the current vertical count

    case ((I_v_count-33) / segment_height)
    0: {O_data_r, O_data_g, O_data_b} <= WHITE;
    1: {O_data_r, O_data_g, O_data_b} <= YELLOW;
    2: {O_data_r, O_data_g, O_data_b} <= CYAN;
    3: {O_data_r, O_data_g, O_data_b} <= GREEN;
    4: {O_data_r, O_data_g, O_data_b} <= MAGENTA;
    5: {O_data_r, O_data_g, O_data_b} <= RED;
    6: {O_data_r, O_data_g, O_data_b} <= BLUE;
    7: {O_data_r, O_data_g, O_data_b} <= BLACK;
    default: {O_data_r, O_data_g, O_data_b} <= BLACK;

    endcase

    end  else begin

        {O_data_r, O_data_g, O_data_b} <= BLACK; // Black during blanking intervals

        end

    end

endmodule


//TESTBENCH

/*
`timescale 1ns / 1ps

module tb_minimal();

localparam H_TOTAL = 800;
localparam V_TOTAL = 525;
localparam H_BPORCH = 48;
localparam H_RES = 640;
localparam V_BPORCH = 33;
localparam V_RES = 480;

reg clk = 0;
reg rst_n = 0;
reg [11:0] h = 0;
reg [11:0] v = 0;
reg de = 0;
wire [7:0] r, g, b;

// pixel_x alias
wire [11:0] pixel_x = h;

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
    .I_v_total(V_TOTAL), .I_v_sync(2), .I_v_bporch(33), .I_v_fporch(10), .I_v_res(480),
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
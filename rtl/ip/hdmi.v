module hdmi{
    input wire clk,                         //system clock (25.2MHz)
    input wire rst_n,                       //asynchronous active-low reset
    input wire [7:0] ram_data,              //8-bit character row byte fetched out from dual-port RAM structure
    output reg [15:0] address_read_dbp,     //read address pointer sent to the Dual-Port BRAM
    output reg hsync, vsync, de,            //display sync and data enable signals for HDMI encoder
    output wire [23:0] hdmi_data            //24-bit RGB parallel bus feeding the display monitor
};

// ======== video timing resolution profiles (VGA 640x480 @ 60Hz)========
parameter H_ACTIVE = 640;           //horizontal active video area (pixels)
parameter H_FRONT_PORCH = 16;       //horizontal front porch (pixels)
parameter H_SYNC_PULSE = 96;        //horizontal sync pulse width (pixels)
parameter H_BACK_PORCH = 48;        //horizontal back porch (pixels)
parameter H_TOTAL = 800;            //total horizontal pixels per line

parameter V_ACTIVE = 480;           //vertical active video area (lines)
parameter V_FRONT_PORCH = 10;       //vertical front porch (lines)
parameter V_SYNC_PULSE = 2;         //vertical sync pulse width (lines)
parameter V_BACK_PORCH = 33;        //vertical back porch (lines)
parameter V_TOTAL = 525;            //total vertical lines per frame

// ======== boot diagnostic timer variables ========
parameter COLOR_BAR_TIME = 3;       //color bar display time in seconds
parameter CLK_FREQ = 385200;        //system clock frequency

// ======== registers and wires ========
reg [11:0] h_count;             //current horizontal pixel counter
reg [11:0] v_count;             //current vertical line counter
reg [21:0] color_bar_timer;     //timer for displaying color bars
wire [7:0] color_bar_data_r;    //register for color bar data red
wire [7:0] color_bar_data_g;    //register for color bar data green
wire [7:0] color_bar_data_b;    //register for color bar data blue

reg [18:0] rd_addr_req;         //registered read address for dpd ram
//UNUSED!!!!!


// ======== video timing generation ========
//sweeps horizontal/vertical video counters, creates standard VGA sync waves and manages
//the 5-second power-on color bar test timer
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        //asynchronous structural hardware state initialization values
        h_count         <= 0;
        v_count         <= 0;
        hsync           <= 1'b1;        //start in horizontal sync
        vsync           <= 1'b1;        //start in vertical async
        de              <= 1'b0;        //data enable path defaults low outside visible zones
        color_bar_timer <= 22'b0;
        show_color_bars <= 1'b1;        //boot up into diagnostic color bar mode
    end else begin
       
        // --- 2D video scanning grid counters ---
        if (h_count == H_TOTAL - 1) begin
            h_count <= 0;                  //end of row reached -> return to column 0
            if (v_count == V_TOTAL - 1) begin
                v_count <= 0;              //end of screen reached -> return to row 0 top-left
            end else begin
                v_count <= v_count + 1;    //advance down to the next line
            end
        end else begin
            h_count <= h_count + 1;        //advance right to next pixel column
        end

        // --- hardware timing protocol definitions ---
        //generates clean system synchronization square-waves using bounds thresholds checking metrics
        hsync <= (h_count <= (H_BACK_PORCH + H_ACTIVE + H_FRONT_PORCH)) ? 1'b1 : 1'b0;  //low during sync pulse
        vsync <= (v_count <= (V_BACK_PORCH + V_ACTIVE + V_FRONT_PORCH)) ? 1'b1 : 1'b0;  //low during sync pulse
       
        //assert data enable (de) to '1' strcily inside the active area of the frame box
        de <= ((h_count >= H_BACK_PORCH) && (h_count <= (H_BACK_PORCH + H_ACTIVE))) &&
              ((v_count >= V_BACK_PORCH) && (v_count <= (V_BACK_PORCH + V_ACTIVE))) ? 1'b1 : 1'b0;  
              //high during active video

        // --- startup mode switching timer ---
        if (color_bar_timer < (140000 * COLOR_BAR_TIME)) begin
            color_bar_timer <= color_bar_timer + 1;     //hold diagnostic display mode
        end else begin
            show_color_bars <= 1'b0;       //disable color bars after 5s
            color_bar_timer <= 0;          //clear out the timer
            show_image      <= 1'b1;       //toggle active text terminal display mode to high
        end
    end
end

// ======== video data multiplexer and output routing architecture ========
//choose what to display on the screen. if color bars are active, maps RGB values. 
//if text mode is active, uses the bottom 3 bits of 'pixel_x' as a selector to extract 1 bit
//at a time out of the 8-bit RAM byte (white or black)
reg show_image;         //flag to control when to display image data
reg show_color_bars;    //flag to control when to display color bars

reg [23:0] hdmi_data_reg;

always @* begin
    if (show_color_bars) begin
        hdmi_data_reg = {color_bar_data_r, color_bar_data_g, color_bar_data_b};     //output RGB signals straight from color bar engine
    end else begin
        hdmi_data_reg = {24{ram_data[pixel_x[2:0]]}};   //expand 1 text bitmap bit to full 24-bit RGB space 
        //(1 =full white, 0 = full black)
    end
end

assign hdmi_data = hdmi_data_reg;       //route pixel data to out-facing physical bus wires

// ======== instantiation of the diagnostic color_bar_module  ========
//feeds horizontal test pattern logic blocks with sizing properties and absolute counters to
//make stable testing colors on bootup
color_bar_hor my_color_bar (
    .I_pxl_clk(clk),                    //connect system core clock input line feed
    .I_rst_n(rst_n),                    //connect asynchronous hardware reset channel reference path
    .I_h_total(H_TOTAL),                //forward structural grid baseline sizing metadata profiles
    .I_h_sync(H_SYNC_PULSE),
    .I_h_bporch(H_BACK_PORCH),
    .I_h_fporch(H_FRONT_PORCH),
    .I_h_res(H_ACTIVE),
    .I_v_total(V_TOTAL),
    .I_v_sync(V_SYNC_PULSE),
    .I_v_bporch(V_BACK_PORCH),
    .I_v_fporch(V_FRONT_PORCH),
    .I_v_res(V_ACTIVE),
    .I_h_count(h_count),                //forward real-time running tracking sync position values
    .I_v_count(v_count),
    .I_de(de),                          //forward tracking status evaluation matrix boundaries flag
    .O_data_r(color_bar_data_r),        //connect output feeds back to top multiplexer structural blocks
    .O_data_g(color_bar_data_g),
    .O_data_b(color_bar_data_b)
);

// ======== dual-port BRAM character read address mapper ========
//computes video memory read addresses, targets a byte in RAM holding that memory pointer fixed for
//8 continuous horizontal pixels, then increments to the next cell. tracks also row wrasps to move down lines
reg [15:0] rd_addr;             //local tracking address register
reg [6:0] line_counter;         //tracks vertical text lines drawn (v-counter divided by font height)
reg [6:0] line_cnt_2;           //spare status register variable
//!!unused 

always @(posedge clk) begin
    if (~(hsync | vsync)) begin
        //reset window, snap memory lookups back to top-left origin (0, 0)
        rd_addr <= 16'd0;
        line_cnt_2 <= 7'b0;
        line_counter <= 7'b0;
    end else if (((pixel_x % 8) == 0) && (pixel_x != 640)) begin
        //every 8 horizontal pixels, fetch a new 8-bit block from RAM
        rd_addr <= ((pixel_x + pixel_y) + ((line_counter * 640 - line_counter * 8)));
       
        //every 8 vertical lines (v_count past back porch threshold) increment font row tracker
        if ((v_count > 34) && (((v_count - 34) % 8) == 0) && (h_count == 30)) begin
            line_counter <= line_counter + 1;
        end
    end
end

assign address_read_dbp = rd_addr;      //push address pointer onto physical RAM bus lines

// ======== data output to HDMI ========
//subtracts blanking/sync overhead metrics from absolute counters, normalize coordinates to 
//image-relative grid (top-left is (0, 0))
reg [9:0] pixel_x, pixel_y;         //normalized pixel location coordinate tracking registers

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        pixel_x <= 10'd0;       //clear tracking parameters back to safety baseline positions
        pixel_y <= 10'd0;       //reset x and y coordinates
    end else begin
        if (de && show_image) begin         
            //inside active screen display: strip off sync/porch pixel delays to normalize coordinate axis
            pixel_x <= h_count - H_BACK_PORCH - 1;      //subtract non-active pixels from h_count
            pixel_y <= v_count - V_BACK_PORCH - 1;      //subtract non-active lines from v_count
        end else begin
            //outside visible area (blaking zones): force safe grounfing state zero
            pixel_x <= 10'd0;       //reset x coordinates to 0 when not in the active area
            pixel_y <= 10'd0;       //reset y coordinates to 0 when not in the active area
        end
    end
end

endmodule

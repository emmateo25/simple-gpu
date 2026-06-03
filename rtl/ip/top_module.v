//organizer of the: data input, register splitter, DPBram and HDMI

module top_module(
    input                   clk, 
    input                   rst_n, //active low reset signal
    input   [31:0]          io_pad_out, //connects the module's internal registers with external I/O pads

    output                  V_sync,
    output                  H_sync,
    output                  hdmi_data_out
);

reg [31:0] io_value_reg; //reg for storing data inside module

//test DPB ram
wire [15:0] r_add_ram;
wire [7:0] data_out_dpb;
wire [15:0] w_add_ram;
wire [7:0] data_in_ram;
wire w_enable;
wire de_temp;

//instantiate the register splitter(split the 32-bit io_pad_out into 4 8-bit byte to store in DPB ram)
register_splitter my_reg_splitter(
    .clk(clk),
    .data_in_32(io_pad_out),
    .data_out_8(data_in_ram), // output data, connected to DPB input
    .address(w_add_ram), // write address for the DPB ram
    .write_enable(w_enable)     //controls whether to wirte on the dpb 
);

// instantiate the DPB ram,  Double Data Rate Block RAM (DPBRAM), store video data
Gowin_DPB my_dpb(
    .douta(), // not used in this example
    .doutb(data_out_dpb), // output data from DPB, connected to HDMI module input
    .clka(clk),
    .ocea(1'b1), // always enable the output (Output and Chip Enable A)
    .cea(1'b1), // Chip Enable A
    .reseta(1'b0), // no reset
    .wrea(1'b1), // always write on port A
    .clkb(clk),
    .oceb(1'b1), // always enable the output (Output and Chip Enable B)
    .ceb(1'b1), // Chip Enable B
    .resetb(1'b0), // no reset
    .wreb(1'b0), // no write on port B
    .ada(w_add_ram), // write address from register splitter
    .dina(data_in_ram) // data input from register splitter
    .adb(r_add_ram) // read address for DPB
    .dinb() // not used in this example
);

//instantiate the HDMI module, generate hsync,vsync, data enable and HDMI data output
hdmi my_hdmi(
    .clk(clk),
    .rst_n(rst_n),
    .ram_data(data_out_dpb), // video data input from DPB
    .address_read_dpb(r_add_ram), // read address for DPB, connected to HDMI module
    .hsync(H_sync), // horizontal sync output
    .vsync(V_sync), // vertical sync output
    .de(de_temp)// internal signal
    .hdmi_data(hdmi_data_out) // HDMI data output

);
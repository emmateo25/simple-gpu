
// Description:
//  Example for an e203 icb peripheral
// This module facilites communication and data exchange
// ====================================================================

module my_periph_example(
    input                   clk,
    input                   rst_n, //active-low reset signal

//cmd
    input                   i_icb_cmd_valid, // valid comand being sent to module through ICB bus
    output                  i_icb_cmd_ready, // module ready for new command
    input  [32-1:0]         i_icb_cmd_addr, //location where the comand should be applied(within the module's memory)
    input                   i_icb_cmd_read, // read or write operation
    input  [32-1:0]         i_icb_cmd_wdata,// if ~read this is the write data

    output                  i_icb_rsp_valid, //module has valid response
    input                   i_icb_rsp_ready, // 
    output [32-1:0]         i_icb_rsp_rdata, //data response (for ex to a read op)

    output                  io_interrupts_0_0, //generates interrupts(it asks attention to processor)                
    output [32-1:0]         io_pad_out //connects the module's internal registers with external I/O pads
);

    //define a 32-bit register for operating your module
    reg [31:0] io_value_reg; //reg for storing data inside module

    reg [31:0] icb_data_out; // data to be sent to icb bus
    reg        icb_rsp_valid;// tell if data_out is valid

    wire reset;
    wire clock;
    //read enable signal for register reading, this signal assert when proper address issued.
    wire io_value_reg_rd_en; //read enable

    //write enable signal for register writting, this signal assert when proper address issued.
    wire io_value_reg_wr_en; // write enable


    assign reset = ~rst_n;
    assign clock = clk;
    
    //judge if register is selected for read, 3'h4 is the offset address of the register
    assign io_value_reg_rd_en = i_icb_cmd_valid && i_icb_cmd_read && (i_icb_cmd_addr[11:0] == 3'h4);
    //for write
    assign io_value_reg_wr_en = i_icb_cmd_valid && (~i_icb_cmd_read) && (i_icb_cmd_addr[11:0] == 3'h4);

    //no wait state, so direct connect valid to ready signal
    assign i_icb_cmd_ready = i_icb_cmd_valid;

    assign i_icb_rsp_valid = i_icb_rsp_ready && icb_rsp_valid;

    assign i_icb_rsp_rdata = icb_data_out;

    //connect io pad to register
    assign io_pad_out = io_value_reg;


    always @(posedge clock or posedge reset) begin
        if (reset) begin
            io_value_reg <= 32'd0;
            icb_rsp_valid <= 1'b0;
        end 
        else begin
            if (io_value_reg_rd_en) begin
                icb_data_out <= io_value_reg;
                icb_rsp_valid <= 1'b1;
            end
            else begin
                icb_rsp_valid <= 1'b0;
            end

            if(io_value_reg_wr_en) begin
                io_value_reg <= i_icb_cmd_wdata;
                icb_rsp_valid <= 1'b1;
            end
        end
    end

endmodule

`timescale 1ns / 1ps
`include "axis_measure_defs.vh" 
`include "axis_measure_top.v"

module tb();
    reg clk = 1;

    initial begin
        forever begin
            #10 clk = ~clk;
        end
    end 


    wire bvalid;
    wire [1:0] bresp;
    reg bready;
    wire [1:0] rresp; 
    wire rvalid;
    reg rready;
    wire [`STORE_DATA_WIDTH * 8 - 1 : 0] rdata;
    reg wvalid;
    wire wready;
    reg [`STORE_DATA_WIDTH * 8 - 1 : 0] wdata;
    reg [3:0] wstrb;
    reg awvalid;
    wire awready;
    reg [31:0] awaddr;
    reg arvalid;
    wire arready;
    reg [31:0] araddr;

    reg [`DATA_WIDTH * 8 - 1 : 0] instream_tdata;
    reg instream_tvalid;
    wire instream_tready;

    wire [`DATA_WIDTH * 8 - 1 : 0] outstream_tdata;
    wire outstream_tvalid;
    reg outstream_tready;

    axis_measure_top #(.INITIAL_RECORD_ENABLE(1'b1), .RECORD_ONLY_NONZERO(1'b1)) dut(
        .ap_clk(clk),
        .s_axi_control_araddr(araddr),
        .s_axi_control_arready(arready),
        .s_axi_control_arvalid(arvalid),
        .s_axi_control_awaddr(awaddr),
        .s_axi_control_awready(awready),
        .s_axi_control_awvalid(awvalid),
        .s_axi_control_wstrb(wstrb),
        .s_axi_control_wdata(wdata),
        .s_axi_control_wready(wready),
        .s_axi_control_wvalid(wvalid),
        .s_axi_control_rdata(rdata),
        .s_axi_control_rready(rready),
        .s_axi_control_rvalid(rvalid),
        .s_axi_control_rresp(rresp),
        .s_axi_control_bresp(bresp),
        .s_axi_control_bvalid(bvalid),
        .s_axi_control_bready(bready),
        .instream_tdata(instream_tdata),
        .instream_tready(instream_tready),
        .instream_tvalid(instream_tvalid),
        .outstream_tdata(outstream_tdata),
        .outstream_tready(outstream_tready),
        .outstream_tvalid(outstream_tvalid)
    );

    // For testing always write every byte
    initial begin
        wstrb = 4'b1111;
    end

    task read_request(
        input reg [31:0] inaddr
    ); begin
        #1;
        araddr = inaddr;
        arvalid = 1;
        #20;
        arvalid = 0;
        #20;
        rready = 1;
        #20
        rready = 0;        
    end
    endtask

    task clear_request(
    ); begin
        #1;
        awaddr = `CONTROL_OFFSET;
        awvalid = 1;
        #20
        awvalid = 0;
        wdata = `SIG_CLEAR;
        wvalid = 1;
        bready = 1;
        #20
        wvalid = 0;
        #20
        bready = 0;
    end
    endtask
    
    task start(
    ); begin
        #1;
        awaddr = `CONTROL_OFFSET;
        awvalid = 1;
        #20
        awvalid = 0;
        wdata = `SIG_START;
        wvalid = 1;
        bready = 1;
        #20
        wvalid = 0;
        #20
        bready = 0;
    end
    endtask

    initial begin
        #100;
        read_request(0);
        #59;
        read_request(`CYCLES_OFFSET);
        #59;
        read_request(`CYCLES_OFFSET + 4);
        #59;
        clear_request();
        #19;
        start();
        #59;
        read_request(`CYCLES_OFFSET);
        #59;
        #60;
        read_request(`LAST_FRAME_OFFSET);
        #59;
    end

    task send_axis_packet(
        input reg [`DATA_WIDTH * 8 - 1 : 0] input_data
    ); begin
        if (instream_tready) begin
            instream_tdata = input_data;
            instream_tvalid = 1;
            #20;
            instream_tvalid = 0;
        end        
    end
    endtask

    initial begin
        forever begin
            #1;
            outstream_tready = 1;
            send_axis_packet(0);
            send_axis_packet(0);
            send_axis_packet(10);
            send_axis_packet(5);
            #20;
            send_axis_packet(20);
            #20;
            send_axis_packet(30);
            #39;            
        end
    end

endmodule

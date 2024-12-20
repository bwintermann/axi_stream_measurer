`timescale 1ns / 1ps
`include "axis_measure_defs.vh"

// AXI Signals
`define AXI_OKAY 2'b00

// Byte addressed register offsets
`define CONTROL_OFFSET 16
`define ASSERTIONS_OFFSET 20
`define CYCLES_OFFSET 28
`define LATENCY_OFFSET 36
`define AXIS_DATA_WIDTH_OFFSET 44
`define LAST_FRAME_OFFSET 48

// Control signals
`define SIG_START 32'd1
`define SIG_STOP 32'd0
`define SIG_CLEAR 32'd2

module axis_measure_top (

    input wire ap_clk,

    //********************* AXI CONTROL WIRES *********************
    // AW: Write request
    input wire                           s_axi_control_awvalid,
    output wire                          s_axi_control_awready,
    input wire  [15:0]                   s_axi_control_awaddr ,
    
    // W: Write data
    input wire                           s_axi_control_wvalid,
    output wire                          s_axi_control_wready,
    input wire  [`STORE_DATA_WIDTH * 8 - 1 : 0]   s_axi_control_wdata,
    input wire  [3:0]                    s_axi_control_wstrb,
    
    // AR: Read request
    input wire                           s_axi_control_arvalid,
    output wire                          s_axi_control_arready,
    input wire  [15:0]                   s_axi_control_araddr,
    
    // R: Read data
    output reg                          s_axi_control_rvalid,
    input wire                           s_axi_control_rready,
    output reg [`STORE_DATA_WIDTH * 8 - 1 : 0]     s_axi_control_rdata = 0,
    output wire [1:0]                    s_axi_control_rresp,

    // B: Response
    output reg                           s_axi_control_bvalid = 0,
    input wire                           s_axi_control_bready,
    output wire [1:0]                     s_axi_control_bresp, 
    
    //********************* AXIS INPUT STREAM *********************
    input wire [`DATA_WIDTH * 8 - 1 : 0] instream_tdata,
    input wire                          instream_tvalid,
    output wire                         instream_tready,
    
    //********************* AXIS OUTPUT STREAM *********************
    output wire [`DATA_WIDTH * 8 - 1 : 0] outstream_tdata,
    output wire                          outstream_tvalid,
    input wire                           outstream_tready
);

    parameter INITIAL_RECORD_ENABLE = `START_ENABLED;
    parameter RECORD_ONLY_NONZERO = `RECORD_ONLY_NONZERO;
    parameter CLEAR_CONTROL_ON_WRITE = 0;

    // Awaiting an AXI Data Write beat
    reg awaiting_write = 0;
    reg [15:0] awaiting_write_addr = 0;

    // Counters
    reg [2 * `STORE_DATA_WIDTH * 8 - 1 : 0] assertions = 0;
    reg [2 * `STORE_DATA_WIDTH * 8 - 1 : 0] assertions_bytes = 0;
    reg [2 * `STORE_DATA_WIDTH * 8 - 1 : 0] cycles_total = 0;
    reg [2 * `STORE_DATA_WIDTH * 8 - 1 : 0] latency = 0;
    reg detected_assertion = 0;
    reg [`DATA_WIDTH * 8 - 1 : 0] last_frame = 0;
    
    // If the flag is set, only record values that are non zero
    // Need reduction operators for cases when parameter is passed without width annotation
    wire can_record = (|RECORD_ONLY_NONZERO && |instream_tdata) || (~|RECORD_ONLY_NONZERO);

    // Control register
    reg [31:0] control_reg = INITIAL_RECORD_ENABLE;

    // Just forward the AXI Stream
    assign outstream_tdata = instream_tdata;
    assign outstream_tvalid = instream_tvalid;
    assign instream_tready = outstream_tready;


    //********************* Record active transmissions *********************
    always @(posedge ap_clk) begin
        if (control_reg == `SIG_START) begin
            // Record new packet if sender and receiver are valid and ready
            if (instream_tvalid & outstream_tready & can_record) begin
                assertions <= assertions + 1;
                assertions_bytes <= assertions_bytes + `DATA_WIDTH;
                last_frame <= instream_tdata;
                detected_assertion <= 1;
            end

            // Count ap_clk cycles
            cycles_total <= cycles_total + 1;

            // Count latency until first assertion after clear
            if (~detected_assertion) begin
                latency <= latency + 1;
            end
            
        end else begin
            // Is either SIG_STOP or SIG_CLEAR - if clear then reset all counters
            if (control_reg == `SIG_CLEAR) begin
                cycles_total <= 0;
                assertions <= 0;
                assertions_bytes <= 0;
                detected_assertion <= 0;
                latency <= 0;
            end
        end
    end


    //********************* AXI Read Logic *********************
    // Always ready to receive address read data
    assign s_axi_control_arready = 1'b1;

    // Always ready to receive address write data
    assign s_axi_control_awready = 1'b1;

    // Always ready to receive write data
    assign s_axi_control_wready = 1'b1;
    
    // Always Okay to Reads
    assign s_axi_control_rresp = `AXI_OKAY;

    // Always Okay to Writes
    assign s_axi_control_bresp = `AXI_OKAY;

    // AXI Lite logic
    always @(posedge ap_clk) begin
        // Accept new read address
        if (s_axi_control_arready & s_axi_control_arvalid) begin
            if (s_axi_control_araddr >= `LAST_FRAME_OFFSET) begin 
                s_axi_control_rdata <= last_frame[(s_axi_control_araddr - `LAST_FRAME_OFFSET) * 8 + 31 -: 32];
            end else begin
                case (s_axi_control_araddr)
                    `CONTROL_OFFSET: s_axi_control_rdata <= control_reg;
                    `ASSERTIONS_OFFSET: s_axi_control_rdata <= assertions[31:0];
                    `ASSERTIONS_OFFSET + 4: s_axi_control_rdata <= assertions[63:32];
                    `CYCLES_OFFSET: s_axi_control_rdata <= cycles_total[31:0];
                    `CYCLES_OFFSET + 4: s_axi_control_rdata <= cycles_total[63:32];
                    `LATENCY_OFFSET: s_axi_control_rdata <= latency[31:0];
                    `LATENCY_OFFSET + 4: s_axi_control_rdata <= latency[63:32];
                    `AXIS_DATA_WIDTH_OFFSET: s_axi_control_rdata <= `DATA_WIDTH;
                    default: s_axi_control_rdata <= 32'h1234dead;
                endcase
            end
            s_axi_control_rvalid <= 1;
        end

        // Send data until master is ready
        if (s_axi_control_rvalid & s_axi_control_rready) begin
            s_axi_control_rvalid <= 0;
        end

        // ------- Writing -------
        
        // Accept new write address
        if (s_axi_control_awvalid & s_axi_control_awready) begin
            if (~(s_axi_control_wvalid & s_axi_control_wready)) begin
                awaiting_write_addr <= s_axi_control_awaddr;
            end
        end


        // Write data
        if (s_axi_control_wvalid & s_axi_control_wready) begin
            if (~(s_axi_control_awvalid & s_axi_control_awready)) begin
                // Delayed data case
                if (awaiting_write_addr == `CONTROL_OFFSET) begin
                    control_reg <= s_axi_control_wdata;
                end
            end else begin
                // If AW and W channels are both ready at the same time, we can use the directly supplied address
                if (s_axi_control_awaddr == `CONTROL_OFFSET) begin
                    control_reg <= s_axi_control_wdata;
                end
            end
            s_axi_control_bvalid <= 1;                     
        end else begin
            // If param is set, reset control register to STOP automatically afer SIG_CLEAR was sent
            if (CLEAR_CONTROL_ON_WRITE && control_reg == `SIG_CLEAR) begin
                control_reg <= `SIG_STOP;
            end
        end


        // Reset BVALID only if no data is being sent and the signal was ack'ed
        if (s_axi_control_bvalid & s_axi_control_bready) begin
            s_axi_control_bvalid <= 0;
        end
    end
    


endmodule

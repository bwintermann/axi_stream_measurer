`timescale 1ns / 1ps
`include "axis_measure_defs.vh"

// AXI Signals
`define AXI_OKAY 2'b00

// Byte addressed register offsets, 0-0x14(20) reserved for control
`define CONTROL_OFFSET 16
`define ASSERTIONS_OFFSET 20
`define CYCLES_OFFSET 28
`define LAST_FRAME_OFFSET 36

// Control signals
`define SIG_START 32'd1
`define SIG_STOP 32'd0
`define SIG_CLEAR 32'd2

module axis_measure_top (

    // TODO: Must be defined as an interface for vitis packing
    input wire ap_clk,

    //********************* AXI CONTROL WIRES *********************
    // AW: Write request
    input wire                           s_axi_control_awvalid,
    output wire                          s_axi_control_awready,
    input wire  [31:0]                   s_axi_control_awaddr ,
    
    // W: Write data
    input wire                           s_axi_control_wvalid,
    output wire                          s_axi_control_wready,
    input wire  [`STORE_DATA_WIDTH * 8 - 1 : 0]   s_axi_control_wdata,
    input wire  [3:0]                    s_axi_control_wstrb,
    
    // AR: Read request
    input wire                           s_axi_control_arvalid,
    output wire                          s_axi_control_arready,
    input wire  [31:0]                   s_axi_control_araddr,
    
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

    // Awaiting an AXI Data Write beat
    reg awaiting_write = 0;

    // Counters
    reg [2 * `STORE_DATA_WIDTH * 8 - 1 : 0] assertions = 0;
    reg [2 * `STORE_DATA_WIDTH * 8 - 1 : 0] assertions_bytes = 0;
    reg [2 * `STORE_DATA_WIDTH * 8 - 1 : 0] cycles_total = 0;
    reg [`DATA_WIDTH * 8 - 1 : 0] last_frame = 0;
    
    // If the flag is set, only record values that are non zero
    // Need reduction parameters for cases when parameter is passed without width annotation
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
            end

            // Count ap_clk cycles
            cycles_total <= cycles_total + 1;
            
        end else begin
            // Is either SIG_STOP or SIG_CLEAR - if clear then reset all counters
            if (control_reg == `SIG_CLEAR) begin
                cycles_total <= 0;
                assertions <= 0;
                assertions_bytes <= 0;
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
                    default: s_axi_control_rdata <= 32'hdead;
                endcase
            end
            s_axi_control_rvalid <= 1;
        end

        // Send data until master is ready
        if (s_axi_control_rvalid & s_axi_control_rready) begin
            s_axi_control_rvalid <= 0;
        end
        
        // Accept new write address
        if (s_axi_control_awvalid & s_axi_control_awready) begin
            if (s_axi_control_awaddr == `CONTROL_OFFSET) begin
                awaiting_write <= 1;
            end else begin
                awaiting_write <= 0;
            end
        end else begin
            if (awaiting_write & s_axi_control_wvalid) begin
                awaiting_write <= 0;
            end
        end

        // Save write data and tell master RESP = OK
        if (awaiting_write & s_axi_control_wvalid) begin
            control_reg <= s_axi_control_wdata & {{8{s_axi_control_wstrb[3]}}, {8{s_axi_control_wstrb[2]}}, {8{s_axi_control_wstrb[1]}}, {8{s_axi_control_wstrb[0]}}}; 
            s_axi_control_bvalid <= 1;
        end

        // Reset Response if the master accepted the OK and there is no pending write
        if (s_axi_control_bvalid & s_axi_control_bready & ~awaiting_write) begin
            s_axi_control_bvalid <= 0;
        end
    end
    


endmodule

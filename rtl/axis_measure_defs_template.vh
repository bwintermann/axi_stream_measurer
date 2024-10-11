// AXI Lite only supports 32 bit accesses
`define STORE_DATA_WIDTH 4

// Data width of axi streams in bytes
`define DATA_WIDTH ???DATA_WIDTH???

// Whether to start with the counter turned on or off
`define START_ENABLED 32'b???START_ENABLED???

// Whether to only record packets that are not completely zero. Applies both to assertion count and last_frame
`define RECORD_ONLY_NONZERO 1'b???RECORD_ONLY_NONZERO???
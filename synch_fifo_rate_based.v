`timescale 1ns/1ps

module sync_fifo #(
    parameter DATA_WIDTH = 32,

   
    // Producer: 1 write every (1 + Iw) cycles
    // Consumer: 1 read  every (1 + Ir) cycles
    parameter Iw = 0,
    parameter Ir = 3,

    // Max producer burst window
    parameter N  = 16,

    parameter SAFETY_MARGIN = 2,

    // Periods
    parameter Pw = 1 + Iw,
    parameter Pr = 1 + Ir,

    //  (CEILING division) verilog div truncates. So 1 is added to ceil
    parameter CONSUMED  = (N * Pw + Pr - 1) / Pr,
    parameter BACKLOG   = (N > CONSUMED) ? (N - CONSUMED) : 1,

    //   power-of-2 depth
    parameter DEPTH_RAW  = BACKLOG + SAFETY_MARGIN,
    parameter ADDR_WIDTH = $clog2(DEPTH_RAW),
    parameter DEPTH      = (1 << ADDR_WIDTH)
)(
    input                     clk,
    input                     rst,

    input                     wr_en,
    input                     rd_en,
    input  [DATA_WIDTH-1:0]   din,

    output reg [DATA_WIDTH-1:0] dout,
    output                    full,
    output                    empty,
    output [ADDR_WIDTH:0]     count
);

    
    // Memory
  
    reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];

    // Pointers (extra MSB for full detection)
   
    reg [ADDR_WIDTH:0] wr_ptr;
    reg [ADDR_WIDTH:0] rd_ptr;

    wire write = wr_en && !full;
    wire read  = rd_en && !empty;

   
    // Status logic

    assign empty = (wr_ptr == rd_ptr);

    assign full  = (wr_ptr[ADDR_WIDTH]     != rd_ptr[ADDR_WIDTH]) &&
                   (wr_ptr[ADDR_WIDTH-1:0] == rd_ptr[ADDR_WIDTH-1:0]);

    assign count = wr_ptr - rd_ptr;

    // Sequential logic
    
    always @(posedge clk) begin
        if (rst) begin
            wr_ptr <= 0;
            rd_ptr <= 0;
            dout   <= 0;
        end
        else begin
            // Write
            if (write) begin
                mem[wr_ptr[ADDR_WIDTH-1:0]] <= din;
                wr_ptr <= wr_ptr + 1;
            end

            // Read
            if (read) begin
                dout <= mem[rd_ptr[ADDR_WIDTH-1:0]];
                rd_ptr <= rd_ptr + 1;
            end
        end
    end

endmodule

module sync_fifo #(
    parameter DATA_WIDTH      = 32,

    parameter MAX_WRITE_BURST = 16,  // Max consecutive writes
    parameter READ_LATENCY    = 4,   // Cycles before read reacts
    parameter SAFETY_MARGIN   = 2,   // Extra buffer margin

    // DEPTH >= worst-case backlog
    parameter DEPTH = MAX_WRITE_BURST
                    + READ_LATENCY
                    + SAFETY_MARGIN,

    parameter ADDR_WIDTH = clog2(DEPTH)
)(
    input                     clk,
    input                     rst,

    input                     wr_en,
    input                     rd_en,
    input  [DATA_WIDTH-1:0]   din,

    output reg [DATA_WIDTH-1:0] dout,
    output                    full,
    output                    empty,
    output [ADDR_WIDTH:0]    count
);

   
    // Memory
 
    reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];

  
    // Pointers (extra MSB for wrap detection)
   
    reg [ADDR_WIDTH:0] wr_ptr;
    reg [ADDR_WIDTH:0] rd_ptr;

    wire write;
    wire read;

    assign write = wr_en && !full;
    assign read  = rd_en && !empty;

    
    // Full / Empty detection
  
    assign full  = (wr_ptr[ADDR_WIDTH]     != rd_ptr[ADDR_WIDTH]) &&
                   (wr_ptr[ADDR_WIDTH-1:0] == rd_ptr[ADDR_WIDTH-1:0]);

    assign empty = (wr_ptr == rd_ptr);

  
    // Occupancy
  
    assign count = wr_ptr - rd_ptr;

  
    // Sequential logic
  
    always @(posedge clk) begin
        if (rst) begin
            wr_ptr <= 0;
            rd_ptr <= 0;
            dout   <= 0;
        end
        else begin
            if (write) begin
                mem[wr_ptr[ADDR_WIDTH-1:0]] <= din;
                wr_ptr <= wr_ptr + 1;
            end

            if (read) begin
                dout <= mem[rd_ptr[ADDR_WIDTH-1:0]];
                rd_ptr <= rd_ptr + 1;
            end
        end
    end

    // $clog2 is a systemverilog function. Not found in verilog
    
    function integer clog2;
        input integer value;
        integer i;
        begin
            value = value - 1;
            for (i = 0; value > 0; i = i + 1)
                value = value >> 1;
            clog2 = i;
        end
    endfunction

endmodule

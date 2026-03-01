module sync_fifo #(
    parameter int DATA_WIDTH = 32,

    
    parameter int MAX_WRITE_BURST   = 16,  // Max consecutive writes
    parameter int READ_LATENCY      = 4,   // Cycles before read reacts 
    parameter int SAFETY_MARGIN     = 2,   // Extra buffer margin

   
    // DEPTH >= worst-case backlog
    // Ready latency = delay between a consumer becoming able to accept data and the producer seeing ready = 1.
    parameter int DEPTH = MAX_WRITE_BURST 
                         + READ_LATENCY 
                         + SAFETY_MARGIN,

    parameter int ADDR_WIDTH = $clog2(DEPTH)
)(
    input  logic                     clk,
    input  logic                     rst,

    input  logic                     wr_en,
    input  logic                     rd_en,
    input  logic [DATA_WIDTH-1:0]    din,

    output logic [DATA_WIDTH-1:0]    dout,
    output logic                     full,
    output logic                     empty,
    output logic [ADDR_WIDTH:0]      count
);

    
    // Memory
   
    logic [DATA_WIDTH-1:0] mem [0:DEPTH-1];

    
    // Pointers (extra MSB for wrap detection)
   
    logic [ADDR_WIDTH:0] wr_ptr, rd_ptr;
    logic write, read;

    assign write = wr_en && !full;
    assign read  = rd_en && !empty;

    // Full / Empty detection
   
    assign full  = (wr_ptr[ADDR_WIDTH]     != rd_ptr[ADDR_WIDTH]) &&
                   (wr_ptr[ADDR_WIDTH-1:0] == rd_ptr[ADDR_WIDTH-1:0]);

    assign empty = (wr_ptr == rd_ptr);

    // Occupancy
    assign count = wr_ptr - rd_ptr;

    
    // Sequential Logic
   
    always_ff @(posedge clk) begin
        if (rst) begin
            wr_ptr <= '0;
            rd_ptr <= '0;
            dout   <= '0;
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

endmodule


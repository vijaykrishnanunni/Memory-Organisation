module async_fifo #(
    parameter DATA_WIDTH = 16,
    parameter DEPTH      = 16      // must be power of 2
)(
    input  wire wr_clk,
    input  wire wr_rst_n,
    input  wire wr_en,
    input  wire [DATA_WIDTH-1:0] wr_data,

    input  wire rd_clk,
    input  wire rd_rst_n,
    input  wire rd_en,
    output reg  [DATA_WIDTH-1:0] rd_data,

    output wire full,
    output wire empty
);

    // clog2 
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

    localparam ADDR_WIDTH = clog2(DEPTH);

   // Memory
 
    reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];

    // Binary & Gray pointers (extra MSB)
 
    reg [ADDR_WIDTH:0] wr_bin, wr_gray;
    reg [ADDR_WIDTH:0] rd_bin, rd_gray;

    // synchronizers
    reg [ADDR_WIDTH:0] wr_gray_sync1, wr_gray_sync2;
    reg [ADDR_WIDTH:0] rd_gray_sync1, rd_gray_sync2;


    // Binary → Gray
   
    function [ADDR_WIDTH:0] bin2gray;
        input [ADDR_WIDTH:0] bin;
        begin
            bin2gray = (bin >> 1) ^ bin;
        end
    endfunction

    // WRITE DOMAIN
   
    wire [ADDR_WIDTH:0] wr_bin_next;
    wire [ADDR_WIDTH:0] wr_gray_next;

    assign wr_bin_next  = wr_bin + (wr_en & ~full);
    assign wr_gray_next = bin2gray(wr_bin_next);

    always @(posedge wr_clk or negedge wr_rst_n) begin
        if (!wr_rst_n) begin
            wr_bin  <= 0;
            wr_gray <= 0;
        end else begin
            wr_bin  <= wr_bin_next;
            wr_gray <= wr_gray_next;
        end
    end

    always @(posedge wr_clk)
        if (wr_en && !full)
            mem[wr_bin[ADDR_WIDTH-1:0]] <= wr_data;

    // sync read pointer → write clock
    always @(posedge wr_clk or negedge wr_rst_n) begin
        if (!wr_rst_n) begin
            rd_gray_sync1 <= 0;
            rd_gray_sync2 <= 0;
        end else begin
            rd_gray_sync1 <= rd_gray;
            rd_gray_sync2 <= rd_gray_sync1;
        end
    end

    // READ DOMAIN
    
    wire [ADDR_WIDTH:0] rd_bin_next;
    wire [ADDR_WIDTH:0] rd_gray_next;

    assign rd_bin_next  = rd_bin + (rd_en & ~empty);
    assign rd_gray_next = bin2gray(rd_bin_next);

    always @(posedge rd_clk or negedge rd_rst_n) begin
        if (!rd_rst_n) begin
            rd_bin  <= 0;
            rd_gray <= 0;
            rd_data <= 0;
        end else begin
            rd_bin  <= rd_bin_next;
            rd_gray <= rd_gray_next;

            if (rd_en && !empty)
                rd_data <= mem[rd_bin[ADDR_WIDTH-1:0]];
        end
    end

    // sync write pointer → read clock
    always @(posedge rd_clk or negedge rd_rst_n) begin
        if (!rd_rst_n) begin
            wr_gray_sync1 <= 0;
            wr_gray_sync2 <= 0;
        end else begin
            wr_gray_sync1 <= wr_gray;
            wr_gray_sync2 <= wr_gray_sync1;
        end
    end

    // STATUS FLAGS

    assign empty = (rd_gray == wr_gray_sync2);

    assign full =
        (wr_gray_next ==
         {~rd_gray_sync2[ADDR_WIDTH:ADDR_WIDTH-1],
           rd_gray_sync2[ADDR_WIDTH-2:0]});

endmodule

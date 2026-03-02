module rate_based_async_fifo #(
    parameter DATA_WIDTH = 16,

    // System behaviour parameters
    parameter WR_FREQ = 100,
    parameter RD_FREQ = 80,
    parameter Iw = 0, //no. of idle cycles between consecutive writes
    parameter Ir = 0, //no. of idle cycles between consecutive reads

    parameter BURST_SIZE = 64,//max cont. no. of data words written before the reader reacts.
    parameter SAFETY_MARGIN = 16//to tolerate jitter, uncertainty, and timing variation
    parameter RESPONSE_LATENCY = 32, /* delay (in cycles) between FIFO needing reads 
                                        and the reader actually starting to read */

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

    // clog2 function
    function integer clog2;
        input integer value;
        integer i;
        begin
            value = value - 1;
            for (i=0; value>0; i=i+1)
                value = value >> 1;
            clog2 = i;
        end
    endfunction

    // Effective rates
    localparam WR_RATE = WR_FREQ / (1 + Iw);
    localparam RD_RATE = RD_FREQ / (1 + Ir);

    localparam RATE_DIFF =
        (WR_RATE > RD_RATE) ? (WR_RATE - RD_RATE) : 0;

    // Accumulation during latency
    localparam ACCUM =
        RATE_DIFF * RESPONSE_LATENCY;

    // Requested depth
    localparam DEPTH_REQ =
        BURST_SIZE + ACCUM + SAFETY_MARGIN;

    // Round to power of two
    localparam ADDR_WIDTH = clog2(DEPTH_REQ);
    localparam DEPTH = (1 << ADDR_WIDTH);

    // Memory
    reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];

    // Pointers
    reg [ADDR_WIDTH:0] wr_bin, wr_gray;
    reg [ADDR_WIDTH:0] rd_bin, rd_gray;

    reg [ADDR_WIDTH:0] wr_gray_sync1, wr_gray_sync2;
    reg [ADDR_WIDTH:0] rd_gray_sync1, rd_gray_sync2;

    // Binary to Gray conversion
    function [ADDR_WIDTH:0] bin2gray;
        input [ADDR_WIDTH:0] bin;
        begin
            bin2gray = (bin>>1) ^ bin;
        end
    endfunction

    // Write domain
    wire [ADDR_WIDTH:0] wr_bin_next =
        wr_bin + (wr_en & ~full);

    wire [ADDR_WIDTH:0] wr_gray_next =
        bin2gray(wr_bin_next);

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

    always @(posedge wr_clk or negedge wr_rst_n) begin
        if (!wr_rst_n) begin
            rd_gray_sync1 <= 0;
            rd_gray_sync2 <= 0;
        end else begin
            rd_gray_sync1 <= rd_gray;
            rd_gray_sync2 <= rd_gray_sync1;
        end
    end

    // Read domain
    wire [ADDR_WIDTH:0] rd_bin_next =
        rd_bin + (rd_en & ~empty);

    wire [ADDR_WIDTH:0] rd_gray_next =
        bin2gray(rd_bin_next);

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

    always @(posedge rd_clk or negedge rd_rst_n) begin
        if (!rd_rst_n) begin
            wr_gray_sync1 <= 0;
            wr_gray_sync2 <= 0;
        end else begin
            wr_gray_sync1 <= wr_gray;
            wr_gray_sync2 <= wr_gray_sync1;
        end
    end

    // Status flags
    assign empty = (rd_gray == wr_gray_sync2);

    assign full =
        (wr_gray_next ==
        {~rd_gray_sync2[ADDR_WIDTH:ADDR_WIDTH-1],
          rd_gray_sync2[ADDR_WIDTH-2:0]});

endmodule

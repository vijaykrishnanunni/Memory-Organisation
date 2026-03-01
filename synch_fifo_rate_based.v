module rate_based_fifo #(
    parameter int DATA_WIDTH = 32,

    //  System parameters
    parameter int FA = 100,        // write frequency units
    parameter int FB = 80,         // read frequency units
    parameter int Iw = 0,          // idle cycles between writes
    parameter int Ir = 0,          // idle cycles between reads
    parameter int N  = 16,         // max write burst length

    // Derived depth
    parameter int DEPTH = calc_depth(FA, FB, Iw, Ir, N),
    parameter int ADDR_WIDTH = $clog2(DEPTH)
)(
    input  logic clk,
    input  logic rst,

    input  logic wr_en,
    input  logic rd_en,
    input  logic [DATA_WIDTH-1:0] din,

    output logic [DATA_WIDTH-1:0] dout,
    output logic full,
    output logic empty,
    output logic [ADDR_WIDTH:0] count
);

    // Memory 
    logic [DATA_WIDTH-1:0] mem [DEPTH];

    // Pointers 
    logic [ADDR_WIDTH:0] wr_ptr;
    logic [ADDR_WIDTH:0] rd_ptr;

    // Count
    assign count = wr_ptr - rd_ptr;

    assign full  = (count == DEPTH);
    assign empty = (count == 0);

    // Write logic 
    always_ff @(posedge clk) begin
        if (rst)
            wr_ptr <= 0;
        else if (wr_en && !full) begin
            mem[wr_ptr[ADDR_WIDTH-1:0]] <= din;
            wr_ptr <= wr_ptr + 1;
        end
    end

    // Read logi
    always_ff @(posedge clk) begin
        if (rst) begin
            rd_ptr <= 0;
            dout   <= 0;
        end
        else if (rd_en && !empty) begin
            dout <= mem[rd_ptr[ADDR_WIDTH-1:0]];
            rd_ptr <= rd_ptr + 1;
        end
    end

    //Depth calculation functio
    function automatic int calc_depth(
        input int fa,
        input int fb,
        input int iw,
        input int ir,
        input int burst
    );
        int num;
        int den;
        int result;
        begin
            num = fb * (1 + iw);
            den = fa * (1 + ir);

            if (num >= den)
                result = 0;
            else
                result = (burst * (den - num) + den - 1) / den; // ceil division

            if (result < 1)
                result = 1;

            calc_depth = result;
        end
    endfunction

endmodule

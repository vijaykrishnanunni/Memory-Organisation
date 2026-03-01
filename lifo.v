module lifo #(
    parameter DATA_WIDTH = 4,
    parameter DEPTH      = 8
)(
    input  wire                   clk,
    input  wire                   rst_n,
    input  wire                   push,
    input  wire                   pop,
    input  wire [DATA_WIDTH-1:0]  data_in,
    output reg  [DATA_WIDTH-1:0]  data_out,
    output wire                   full,
    output wire                   empty
);

    localparam ADDR_WIDTH = $clog2(DEPTH);

    reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];
    reg [ADDR_WIDTH:0]   sp;   // counts valid entries (0 to DEPTH)

    assign full  = (sp == DEPTH);
    assign empty = (sp == 0);

    always @(posedge clk) begin
        if (!rst_n) begin
            sp       <= '0;
            data_out <= '0;
        end
        else begin
            if (push && !full) begin
                mem[sp] <= data_in;
                sp      <= sp + 1'b1;
            end
            else if (pop && !empty) begin
                sp       <= sp - 1'b1;
                data_out <= mem[sp - 1'b1];
            end
        end
    end

endmodule

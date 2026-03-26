module sync_fifo_top #(
    parameter integer DATA_WIDTH = 8,
    parameter integer DEPTH = 16,
    parameter integer ADDR_WIDTH = 4
)
(
    input  wire clk,
    input  wire rst_n,
    input  wire wr_en,
    input  wire [DATA_WIDTH-1:0] wr_data,
    output wire wr_full,
    input  wire rd_en,
    output reg [DATA_WIDTH-1:0] rd_data,
    output wire rd_empty,
    output wire [ADDR_WIDTH:0] count
);

    function integer clog2; //instead of $clog()
        input integer value;
        integer temp;
        begin
            temp = value - 1;
            for (clog2 = 0; temp > 0; clog2 = clog2 + 1) begin
                temp = temp >> 1;
            end
        end
    endfunction

    localparam CALCULATED_ADDR_WIDTH = clog2(DEPTH);
    wire [DATA_WIDTH-1:0] core_rd_data;

    sync_fifo #(
       .DATA_WIDTH(DATA_WIDTH),
       .DEPTH(DEPTH),
       .ADDR_WIDTH(CALCULATED_ADDR_WIDTH)
    ) core_fifo_inst (
       .clk(clk),
       .rst_n(rst_n),
       .wr_en(wr_en),
       .wr_data(wr_data),
       .wr_full(wr_full),
       .rd_en(rd_en),
       .rd_data(core_rd_data),
       .rd_empty(rd_empty),
       .count(count)
    );

    always @(*) begin
        rd_data = core_rd_data;
    end

endmodule
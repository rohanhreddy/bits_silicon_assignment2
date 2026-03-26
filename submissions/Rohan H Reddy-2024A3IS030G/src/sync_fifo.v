module sync_fifo #(
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

    reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];
    reg [ADDR_WIDTH-1:0] wr_ptr;
    reg [ADDR_WIDTH-1:0] rd_ptr;
    reg [ADDR_WIDTH:0]   occupancy_count;

    assign wr_full  = (occupancy_count == DEPTH); //flags
    assign rd_empty = (occupancy_count == 0);
    assign count    = occupancy_count;

    wire valid_write = wr_en &&!wr_full;
    wire valid_read  = rd_en &&!rd_empty;

    always @(posedge clk) begin
        if (!rst_n) begin
            wr_ptr          <= 0;
            rd_ptr          <= 0;
            occupancy_count <= 0;
        end else begin

            if (valid_write && valid_read) begin
                wr_ptr <= (wr_ptr == DEPTH - 1)? 0 : wr_ptr + 1;
                rd_ptr <= (rd_ptr == DEPTH - 1)? 0 : rd_ptr + 1;
            end //here occupancy same so no need to handle

            else if (valid_write) begin
                wr_ptr          <= (wr_ptr == DEPTH - 1)? 0 : wr_ptr + 1;
                occupancy_count <= occupancy_count + 1;
            end

            else if (valid_read) begin
                rd_ptr          <= (rd_ptr == DEPTH - 1)? 0 : rd_ptr + 1;
                occupancy_count <= occupancy_count - 1;
            end
        end
    end

    always @(posedge clk) begin
        if (valid_write) begin
            mem[wr_ptr] <= wr_data;
        end
    end

    always @(posedge clk) begin
        if (!rst_n) begin
            rd_data <= 0;
        end else if (valid_read) begin
            rd_data <= mem[rd_ptr];
        end
    end

endmodule

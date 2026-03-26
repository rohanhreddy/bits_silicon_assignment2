`timescale 1ns / 1ps

module tb_sync_fifo;

    parameter integer DATA_WIDTH = 8;
    parameter integer DEPTH = 16;
    parameter integer ADDR_WIDTH = 4; //clog2(16)

    reg clk;
    reg rst_n;
    reg wr_en;
    reg [DATA_WIDTH-1:0] wr_data;
    reg rd_en;

    wire wr_full;
    wire [DATA_WIDTH-1:0] rd_data;
    wire rd_empty;
    wire [ADDR_WIDTH:0] count;
    
    integer cycle = 0;

    reg [DATA_WIDTH-1:0] model_mem [0:DEPTH-1];
    integer model_wr_ptr;
    integer model_rd_ptr;
    integer model_count;
    reg [DATA_WIDTH-1:0] model_rd_data;

    integer cov_full = 0; //manual counters
    integer cov_empty = 0;
    integer cov_wrap = 0;
    integer cov_simul = 0;
    integer cov_overflow = 0;
    integer cov_underflow = 0;

    sync_fifo_top #(
      .DATA_WIDTH(DATA_WIDTH),
      .DEPTH(DEPTH),
      .ADDR_WIDTH(ADDR_WIDTH)
    ) dut (
      .clk(clk),
      .rst_n(rst_n),
      .wr_en(wr_en),
      .wr_data(wr_data),
      .wr_full(wr_full),
      .rd_en(rd_en),
      .rd_data(rd_data),
      .rd_empty(rd_empty),
      .count(count)
    );

    initial begin
        clk = 0;
        forever #5 clk = ~clk; //5ns each crest trough, 10ns total
    end

    always @(posedge clk) begin
        cycle = cycle + 1;
    end

    always @(posedge clk) begin //golden reference code
        if (!rst_n) begin
            model_wr_ptr  = 0;
            model_rd_ptr  = 0;
            model_count   = 0;
            model_rd_data = 0;
        end else begin

            if (wr_en && model_count == DEPTH) cov_overflow = cov_overflow + 1; //error overflow
            if (rd_en && model_count == 0)     cov_underflow = cov_underflow + 1; //underflow

            if (wr_en && (model_count < DEPTH) && rd_en && (model_count > 0)) begin //read and write at same time
                model_mem[model_wr_ptr] = wr_data;
                model_rd_data = model_mem[model_rd_ptr];
                
                if (model_wr_ptr == DEPTH - 1 || model_rd_ptr == DEPTH - 1) cov_wrap = cov_wrap + 1;
                
                model_wr_ptr = (model_wr_ptr == DEPTH - 1)? 0 : model_wr_ptr + 1;
                model_rd_ptr = (model_rd_ptr == DEPTH - 1)? 0 : model_rd_ptr + 1;
                cov_simul = cov_simul + 1;
            end

            else if (wr_en && (model_count < DEPTH)) begin //only write
                model_mem[model_wr_ptr] = wr_data;
                if (model_wr_ptr == DEPTH - 1) cov_wrap = cov_wrap + 1;
                model_wr_ptr = (model_wr_ptr == DEPTH - 1)? 0 : model_wr_ptr + 1;
                model_count  = model_count + 1;
            end

            else if (rd_en && (model_count > 0)) begin //only read
                model_rd_data = model_mem[model_rd_ptr];
                if (model_rd_ptr == DEPTH - 1) cov_wrap = cov_wrap + 1;
                model_rd_ptr  = (model_rd_ptr == DEPTH - 1)? 0 : model_rd_ptr + 1;
                model_count   = model_count - 1;
            end

            if (model_count == DEPTH) cov_full  = cov_full + 1;
            if (model_count == 0)     cov_empty = cov_empty + 1;
        end
    end

    always @(negedge clk) begin //test with score
        if (rst_n) begin
            if (rd_en &&!rd_empty && (rd_data!== model_rd_data)) begin
                $display("Error at cycle %0d: Expected rd_data=%h, Got=%h", cycle, model_rd_data, rd_data);
                $finish;
            end
            if (count!== model_count) begin
                $display("Error at cycle %0d: Expected count=%0d, Got=%0d", cycle, model_count, count);
                $finish;
            end
            if (rd_empty!== (model_count == 0)) begin
                $display("Error at cycle %0d: Expected empty=%b, Got=%b", cycle, (model_count==0), rd_empty);
                $finish;
            end
            if (wr_full!== (model_count == DEPTH)) begin
                $display("Error at cycle %0d: Expected full=%b, Got=%b", cycle, (model_count==DEPTH), wr_full);
                $finish;
            end
        end
    end

    integer i;
    
    initial begin

        clk = 0;
        rst_n = 1;
        wr_en = 0;
        rd_en = 0;
        wr_data = 0;

        $display("Starting FIFO Verification");

        @(negedge clk) rst_n = 0;
        @(negedge clk) rst_n = 1;

        @(negedge clk) wr_en = 1; wr_data = 8'hA5; //read or write only at once
        @(negedge clk) wr_en = 0;
        @(negedge clk) rd_en = 1;
        @(negedge clk) rd_en = 0;

        for (i = 0; i < DEPTH; i = i + 1) begin //fill
            @(negedge clk) wr_en = 1; wr_data = i;
        end
        @(negedge clk) wr_en = 0;

        @(negedge clk) wr_en = 1; wr_data = 8'hFF; //overflow checking
        @(negedge clk) wr_en = 0;

        for (i = 0; i < DEPTH; i = i + 1) begin //drain
            @(negedge clk) rd_en = 1;
        end
        @(negedge clk) rd_en = 0;

        @(negedge clk) rd_en = 1; //underflow checking
        @(negedge clk) rd_en = 0;

        @(negedge clk) wr_en = 1; wr_data = 8'h11; //readn and write at same time, write initially to ensure non empty
        @(negedge clk) wr_en = 1; rd_en = 1; wr_data = 8'h22;
        @(negedge clk) wr_en = 0; rd_en = 0;

        for (i = 0; i < DEPTH + 5; i = i + 1) begin //wrap around because circular FIFO buffer
            @(negedge clk) wr_en = 1; rd_en = 1; wr_data = 8'h33;
        end
        @(negedge clk) wr_en = 0; rd_en = 0;

        $display("\n--- Coverage Summary ---");
        $display("cov_full : %0d", cov_full);
        $display("cov_empty : %0d", cov_empty);
        $display("cov_wrap : %0d", cov_wrap);
        $display("cov_simul : %0d", cov_simul);
        $display("cov_overflow : %0d", cov_overflow);
        $display("cov_underflow : %0d", cov_underflow);
        
        if (cov_full == 0 || cov_empty == 0 || cov_wrap == 0 || cov_simul == 0 || cov_overflow == 0 || cov_underflow == 0) begin
            $display("Not all conditions were covered :( ");
        end else begin
            $display("\nSuccess: All directed tests passed with 100%% coverage");
        end

        $finish;
    end

endmodule
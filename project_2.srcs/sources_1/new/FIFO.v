`timescale 1ns / 1ps

module sync_fifo #(
    parameter FIFO_WIDTH = 32,
    parameter FIFO_DEPTH = 16,
    parameter ADDR_WIDTH = $clog2(FIFO_DEPTH)
) (
    input  wire                    clk,
    input  wire                    reset,
    
    input  wire                    FIFO_WR_EN,
    input  wire                    FIFO_RD_EN,
    output wire                    FIFO_FULL,
    output wire                    FIFO_EMPTY,
    output wire [ADDR_WIDTH:0]     count,
    
    input  wire [FIFO_WIDTH-1:0]   wr_data,
    output wire [FIFO_WIDTH-1:0]   rd_data
);

    reg [FIFO_WIDTH-1:0] fifo_mem [0:FIFO_DEPTH-1];
    reg [ADDR_WIDTH-1:0] wr_ptr;
    reg [ADDR_WIDTH-1:0] rd_ptr;
    reg [ADDR_WIDTH:0]   fifo_count; 
    
    assign FIFO_EMPTY = (fifo_count == 0);
    assign FIFO_FULL  = (fifo_count == FIFO_DEPTH);
    assign count = fifo_count;
    assign rd_data = fifo_mem[rd_ptr];
    
    always @(posedge clk) begin
        if (reset) begin
            wr_ptr <= 0;
        end else if (FIFO_WR_EN && !FIFO_FULL) begin
            fifo_mem[wr_ptr] <= wr_data;
            wr_ptr <= (wr_ptr == FIFO_DEPTH-1) ? 0 : wr_ptr + 1;
        end
    end
    
    always @(posedge clk) begin
        if (reset) begin
            rd_ptr <= 0;
        end else if (FIFO_RD_EN && !FIFO_EMPTY) begin
            rd_ptr <= (rd_ptr == FIFO_DEPTH-1) ? 0 : rd_ptr + 1;
        end
    end
    
    always @(posedge clk) begin
        if (reset) begin
            fifo_count <= 0;
        end else begin
            case ({FIFO_WR_EN && !FIFO_FULL, FIFO_RD_EN && !FIFO_EMPTY})
                2'b10: fifo_count <= fifo_count + 1;
                2'b01: fifo_count <= fifo_count - 1;
                2'b11: fifo_count <= fifo_count; 
                default: fifo_count <= fifo_count;
            endcase
        end
    end

endmodule
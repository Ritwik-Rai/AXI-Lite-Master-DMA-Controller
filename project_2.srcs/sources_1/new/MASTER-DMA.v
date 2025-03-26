`timescale 1ns / 1ps
module master_dma_controller (
    input  wire        clk,
    input  wire        reset,
    input  wire        trigger,
    input  wire [4:0]  length,
    input  wire [31:0] source_address,
    input  wire [31:0] destination_address,
    output reg         done,
    
    output reg  [31:0] ARADDR,
    output reg         ARVALID,
    input  wire        ARREADY,
    
    input  wire [31:0] RDATA,
    input  wire        RVALID,
    output reg         RREADY,
    
    output reg  [31:0] AWADDR,
    output reg         AWVALID,
    input  wire        AWREADY,
    
    output reg  [31:0] WDATA,
    output reg         WVALID,
    input  wire        WREADY,
    
    input  wire        BVALID,
    output reg         BREADY
);

    parameter FIFO_WIDTH = 32;
    parameter FIFO_DEPTH = 16;
    parameter ADDR_WIDTH = 4; 

    parameter IDLE_R  = 3'b000;
    parameter ADDR_R  = 3'b001;
    parameter DATA_R  = 3'b010;
    parameter DONE_R  = 3'b011;
    
    parameter IDLE_W  = 3'b000;
    parameter ADDR_W  = 3'b001;
    parameter DATA_W  = 3'b010;
    parameter RESP_W  = 3'b011;
    parameter DONE_W  = 3'b100;
    
    reg [2:0] read_state;
    reg [2:0] write_state;
    
    reg [4:0]  read_count;
    reg [4:0]  write_count;
    reg [31:0] curr_source_addr;
    reg [31:0] curr_dest_addr;
    reg [4:0]  transfer_length;
    reg        dma_active;
    
    reg        FIFO_WR_EN;
    reg        FIFO_RD_EN;
    wire       FIFO_EMPTY;
    wire       FIFO_FULL;
    reg [31:0] fifo_wr_data;
    wire [31:0] fifo_rd_data;
    wire [ADDR_WIDTH:0] fifo_count;
    
    sync_fifo #(
        .FIFO_WIDTH(FIFO_WIDTH),
        .FIFO_DEPTH(FIFO_DEPTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) data_fifo (
        .clk(clk),
        .reset(reset),
        .FIFO_WR_EN(FIFO_WR_EN),
        .FIFO_RD_EN(FIFO_RD_EN),
        .FIFO_FULL(FIFO_FULL),
        .FIFO_EMPTY(FIFO_EMPTY),
        .count(fifo_count),
        .wr_data(fifo_wr_data),
        .rd_data(fifo_rd_data)
    );
    
    always @(posedge clk) begin
        if (reset) begin
            read_state <= IDLE_R;
            ARVALID <= 0;
            RREADY <= 0;
            read_count <= 0;
            curr_source_addr <= 0;
            FIFO_WR_EN <= 0;
            fifo_wr_data <= 0;
            dma_active <= 0;
        end else begin
            case (read_state)
                IDLE_R: begin
                    if (trigger && !dma_active) begin
                        read_state <= ADDR_R;
                        curr_source_addr <= source_address;
                        transfer_length <= length;
                        read_count <= 0;
                        dma_active <= 1;
                    end
                end
                
                ADDR_R: begin
                    if (!FIFO_FULL) begin
                        ARVALID <= 1;
                        ARADDR <= curr_source_addr;
                        read_state <= DATA_R;
                    end
                end
                
                DATA_R: begin
                    if (ARREADY && ARVALID) begin
                        ARVALID <= 0;
                        RREADY <= 1;
                    end
                    
                    if (RVALID && RREADY) begin
                        fifo_wr_data <= RDATA;
                        FIFO_WR_EN <= 1;
                        RREADY <= 0;
                        read_count <= read_count + 1;
                        curr_source_addr <= curr_source_addr + 4; 
                        
                        if (read_count == transfer_length - 1) begin
                            read_state <= DONE_R;
                        end else begin
                            read_state <= ADDR_R;
                        end
                    end else begin
                        FIFO_WR_EN <= 0;
                    end
                end
                
                DONE_R: begin
                    FIFO_WR_EN <= 0;
                    if (write_state == DONE_W) begin
                        read_state <= IDLE_R;
                        dma_active <= 0;
                    end
                end
                
                default: read_state <= IDLE_R;
            endcase
        end
    end
    
    always @(posedge clk) begin
        if (reset) begin
            write_state <= IDLE_W;
            AWVALID <= 0;
            WVALID <= 0;
            BREADY <= 0;
            write_count <= 0;
            curr_dest_addr <= 0;
            FIFO_RD_EN <= 0;
            done <= 0;
        end else begin
            case (write_state)
                IDLE_W: begin
                    if (trigger && !dma_active) begin
                        write_state <= IDLE_W; 
                        curr_dest_addr <= destination_address;
                        write_count <= 0;
                    end else if (dma_active && !FIFO_EMPTY) begin
                        write_state <= ADDR_W;
                    end
                end
                
                ADDR_W: begin
                    AWVALID <= 1;
                    AWADDR <= curr_dest_addr;
                    write_state <= DATA_W;
                end
                
                DATA_W: begin
                    if (AWREADY && AWVALID) begin
                        AWVALID <= 0;
                        WVALID <= 1;
                        FIFO_RD_EN <= 1;
                        WDATA <= fifo_rd_data;
                    end
                    
                    if (WREADY && WVALID) begin
                        WVALID <= 0;
                        FIFO_RD_EN <= 0;
                        BREADY <= 1;
                        write_state <= RESP_W;
                    end
                end
                
                RESP_W: begin
                    if (BVALID && BREADY) begin
                        BREADY <= 0;
                        write_count <= write_count + 1;
                        curr_dest_addr <= curr_dest_addr + 4; 
                        
                        if (write_count == transfer_length - 1) begin
                            write_state <= DONE_W;
                            done <= 1;
                        end else if (!FIFO_EMPTY) begin
                            write_state <= ADDR_W;
                        end else begin
                            write_state <= IDLE_W; 
                        end
                    end
                end
                
                DONE_W: begin
                    if (read_state == IDLE_R && !dma_active) begin
                        write_state <= IDLE_W;
                        done <= 0;
                    end
                end
                
                default: write_state <= IDLE_W;
            endcase
        end
    end

endmodule
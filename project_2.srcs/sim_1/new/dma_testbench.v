`timescale 1ns / 1ps
module master_dma_controller_tb();
    reg         clk;
    reg         reset;
    reg         trigger;
    reg  [4:0]  length;
    reg  [31:0] source_address;
    reg  [31:0] destination_address;
    wire        done;
    
    wire [31:0] ARADDR;
    wire        ARVALID;
    reg         ARREADY;
    
    reg  [31:0] RDATA;
    reg         RVALID;
    wire        RREADY;
    
    wire [31:0] AWADDR;
    wire        AWVALID;
    reg         AWREADY;
    
    wire [31:0] WDATA;
    wire        WVALID;
    reg         WREADY;
    
    reg         BVALID;
    wire        BREADY;
    
    reg [31:0] source_mem [0:31];
    reg [31:0] dest_mem [0:31];
    
    integer i;
    integer error_count;
    
    master_dma_controller dut (
        .clk(clk),
        .reset(reset),
        .trigger(trigger),
        .length(length),
        .source_address(source_address),
        .destination_address(destination_address),
        .done(done),
        
        .ARADDR(ARADDR),
        .ARVALID(ARVALID),
        .ARREADY(ARREADY),
        
        .RDATA(RDATA),
        .RVALID(RVALID),
        .RREADY(RREADY),
        
        .AWADDR(AWADDR),
        .AWVALID(AWVALID),
        .AWREADY(AWREADY),
        
        .WDATA(WDATA),
        .WVALID(WVALID),
        .WREADY(WREADY),
        
        .BVALID(BVALID),
        .BREADY(BREADY)
    );
    
    initial begin
        clk = 0;
        forever #5 clk = ~clk; 
    end
    
    always @(posedge clk) begin
        if (reset)
            ARREADY <= 0;
        else if (ARVALID && !ARREADY)
            ARREADY <= 1; 
        else
            ARREADY <= 0;
    end
    
    always @(posedge clk) begin
        if (reset) begin
            RVALID <= 0;
            RDATA <= 0;
        end else if (ARREADY && ARVALID) begin
            RVALID <= 1;
            RDATA <= source_mem[(ARADDR - source_address) >> 2];
        end else if (RVALID && RREADY) begin
            RVALID <= 0;
        end
    end
    
    always @(posedge clk) begin
        if (reset)
            AWREADY <= 0;
        else if (AWVALID && !AWREADY)
            AWREADY <= 1;
        else
            AWREADY <= 0;
    end
    
    always @(posedge clk) begin
        if (reset)
            WREADY <= 0;
        else if (WVALID && !WREADY)
            WREADY <= 1; 
        else
            WREADY <= 0;
    end
    
    always @(posedge clk) begin
        if (reset)
            BVALID <= 0;
        else if (WREADY && WVALID) begin
            dest_mem[(AWADDR - destination_address) >> 2] <= WDATA;
            BVALID <= 1;
        end else if (BVALID && BREADY)
            BVALID <= 0;
    end
    
    initial begin
        reset = 1;
        trigger = 0;
        length = 0;
        source_address = 0;
        destination_address = 0;
        error_count = 0;
        
        for (i = 0; i < 32; i = i + 1) begin
            source_mem[i] = i + 32'hA000_0000; 
            dest_mem[i] = 0;
        end
        
        #100;
        reset = 0;
        #20;
        
        $display("Starting test: Transfer of 8 words");
        source_address = 32'h1000_0000;
        destination_address = 32'h2000_0000;
        length = 8;
        trigger = 1;
        #20;
        trigger = 0;
        
        wait(done);
        #100; 
        
        for (i = 0; i < length; i = i + 1) begin
            if (dest_mem[i] != source_mem[i]) begin
                $display("ERROR: Mismatch at index %d. Expected: %h, Got: %h", 
                         i, source_mem[i], dest_mem[i]);
                error_count = error_count + 1;
            end
        end
        
        if (error_count == 0)
            $display("TEST PASSED: All 8 words transferred correctly!");
        else
            $display("TEST FAILED: %d errors detected during transfer!", error_count);
            
        #100;
        $finish;
    end
    
    initial begin
        $monitor("Time: %t, State: Read=%d Write=%d, FIFO count=%d", 
                 $time, dut.read_state, dut.write_state, dut.fifo_count);
    end

endmodule
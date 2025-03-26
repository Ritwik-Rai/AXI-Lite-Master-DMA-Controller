`timescale 1ns / 1ps

module master_dma_controller_tb();
    // System signals
    reg         clk;
    reg         reset;
    reg         trigger;
    reg  [4:0]  length;
    reg  [31:0] source_address;
    reg  [31:0] destination_address;
    wire        done;
    
    // AXI-Lite Read Address Channel
    wire [31:0] ARADDR;
    wire        ARVALID;
    reg         ARREADY;
    
    // AXI-Lite Read Data Channel
    reg  [31:0] RDATA;
    reg         RVALID;
    wire        RREADY;
    
    // AXI-Lite Write Address Channel
    wire [31:0] AWADDR;
    wire        AWVALID;
    reg         AWREADY;
    
    // AXI-Lite Write Data Channel
    wire [31:0] WDATA;
    wire        WVALID;
    reg         WREADY;
    
    // AXI-Lite Write Response Channel
    reg         BVALID;
    wire        BREADY;
    
    // Memory model
    reg [31:0] source_mem [0:31];
    reg [31:0] dest_mem [0:31];
    
    // Test control vars
    integer i;
    integer error_count;
    
    // Instantiate the master_dma_controller
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
    
    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk; // 100 MHz clock
    end
    
    // AXI-Lite Read Address Channel handler
    always @(posedge clk) begin
        if (reset)
            ARREADY <= 0;
        else if (ARVALID && !ARREADY)
            ARREADY <= 1; // Accept read address after 1 cycle
        else
            ARREADY <= 0;
    end
    
    // AXI-Lite Read Data Channel handler
    always @(posedge clk) begin
        if (reset) begin
            RVALID <= 0;
            RDATA <= 0;
        end else if (ARREADY && ARVALID) begin
            // Calculate memory offset based on address
            RVALID <= 1;
            RDATA <= source_mem[(ARADDR - source_address) >> 2];
        end else if (RVALID && RREADY) begin
            RVALID <= 0;
        end
    end
    
    // AXI-Lite Write Address Channel handler
    always @(posedge clk) begin
        if (reset)
            AWREADY <= 0;
        else if (AWVALID && !AWREADY)
            AWREADY <= 1; // Accept write address after 1 cycle
        else
            AWREADY <= 0;
    end
    
    // AXI-Lite Write Data Channel handler
    always @(posedge clk) begin
        if (reset)
            WREADY <= 0;
        else if (WVALID && !WREADY)
            WREADY <= 1; // Accept write data after 1 cycle
        else
            WREADY <= 0;
    end
    
    // AXI-Lite Write Response Channel handler
    always @(posedge clk) begin
        if (reset)
            BVALID <= 0;
        else if (WREADY && WVALID) begin
            // Store data in destination memory
            dest_mem[(AWADDR - destination_address) >> 2] <= WDATA;
            BVALID <= 1;
        end else if (BVALID && BREADY)
            BVALID <= 0;
    end
    
    // Main test sequence
    initial begin
        // Initialize
        reset = 1;
        trigger = 0;
        length = 0;
        source_address = 0;
        destination_address = 0;
        error_count = 0;
        
        // Initialize source memory with test data
        for (i = 0; i < 32; i = i + 1) begin
            source_mem[i] = i + 32'hA000_0000; // Distinct test pattern
            dest_mem[i] = 0;
        end
        
        // Reset for 100ns
        #100;
        reset = 0;
        #20;
        
        // Single Test Case: Transfer of 8 words
        $display("Starting test: Transfer of 8 words");
        source_address = 32'h1000_0000;
        destination_address = 32'h2000_0000;
        length = 8;
        trigger = 1;
        #20;
        trigger = 0;
        
        // Wait for completion
        wait(done);
        #100; // Allow for any trailing operations
        
        // Verify transfer
        for (i = 0; i < length; i = i + 1) begin
            if (dest_mem[i] != source_mem[i]) begin
                $display("ERROR: Mismatch at index %d. Expected: %h, Got: %h", 
                         i, source_mem[i], dest_mem[i]);
                error_count = error_count + 1;
            end
        end
        
        // Report results
        if (error_count == 0)
            $display("TEST PASSED: All 8 words transferred correctly!");
        else
            $display("TEST FAILED: %d errors detected during transfer!", error_count);
            
        // End simulation
        #100;
        $finish;
    end
    
    // Monitoring
    initial begin
        $monitor("Time: %t, State: Read=%d Write=%d, FIFO count=%d", 
                 $time, dut.read_state, dut.write_state, dut.fifo_count);
    end

endmodule
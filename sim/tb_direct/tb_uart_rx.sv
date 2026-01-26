`timescale 1ns / 1ps

module tb_uart_rx();
    // --- Clock and Reset Signals ---
    logic        clk, reset_n;
    logic        pclk, presetn;
    
    // --- APB Interface Signals (CPU Side) ---
    logic        psel, penable, pwrite;
    logic [3:0]  pstrb;
    logic [11:0] paddr;
    logic [31:0] pwdata;
    wire         pready, pslverr;
    wire  [31:0] prdata;
    
    // --- UART Interface Signals (Peripheral Side) ---
    logic        rx;
    wire         rts_n;

    // --- DUT Instantiation ---
    uart_n dut (
        .clk(clk), 
        .reset_n(reset_n),
        .pclk(pclk), 
        .preset_n(presetn),
        .psel(psel), 
        .penable(penable), 
        .pwrite(pwrite),
        .pstrb(pstrb), 
        .paddr(paddr), 
        .pwdata(pwdata),
        .pready(pready), 
        .pslverr(pslverr), 
        .prdata(prdata),
        .rx(rx), 
        .rts_n(rts_n),
        .tx(), 
        .cts_n(1'b0) 
    );

    // --- 50MHz Clock Generation ---
    initial begin
        clk = 0; pclk = 0;
        forever #10 begin clk = ~clk; pclk = ~pclk; end
    end

    // --- APB Write Task ---
    task apb_write(input [11:0] addr, input [31:0] data);
        begin
            @(posedge pclk);
            psel = 1; 
            pwrite = 1; 
            paddr = addr; 
            pwdata = data; 
            pstrb = 4'b1111;
            @(posedge pclk); penable = 1;
            wait(pready);
            @(posedge pclk); 
            psel = 0; 
            penable = 0;
        end
    endtask

    // --- APB Read Task ---
    task apb_read(input [11:0] addr, output [31:0] data);
        begin
            @(posedge pclk);
            psel = 1; 
            pwrite = 0; 
            paddr = addr;
            @(posedge pclk); 
            penable = 1;
            wait(pready);
            data = prdata;
            @(posedge pclk); 
            psel = 0; 
            penable = 0;
        end
    endtask

    // --- Peripheral Task: Send UART Frame with Parity ---
    task send_uart_frame(
        input [7:0] data,
        input [1:0] bit_num,   // 00:5, 01:6, 10:7, 11:8 bits
        input       par_en,    // 1: Enable, 0: Disable
        input       par_type,  // 1: Even, 0: Odd
        input       stop_num   // 0: 1 stop, 1: 2 stops
    );
        integer i;
        logic [3:0] num_bits;
        logic [7:0] masked_data;
        logic       parity_bit;

        begin
            case (bit_num)
                2'b00: begin num_bits = 5; masked_data = data[4:0]; end
                2'b01: begin num_bits = 6; masked_data = data[5:0]; end
                2'b10: begin num_bits = 7; masked_data = data[6:0]; end
                2'b11: begin num_bits = 8; masked_data = data[7:0]; end
            endcase

            // Parity Calculation: Even (XOR), Odd (XNOR) 
            parity_bit = (par_type) ? ^masked_data : ~^masked_data;

            $display("[Peripheral] Sending Data: 0x%h, Parity: %b", masked_data, parity_bit);

            // Start Bit
            rx = 0;
            repeat(435) @(posedge clk); 

            // Data Bits (LSB first)
            for (i = 0; i < num_bits; i = i + 1) begin
                rx = masked_data[i];
                repeat(435) @(posedge clk);
            end

            // Parity Bit
            if (par_en) begin
                rx = ~parity_bit;
                // rx = parity_bit;
                repeat(435) @(posedge clk);
            end

            // Stop Bit(s)
            rx = 1;
            repeat(435) @(posedge clk);
            if (stop_num) repeat(435) @(posedge clk);
        end
    endtask

    // --- Main Simulation Logic (Following Figure 4 Flowchart) ---
    initial begin
        logic [31:0] status, rx_val;
        
        // Initialization
        reset_n = 0; presetn = 0;
        psel = 0; penable = 0;
        rx = 1; 
        #100;
        reset_n = 1; presetn = 1;
        #50;

        $display("--- UART RX TEST START ---");

        // 1. CPU configures UART Frame (8-bit, Even Parity, 1 Stop bit)
        // cfg_reg (0x8): Bit[4]=1 (Even), Bit[3]=0 (Parity En), Bit[2]=0 (1 stop), Bit[1:0]=11 (5-bit)
        // apb_write(12'h008, 32'h0000_0013);  // 1 0011
        // cfg_reg (0x8): Bit[4]=1 (Even), Bit[3]=0 (Parity En), Bit[2]=1 (2 stop), Bit[1:0]=11 (5-bit)
        apb_write(12'h008, 32'h0000_001F);  // 1 1111        
        $display("[CPU] Step 1: Configured UART to 8E1 format.");

        // 2. Wait for UART to be ready (rts_n == 0) 
        wait(rts_n == 0);
        $display("[UART] Hardware Status: rts_n is 0. Ready to receive.");

        // 3. Peripheral sends data frame 
        // Sending 0x3C with correct Even Parity 0011 1100
        send_uart_frame(8'h3C, 2'b11, 1'b1, 1'b1, 1'b1);
        repeat(8) #8685;
        // 4. CPU Polling rx_done == 1 
        // stt_reg (0x10): Bit[1] is rx_done
        // do begin
        //     apb_read(12'h010, status);
        // end while (status[1] !== 1'b1);
        $display("[CPU] Step 4: rx_done detected as 1. Data received by hardware.");

        // 5. CPU reads data from rx_data register (0x4) 
        apb_read(12'h004, rx_val);
        $display("[CPU] Step 5: Read rx_data_reg = 0x%h", rx_val[7:0]);

        // 6. Verify Results and Status 
        if (rx_val[7:0] == 8'h3C && status[2] == 0)
            $display("==> TEST RESULT: SUCCESS (Received Correct Data and No Parity Error)");
        else if (status[2] == 1)
            $display("==> TEST RESULT: FAILED (Parity Error Detected)");
        else
            $display("==> TEST RESULT: FAILED (Data Mismatch)");

        // UART automatically resets rts_n and rx_done after CPU read 
        #100;
        $display("[STATUS] Post-read rts_n: %b", rts_n);

        $display("--- UART RX TEST FINISHED ---");
        repeat(2) @(posedge dut.clk_tx);

        // $display("--- UART RX TEST START ---");

        // // 1. CPU configures UART Frame (8-bit, Even Parity, 1 Stop bit)
        // // cfg_reg (0x8): Bit[4]=1 (Even), Bit[3]=1 (Parity En), Bit[2]=0 (1 stop), Bit[1:0]=11 (8-bit)
        // apb_write(12'h008, 32'h0000_001B);  // 1 1011
        // $display("[CPU] Step 1: Configured UART to 8E1 format.");

        // // 2. Wait for UART to be ready (rts_n == 0) 
        // wait(rts_n == 0);
        // $display("[UART] Hardware Status: rts_n is 0. Ready to receive.");

        // // 3. Peripheral sends data frame 
        // // Sending 0x3C with correct Even Parity 0011 1100
        // send_uart_frame(8'h3C, 2'b11, 1'b1, 1'b1, 1'b0);

        // // 4. CPU Polling rx_done == 1 
        // // stt_reg (0x10): Bit[1] is rx_done
        // do begin
        //     apb_read(12'h010, status);
        // end while (status[1] !== 1'b1);
        // $display("[CPU] Step 4: rx_done detected as 1. Data received by hardware.");

        // // 5. CPU reads data from rx_data register (0x4) 
        // apb_read(12'h004, rx_val);
        // $display("[CPU] Step 5: Read rx_data_reg = 0x%h", rx_val[7:0]);

        // // 6. Verify Results and Status 
        // if (rx_val[7:0] == 8'h3C && status[2] == 0)
        //     $display("==> TEST RESULT: SUCCESS (Received Correct Data and No Parity Error)");
        // else if (status[2] == 1)
        //     $display("==> TEST RESULT: FAILED (Parity Error Detected)");
        // else
        //     $display("==> TEST RESULT: FAILED (Data Mismatch)");

        // // UART automatically resets rts_n and rx_done after CPU read 
        // #100;
        // $display("[STATUS] Post-read rts_n: %b", rts_n);

        $display("--- UART RX TEST FINISHED ---");
        $finish;
    end

endmodule
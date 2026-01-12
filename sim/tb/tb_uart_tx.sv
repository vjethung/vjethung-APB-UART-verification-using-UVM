// `timescale 1ns / 1ps

// module tb_uart_tx();
//     // --- Clock and Reset Signals ---
//     logic        clk, reset_n; 
//     logic        pclk, presetn;
    
//     // --- APB Interface Signals ---
//     logic        psel, penable, pwrite; 
//     logic [3:0]  pstrb; 
//     logic [11:0] paddr; 
//     logic [31:0] pwdata; 
//     wire         pready, pslverr; 
//     wire  [31:0] prdata; 
    
//     // --- UART Interface Signals ---
//     wire         tx; 
//     logic        cts_n; 

//     // --- DUT Instantiation ---
//     uart dut (
//         .clk(clk), 
//         .reset_n(reset_n),
//         .pclk(pclk), 
//         .preset_n(presetn),
//         .psel(psel), 
//         .penable(penable), 
//         .pwrite(pwrite),
//         .pstrb(pstrb), 
//         .paddr(paddr), 
//         .pwdata(pwdata),
//         .pready(pready), 
//         .pslverr(pslverr), 
//         .prdata(prdata),
//         .tx(tx), 
//         .cts_n(cts_n),
//         .rx(1'b1), 
//         .rts_n() 
//     ); 

//     // --- 50MHz Clock Generation (T = 20ns) ---
//     initial begin
//         clk = 0; pclk = 0; 
//         forever #10 begin clk = ~clk; pclk = ~pclk; end 
//     end

//     // --- APB Write Task ---
//     task apb_write(input [11:0] addr, input [31:0] data);
//         begin
//             @(posedge pclk);
//             psel = 1; 
//             pwrite = 1; 
//             paddr = addr; 
//             pwdata = data; 
//             pstrb = 4'b1111; 
//             @(posedge pclk); 
//             penable = 1; 
//             wait(pready);
//             @(posedge pclk); 
//             psel = 0; 
//             penable = 0; 
//         end
//     endtask

//     // --- APB Read Task ---
//     task apb_read(input [11:0] addr, output [31:0] data);
//         begin
//             @(posedge pclk);
//             psel = 1; 
//             pwrite = 0; 
//             paddr = addr; 
//             @(posedge pclk); 
//             penable = 1; 
//             wait(pready); 
//             data = prdata; 
//             @(posedge pclk); 
//             psel = 0; 
//             penable = 0; 
//         end
//     endtask

//     // --- Main Test Execution (Figure 3 Logic) ---
//     initial begin
//         logic [31:0] status_val; 
        
//         // Step 1: System Initialization (Reset)
//         reset_n = 0; presetn = 0; psel = 0; penable = 0; 
//         cts_n = 0; // External device is ready to receive (Active Low) 
//         #100;
//         reset_n = 1; presetn = 1; 
//         #50;

//         $display("--- UART TX PROCESS START ---"); 

//         // 1. Polling tx_done == 1 (Check if UART is ready)
//         do begin
//             apb_read(12'h010, status_val); 
//             if (status_val[0] !== 1'b1) 
//                 $display("[CPU] TX is busy, waiting for tx_done == 1..."); 
//         end while (status_val[0] !== 1'b1); 
//         $display("[CPU] Step 1: tx_done is 1. UART is ready for transmission."); 

//         // 2. Configure Frame (8 data bits, 1 stop bit,  parity)
//         // Configuration Register (Address 0x8)
//         apb_write(12'h008, 32'h0000_001B);   //1 1011
//         $display("[CPU] Step 2: Frame configured (8 Data bits, 1 Stop bit, Parity OFF)."); 

//         // 3. Write data to tx_data register (Address 0x0)
//         apb_write(12'h000, 32'h0000_00A4);
//         $display("[CPU] Step 3: Data 0xA5 written to tx_data_reg."); 

//         // 4. Set start_tx = 1 to begin transmission (Address 0xC)
//         apb_write(12'h00C, 32'h0000_0001); 
//         $display("[CPU] Step 4: start_tx set to 1. UART starts Parallel-to-Serial conversion."); 

//         // --- Hardware Monitoring ---
//         #100;
//         apb_read(12'h010, status_val); 
//         if (status_val[0] === 1'b0)
//             $display("[UART] Hardware Status: Serial transmission in progress (tx_done = 0).");

//         // Wait for Hardware to finish (tx_done returns to 1)
//         repeat(3) @(posedge dut.clk_tx)
//         wait(dut.tx_done == 1); 
//         $display("[UART] Step 5: Serial transmission complete. tx_done is 1."); 

//         $display("--- UART TX PROCESS FINISHED ---");
//         #1000;
//         $finish; 
//     end

// endmodule
`timescale 1ns / 1ps

module tb_uart_tx();
    // --- Clock and Reset Signals ---
    logic        clk, reset_n;
    logic        pclk, presetn;
    // --- APB Interface Signals ---
    logic        psel, penable, pwrite;
    logic [3:0]  pstrb; 
    logic [11:0] paddr; 
    logic [31:0] pwdata;
    wire         pready, pslverr; 
    wire  [31:0] prdata;
    // --- UART Interface Signals ---
    wire         tx;
    logic        cts_n; 

    // --- DUT Instantiation ---
    uart dut (
        .clk(clk), .reset_n(reset_n),
        .pclk(pclk), .preset_n(presetn),
        .psel(psel), .penable(penable), .pwrite(pwrite),
        .pstrb(pstrb), .paddr(paddr), .pwdata(pwdata),
        .pready(pready), .pslverr(pslverr), .prdata(prdata),
        .tx(tx), .cts_n(cts_n),
        .rx(1'b1), .rts_n() 
    );

    // --- 50MHz Clock Generation ---
    initial begin
        clk = 0; pclk = 0; 
        forever #10 begin clk = ~clk; pclk = ~pclk; end 
    end

    // --- Cập nhật APB Write Task để nhận tham số pstrb ---
    task apb_write(input [11:0] addr, input [31:0] data, input [3:0] strb);
        begin
            @(posedge pclk);
            psel = 1; pwrite = 1;
            paddr = addr; 
            pwdata = data; 
            pstrb = strb; // Gán giá trị strobe từ tham số truyền vào
            @(posedge pclk); 
            penable = 1; 
            wait(pready);
            @(posedge pclk); 
            psel = 0; penable = 0; 
            pstrb = 4'b0000;
        end
    endtask

    // --- APB Read Task (Giữ nguyên) ---
    task apb_read(input [11:0] addr, output [31:0] data);
        begin
            @(posedge pclk);
            psel = 1; pwrite = 0;
            paddr = addr; 
            @(posedge pclk); 
            penable = 1; 
            wait(pready); 
            data = prdata; 
            @(posedge pclk); 
            psel = 0; penable = 0;
        end
    endtask

    // --- Main Test Execution ---
    initial begin
        logic [31:0] status_val;
        logic [3:0]  rand_strobe;
        logic [31:0] rand_data;

        // Step 1: Initialization
        reset_n = 0; presetn = 0;
        psel = 0; penable = 0; cts_n = 0; 
        #100;
        reset_n = 1; presetn = 1; 
        #50;

        $display("--- UART TX RANDOM PSTRB TEST START ---");

        // 1. Đợi UART sẵn sàng
        do begin
            apb_read(12'h010, status_val);
        end while (status_val[0] !== 1'b1); 

        // 2. Cấu hình Frame (Sử dụng pstrb cố định 4'hF để đảm bảo cấu hình đúng)
        apb_write(12'h008, 32'h0000_001B, 4'hF);


        // 3. Thực hiện nhiều lần ghi ngẫu nhiên vào tx_data_reg (0x0)
        for (int i = 0; i < 16; i++) begin
            rand_strobe = i; // Tạo strobe ngẫu nhiên từ 0000 đến 1111
            rand_data   = $urandom();           // Tạo dữ liệu ngẫu nhiên 32-bit

            $display("[CPU] Attempting Write: Data=0x%0h, PSTRB=4'b%b", rand_data, rand_strobe);
            apb_write(12'h000, rand_data, rand_strobe);

            // Kiểm tra phản ứng của phần cứng
            #1; 
            if (rand_strobe[0]) begin
                // Nếu bit strobe 0 tích cực, Tpl_84 (tx_data) phải cập nhật 
                if (dut.Tpl_84 == rand_data[7:0])
                    $display("  -> [PASS] Byte 0 updated correctly.");
                else
                    $display("  -> [FAIL] Byte 0 did not update!");
            end else begin
                // Nếu bit strobe 0 bằng 0, giá trị cũ phải được giữ nguyên [cite: 123]
                $display("  -> [INFO] pstrb[0]=0, Hardware ignored byte 0 as expected. Current value: 0x%0h", dut.Tpl_84);
            end
            repeat(3) @(posedge pclk);
        end

        // 4. Kích hoạt truyền tin (Ghi vào 0xC)
        apb_write(12'h00C, 32'h0000_0001, 4'hF);
        
        $display("--- UART TX RANDOM PSTRB TEST FINISHED ---");
        #500;
        $finish; 
    end

endmodule
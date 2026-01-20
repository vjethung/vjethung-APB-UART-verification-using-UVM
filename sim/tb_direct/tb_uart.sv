`timescale 1ns / 1ps

module tb_uart();

    // --- Tín hiệu điều khiển ---
    logic        clk, reset_n;

    logic        pclk, preset_n;
    logic        psel, penable, pwrite;
    logic [3:0]  pstrb;
    logic [11:0] paddr;
    logic [31:0] pwdata;
    wire         pready, pslverr;
    wire  [31:0] prdata;

    logic        cts_n;
    wire         tx;
    logic        rx; 
    wire         rts_n;

    // --- Khởi tạo DUT ---
    uart dut (  .clk(clk), 
                .reset_n(reset_n), 
                .pclk(pclk), 
                .preset_n(preset_n), 
                .psel(psel), 
                .penable(penable), 
                .pwrite(pwrite),
                .pstrb(pstrb), 
                .paddr(paddr), 
                .pwdata(pwdata),
                .pready(pready), 
                .pslverr(pslverr),
                .prdata(prdata), 
                .cts_n(cts_n), 
                .tx(tx),
                .rx(rx),
                .rts_n(rts_n)
    );

    // --- Tạo xung Clock 50MHz (T = 20ns) ---
    initial begin
        clk = 0; pclk = 0;
        forever #10 begin clk = ~clk; pclk = ~pclk; end
    end

    // --- Giao thức APB Write Task ---
    task apb_write(input [11:0] addr, input [31:0] data);
        begin
            @(posedge pclk);
            psel = 1; pwrite = 1; paddr = addr; pwdata = data; pstrb = 4'b1111;
            @(posedge pclk);
            penable = 1;
            wait(pready);
            @(posedge pclk);
            psel = 0; penable = 0;
        end
    endtask

    // --- Giao thức APB Read Task ---
    task apb_read(input [11:0] addr, output [31:0] data);
        begin
            @(posedge pclk);
            psel = 1; pwrite = 0; paddr = addr;
            @(posedge pclk);
            penable = 1;
            wait(pready);
            @(posedge pclk);
            data = prdata;
            psel = 0; penable = 0;
        end
    endtask

    // --- Luồng kiểm thử theo Lưu đồ Thuật toán ---
    initial begin
        logic [31:0] status, received_val;
        
        // Bước 1: Khởi tạo hệ thống (Reset) 
        reset_n = 0; preset_n = 0; psel = 0; penable = 0;
        rx = 1; cts_n = 0; // Cho phép gửi (cts_n active low) 
        #100;
        reset_n = 1; preset_n = 1;
        #50;

        // Cơ chế Loopback: Nối TX vào RX để kiểm tra nhận 
        fork
            forever #1 rx = tx;
        join_none

        $display("--- BẮT ĐẦU KIỂM THỬ THEO LƯU ĐỒ SPEC ---");

        // --- QUY TRÌNH TRUYỀN (Hình 3) ---
        // 1. Kiểm tra tx_done == 1 (CPU chờ bộ truyền sẵn sàng) 
        do begin
            apb_read(12'h010, status);
        end while (status[0] !== 1'b1);
        $display("[CPU] Step 1: tx_done is 1. UART is ready.");

        // 2. Cấu hình khung UART (8 bits, 1 stop, No parity) 
        // data_bit_num = 2'b11, stop_bit_num = 0, parity_en = 0 
        apb_write(12'h008, 32'h0000_0003);
        $display("[CPU] Step 2: Configured UART Frame (8N1).");

        // 3. Ghi dữ liệu tx_data (Ví dụ: 0x55) 
        apb_write(12'h000, 32'h0000_0055);
        $display("[CPU] Step 3: Wrote data 0x55 to tx_data_reg.");

        // 4. Đặt start_tx = 1 để bắt đầu truyền 
        apb_write(12'h00C, 32'h0000_0001);
        $display("[CPU] Step 4: Set start_tx = 1. Transmission started.");

        // --- QUY TRÌNH NHẬN (Hình 4) ---
        // 5. Đợi rx_done == 1 (CPU chờ dữ liệu về từ RX) 
        $display("[CPU] Step 5: Waiting for rx_done...");
        do begin
            apb_read(12'h010, status);
        end while (status[1] !== 1'b1);
        $display("[CPU] rx_done is 1. Data received successfully.");

        // 6. CPU đọc dữ liệu từ thanh ghi rx_data 
        apb_read(12'h004, received_val);
        $display("[CPU] Step 6: Read rx_data = 0x%h", received_val[7:0]);

        // Kiểm tra kết quả
        if (received_val[7:0] == 8'h55)
            $display("==> KẾT QUẢ: THÀNH CÔNG (Data match)");
        else
            $display("==> KẾT QUẢ: THẤT BẠI (Expected 0x55, got 0x%h)", received_val[7:0]);

        #1000;
        $finish;
    end

endmodule
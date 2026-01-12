interface apb_if (input logic pclk, input logic presetn);
    logic [11:0] paddr;
    logic        psel;
    logic        penable;
    logic        pwrite;
    logic [3:0]  pstrb;
    logic [31:0] pwdata;
    logic [31:0] prdata;
    logic        pready;
    logic        pslverr;

    // Tín hiệu hỗ trợ Transaction Recording 
    bit monstart, drvstart;

    // --- TASK: WRITE TRANSFER (Dùng cho Driver) ---
    task automatic write_task(input logic [11:0] addr, 
                              input logic [31:0] data, 
                              input logic [3:0]  strb = 4'hf);
        // T1: Setup Phase 
        @(posedge pclk);
        drvstart <= 1'b1; // Kích hoạt trigger ghi lại giao dịch của Driver
        psel     <= 1'b1;
        pwrite   <= 1'b1;
        paddr    <= addr;
        pwdata   <= data;
        pstrb    <= strb;
        penable  <= 1'b0;

        // T2: Access Phase
        @(posedge pclk);
        penable  <= 1'b1;
        
        wait(pready === 1'b1); 
        @(posedge pclk); // Kết thúc chuyển giao
        
        psel     <= 1'b0;
        penable  <= 1'b0;
        drvstart <= 1'b0; // Tắt trigger 
    endtask

    // --- TASK: READ TRANSFER (Dùng cho Driver) ---
    task automatic read_task(input  logic [11:0] addr, 
                             output logic [31:0] data);
        @(posedge pclk);
        drvstart <= 1'b1;
        psel     <= 1'b1;
        pwrite   <= 1'b0;
        paddr    <= addr;
        pstrb    <= 4'h0; // Read không dùng strobe
        penable  <= 1'b0;

        @(posedge pclk);
        penable  <= 1'b1;
        
        wait(pready === 1'b1); 
        @(posedge pclk); 
        
        data     = prdata;
        psel     <= 1'b0;
        penable  <= 1'b0;
        drvstart <= 1'b0;
    endtask

    // --- TASK: MONITOR COLLECT (Dùng cho Monitor) ---
    task automatic collect_apb_transaction(output logic [11:0] addr,
                                           output logic [31:0] captured_data,
                                           output logic        is_write,
                                           output logic [3:0]  strobe,
                                           output logic        err);
        // Đợi đến thời điểm Access Phase hoàn tất thành công (PREADY lên cao)
        wait(psel === 1'b1 && penable === 1'b1 && pready === 1'b1);
        
        monstart <= 1'b1; // Trigger cho Monitor recording 
        
        addr     = paddr;
        is_write = pwrite;
        strobe   = pstrb; 
        err      = pslverr;
        
        if (pwrite) begin
            // Xử lý tường minh cho pstrb: Chỉ thu thập các byte lane hợp lệ
            captured_data = 32'h0;
            if (pstrb[0]) captured_data[7:0]   = pwdata[7:0];
            if (pstrb[1]) captured_data[15:8]  = pwdata[15:8];
            if (pstrb[2]) captured_data[23:16] = pwdata[23:16];
            if (pstrb[3]) captured_data[31:24] = pwdata[31:24];
        end
        else begin
            captured_data = prdata; // Đọc toàn bộ dữ liệu trả về
        end

        @(posedge pclk); 
        monstart <= 1'b0; // Tắt trigger 
    endtask

endinterface
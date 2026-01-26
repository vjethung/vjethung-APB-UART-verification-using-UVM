import uvm_pkg::*;
`include "uvm_macros.svh"
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
    // bit monitor_start; 
    bit drive_start;

    // WRITE TRANSFER - Driver
    task automatic write_task(input logic [11:0] addr, 
                              input logic [31:0] data, 
                              input logic [3:0]  strb = 4'hf);
        // T1: Setup Phase 
        @(posedge pclk);
        drive_start <= 1'b1; // Kích hoạt trigger ghi lại giao dịch của Driver
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
        drive_start <= 1'b0; // Tắt trigger 
    endtask

    // READ TRANSFER - Driver 
    task automatic read_task(input  logic [11:0] addr, 
                             output logic [31:0] data);
        @(posedge pclk);
        drive_start <= 1'b1;
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
        drive_start <= 1'b0;
    endtask

    // MONITOR COLLECT - Monitor
    task automatic collect_apb_transaction(output logic [11:0] addr,
                                           output logic [31:0] captured_data,
                                           output logic        is_write,
                                           output logic [3:0]  strobe,
                                           output logic        err);
        // thời điểm Access Phase hoàn tất thành công (PREADY lên cao)
        // wait(psel === 1'b1 && penable === 1'b1 && pready === 1'b1);
        do begin
          @(posedge pclk);
        end while (!(psel === 1'b1 && penable === 1'b1 && pready === 1'b1));
        // monitor_start <= 1'b1; // Trigger cho Monitor recording 
        
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
            captured_data = prdata; 
        end

        // @(posedge pclk); 
        // monitor_start <= 1'b0; // Tắt trigger 
    endtask

    // SVA
    property p_apb_reset_default;
    @(negedge presetn) | presetn-> (psel === 0 && penable === 0) || (psel === 'x && penable === 'x);
    endproperty

    property p_setup_to_access;
      @(posedge pclk) disable iff (!presetn)
        (psel && !penable) |=> (psel && penable);
    endproperty

    // property p_penable_requires_psel;
    //   @(posedge pclk) disable iff (psel !== 'x)
    //     penable && psel;
    // endproperty

    property p_addr_ctrl_stable_when_wait;
      @(posedge pclk) disable iff (!presetn)
        (psel && !pready) |=> ($stable(paddr) && $stable(pwrite));
    endproperty

    property p_wdata_stable_when_wait;
      @(posedge pclk) disable iff (!presetn)
        (psel && pwrite && !pready) |=> ($stable(pwdata) && $stable(pstrb));
    endproperty

    property p_read_strb_low;
      @(posedge pclk) disable iff (!presetn)
        (psel && !pwrite) |-> (pstrb == '0);
    endproperty

    localparam logic [11:0] ADDR_TX   = 12'h000;
    localparam logic [11:0] ADDR_RX   = 12'h004;
    localparam logic [11:0] ADDR_CFG  = 12'h008;
    localparam logic [11:0] ADDR_CTRL = 12'h00C;
    localparam logic [11:0] ADDR_STT  = 12'h010;

    function automatic bit is_valid_wr_addr(logic [11:0] a);
      return (a inside {ADDR_TX, ADDR_CFG, ADDR_CTRL});
    endfunction

    function automatic bit apb_access ();
      return (psel && penable && pready);
    endfunction

    property p_err_write_ro;
      @(posedge pclk) disable iff (!presetn)
        (apb_access() && pwrite && (paddr inside {ADDR_RX, ADDR_STT}))
        |-> (##0 (pslverr) or ##1 (pslverr));
    endproperty

    property p_err_write_invalid;
      @(posedge pclk) disable iff (!presetn)
        (apb_access() && pwrite && !is_valid_wr_addr(paddr) && !(paddr inside {ADDR_RX, ADDR_STT}))
        |-> (pslverr == 1'b1);
    endproperty

    property p_ok_write_valid;
      @(posedge pclk) disable iff (!presetn)
        (apb_access() && pwrite && is_valid_wr_addr(paddr))
        |-> (pslverr == 1'b0);
    endproperty

    property p_err_read_invalid;
      @(posedge pclk) disable iff (!presetn)
        (apb_access() && !pwrite && !(paddr inside {ADDR_TX, ADDR_RX, ADDR_CFG, ADDR_CTRL, ADDR_STT}))
        |-> (pslverr == 1'b1);
    endproperty

    APB_RESET:           assert property (p_apb_reset_default)      else `uvm_error("APB_SVA", "Reset error: psel/penable not low");
    APB_SETUP_ACCESS:    assert property (p_setup_to_access)        else `uvm_error("APB_SVA", "APB SETUP->ACCESS violated");
    // APB_PENABLE_VALID:   assert property (p_penable_requires_psel)  else `uvm_error("APB_SVA", "penable=1 but psel=0");
    APB_ADDR_STABLE:     assert property (p_addr_ctrl_stable_when_wait) else `uvm_error("APB_SVA", "paddr/pwrite not stable while wait");
    APB_WDATA_STABLE:    assert property (p_wdata_stable_when_wait) else `uvm_error("APB_SVA", "pwdata/pstrb not stable while wait");
    APB_READ_STRB0:      assert property (p_read_strb_low)          else `uvm_error("APB_SVA", "read but pstrb != 0");

    ERR_WR_RO:           assert property (p_err_write_ro)           else `uvm_error("APB_SVA", "Write RO did NOT raise PSLVERR");
    ERR_WR_INV:          assert property (p_err_write_invalid)      else `uvm_warning("APB_SVA", "Write invalid did NOT raise PSLVERR");
    OK_WR_VALID:         assert property (p_ok_write_valid)         else `uvm_error("APB_SVA", "Valid write unexpectedly raised PSLVERR");
endinterface
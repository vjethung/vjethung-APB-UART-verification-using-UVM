// ------------------------------------------------------------------
// BASE VIRTUAL SEQUENCE
// ------------------------------------------------------------------
// Lớp cha chứa các xử lý chung: Objection, p_sequencer handle
class base_vseq extends uvm_sequence;
  `uvm_object_utils(base_vseq)
  
  `uvm_declare_p_sequencer(uart_virsequencer)

  // Handle cho sequencer vật lý (để con dùng luôn)
  apb_sequencer  apb_sqr;
  uart_sequencer uart_sqr;

  function new(string name="base_vseq");
    super.new(name);
  endfunction

  // Tự động gán handle khi sequence bắt đầu
  virtual task body();
    if (p_sequencer == null) `uvm_fatal("VSEQ", "Virtual Sequencer is NULL")
    apb_sqr  = p_sequencer.apb_sqr;
    uart_sqr = p_sequencer.uart_sqr;
  endtask

  // Quản lý Objection tự động
  virtual task pre_body();
    uvm_phase phase;
    `ifdef UVM_VERSION_1_2
      phase = get_starting_phase();
    `else
      phase = starting_phase;
    `endif
    if (phase != null) begin
      phase.raise_objection(this, get_type_name());
      `uvm_info("VSEQ", "Raise Objection", UVM_MEDIUM)
    end
  endtask

  virtual task post_body();
    uvm_phase phase;
    `ifdef UVM_VERSION_1_2
      phase = get_starting_phase();
    `else
      phase = starting_phase;
    `endif
    if (phase != null) begin
      phase.drop_objection(this, get_type_name());
      `uvm_info("VSEQ", "Drop Objection", UVM_MEDIUM)
    end
  endtask
endclass

// SEQUENCE: SYSTEM CONFIGURATION
// Cấu hình đồng bộ cả DUT và UVC
class system_config_seq extends base_vseq;
    `uvm_object_utils(system_config_seq)

    rand apb_uart_config shared_cfg;
    
    apb_config_frame_seq apb_seq;    
    uart_config_frame_seq uart_seq;  

    function new(string name="system_config_seq");
        super.new(name);
    endfunction

    virtual task body();
        super.body(); 

        // 1. Random Config
        shared_cfg = apb_uart_config::type_id::create("shared_cfg");
        if(!shared_cfg.randomize()) `uvm_fatal("VSEQ", "Config Randomization Failed")

        // 2. Cấu hình DUT qua APB
        apb_seq = apb_config_frame_seq::type_id::create("apb_seq");
        apb_seq.cfg = shared_cfg; 
        `uvm_info("VSEQ", "Configuring DUT via APB...", UVM_LOW)
        apb_seq.start(apb_sqr); 

        // 3. Cấu hình UART Driver
        uart_seq = uart_config_frame_seq::type_id::create("uart_seq");
        uart_seq.cfg = shared_cfg;
        `uvm_info("VSEQ", "Synchronizing UART UVC...", UVM_LOW)
        uart_seq.start(uart_sqr); 
    endtask
endclass

// SEQUENCE: SANITY TEST (APB -> UART)
// Kịch bản truyền nhận dữ liệu cơ bản
class vseq_apb_to_uart extends base_vseq;
    `uvm_object_utils(vseq_apb_to_uart)

    system_config_seq    config_vseq;  
    apb_trans_data_seq   apb_write_seq; 
    apb_read_status_seq  stt_seq;

    function new(string name="vseq_apb_to_uart");
        super.new(name);
    endfunction

    virtual task body();
        bit tx_done = 0;
        int timeout = 0;

        super.body(); 
        `uvm_info("VSEQ", "=== STARTING SANITY TEST: APB to UART ===", UVM_LOW)

        // 1. Cấu hình hệ thống
        config_vseq = system_config_seq::type_id::create("config_vseq");
        config_vseq.start(p_sequencer); 
        
        // 2. Gửi dữ liệu (Ghi Data -> Ghi Start Bit)
        apb_write_seq = apb_trans_data_seq::type_id::create("apb_write_seq");
        if(!apb_write_seq.randomize()) `uvm_fatal("VSEQ", "Data Randomize Failed")
        
        `uvm_info("VSEQ", $sformatf("Sending Data: 0x%h", apb_write_seq.tx_byte), UVM_LOW)
        apb_write_seq.start(apb_sqr); 
        
        // 3. Polling: Đợi TX_DONE (bit 0 của reg 0x10)
        stt_seq = apb_read_status_seq::type_id::create("stt_seq");
        
        while(!tx_done) begin
            stt_seq.start(apb_sqr);
            if(stt_seq.req.prdata[0] == 1) begin
                tx_done = 1;
                `uvm_info("VSEQ", "TX_DONE Detected!", UVM_LOW)
            end else begin
                timeout++;
                if(timeout > 500) begin
                     `uvm_error("VSEQ", "Timeout waiting for TX_DONE")
                     break;
                end
                #10us; // Đợi 1 chút trước khi đọc lại
            end
        end
        `uvm_info("VSEQ", "=== SANITY TEST COMPLETED ===", UVM_LOW)
    endtask
endclass

// SEQUENCE: ERROR INJECTION TEST
class vseq_parity_error_test extends base_vseq;
    `uvm_object_utils(vseq_parity_error_test)

    apb_uart_config       err_cfg;
    apb_config_frame_seq  apb_cfg;
    uart_config_frame_seq uart_sync;
    uart_error_inject_seq uart_err_seq;
    apb_read_status_seq   stt_seq;

    function new(string name="vseq_parity_error_test");
        super.new(name);
    endfunction

    virtual task body();
        super.body();
        `uvm_info("VSEQ", "=== STARTING PARITY ERROR INJECTION TEST ===", UVM_LOW)

        // 1. Cấu hình BẮT BUỘC phải bật Parity
        err_cfg = apb_uart_config::type_id::create("err_cfg");
        if(!err_cfg.randomize() with {
            parity_en == PARITY_EN; 
            data_width == DATA_8BIT;
        }) `uvm_fatal("VSEQ", "Config Randomization Failed")

        // 2. Setup DUT
        apb_cfg = apb_config_frame_seq::type_id::create("apb_cfg");
        apb_cfg.cfg = err_cfg;
        apb_cfg.start(apb_sqr);

        // 3. Setup UART UVC
        uart_sync = uart_config_frame_seq::type_id::create("uart_sync");
        uart_sync.cfg = err_cfg;
        uart_sync.start(uart_sqr);

        // 4. Tiêm lỗi từ UART (Gửi dữ liệu sai Parity vào RX của DUT)
        uart_err_seq = uart_error_inject_seq::type_id::create("uart_err_seq");
        `uvm_info("VSEQ", "Injecting Bad Parity Packets...", UVM_LOW)
        uart_err_seq.start(uart_sqr);

        // 5. Kiểm tra thanh ghi trạng thái của DUT (0x10)
        stt_seq = apb_read_status_seq::type_id::create("stt_seq");
        stt_seq.start(apb_sqr);
        
        `uvm_info("VSEQ", $sformatf("Status Register Readback: 0x%h", stt_seq.req.prdata), UVM_LOW)
        
        // Logic kiểm tra (Tuỳ thuộc vào Spec của thanh ghi 0x10)
        // if (stt_seq.req.prdata[2] == 1) `uvm_info("PASS", "DUT detected Parity Error", UVM_NONE)
        // else `uvm_error("FAIL", "DUT failed to detect Parity Error")

        `uvm_info("VSEQ", "=== ERROR INJECTION TEST COMPLETED ===", UVM_LOW)
    endtask
endclass
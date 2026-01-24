// BASE VIRTUAL SEQUENCE
class base_vseq extends uvm_sequence;
  `uvm_object_utils(base_vseq)
  
  // Các lớp con truy cập: p_sequencer.apb_sqr và p_sequencer.uart_sqr
  `uvm_declare_p_sequencer(uart_virsequencer)

  function new(string name="base_vseq");
    super.new(name);
  endfunction

  task pre_body();
    uvm_phase phase;
    `ifdef UVM_VERSION_1_2
      phase = get_starting_phase();
    `else
      phase = starting_phase;
    `endif
    if (phase != null) begin
      phase.raise_objection(this, get_type_name());
      `uvm_info(get_type_name(), "raise objection", UVM_HIGH)
    end
  endtask : pre_body

  task post_body();
    uvm_phase phase;
    `ifdef UVM_VERSION_1_2
      phase = get_starting_phase();
    `else
      phase = starting_phase;
    `endif
    if (phase != null) begin
      phase.drop_objection(this, get_type_name());
      `uvm_info(get_type_name(), "drop objection", UVM_HIGH)
    end
  endtask : post_body

endclass

// SEQUENCE: SYSTEM CONFIGURATION
class system_config_seq extends base_vseq;
    `uvm_object_utils(system_config_seq)

    rand apb_uart_config shared_cfg;
    
    // Khai báo sequence con
    apb_config_frame_seq apb_seq;    
    uart_config_frame_seq uart_seq;  

    function new(string name="system_config_seq");
        super.new(name);
    endfunction

  virtual task body();
    // Lấy config đã được Test nạp sẵn trong DB
    if (!system_config::get(null, get_full_name(), "cfg", shared_cfg)) begin
        `uvm_fatal("VSEQ", "Cannot find 'cfg' in Config DB! Check base_test.")
    end

    `uvm_info("VSEQ", "Configuring System using shared object from Test...", UVM_LOW)

    // Cấu hình APB luôn chạy
    apb_seq = apb_config_frame_seq::type_id::create("apb_seq");
    apb_seq.cfg = shared_cfg; 
    apb_seq.start(p_sequencer.apb_sqr);

    if (shared_cfg.monitor_mode == MON_RX_ONLY || shared_cfg.monitor_mode == MON_BOTH) begin
        `uvm_info("VSEQ", "Activating UART Driver for RX path", UVM_MEDIUM)
        uart_seq = uart_config_frame_seq::type_id::create("uart_seq");
        uart_seq.cfg = shared_cfg; 
        uart_seq.start(p_sequencer.uart_sqr);
    end else begin
        `uvm_info("VSEQ", "UART Driver remains IDLE (TX Only Mode)", UVM_MEDIUM)
    end
  endtask
endclass

// SEQUENCE:  TEST (APB -> UART)
class vseq_apb_to_uart extends base_vseq;
    `uvm_object_utils(vseq_apb_to_uart)

    system_config_seq    config_vseq;  
    apb_trans_data_seq   apb_write_send_seq; 
    apb_read_status_seq  stt_seq;
    apb_uart_config      shared_cfg;

    function new(string name="vseq_apb_to_uart");
        super.new(name);
    endfunction

    virtual task body();
        bit tx_done = 0;
        int timeout = 0;
        
        int num_data_bits;
        int total_frame_bits;
        real bit_period_ns;

        `uvm_info("VSEQ", "=== STARTING  TEST: APB to UART ===", UVM_MEDIUM)

        // Lấy Config từ DB
        if (!system_config::get(null, get_full_name(), "cfg", shared_cfg)) begin
            `uvm_fatal("VSEQ", "Cannot find 'cfg' in Config DB!")
        end

        config_vseq = system_config_seq::type_id::create("config_vseq");
        config_vseq.shared_cfg = shared_cfg;
        `uvm_do(config_vseq) 

        // TÍNH TOÁN DELAY TỰ ĐỘNG
        case(shared_cfg.data_width)
            DATA_5BIT: num_data_bits = 5;
            DATA_6BIT: num_data_bits = 6;
            DATA_7BIT: num_data_bits = 7;
            DATA_8BIT: num_data_bits = 8;
            default:   num_data_bits = 8;
        endcase

        // Tổng số bit trong 1 khung = 1 (Start) + Data + Parity + Stop 
        total_frame_bits = 1 + num_data_bits; 
        if (shared_cfg.parity_en == PARITY_EN) total_frame_bits += 1;
        total_frame_bits += (shared_cfg.stop_bits == STOP_2BIT) ? 2 : 1;

        // Tính thời gian 1 bit (ns) dựa trên Baudrate 
        bit_period_ns = 1000000000.0 / shared_cfg.baud_rate;

        `uvm_info("VSEQ", $sformatf("Calc: Bits=%0d, Baud=%0d, Tbit=%0.2fns", 
                  total_frame_bits, shared_cfg.baud_rate, bit_period_ns), UVM_LOW)

        // Gửi dữ liệu qua APB
        `uvm_do_on(apb_write_send_seq, p_sequencer.apb_sqr)
        
        // Chờ đúng khoảng thời gian truyền hết khung vật lý
        repeat(total_frame_bits) #(bit_period_ns * 1ns); 

        // Polling trạng thái
        stt_seq = apb_read_status_seq::type_id::create("stt_seq"); 
        while(!tx_done) begin
            `uvm_do_on(stt_seq, p_sequencer.apb_sqr)
            if(stt_seq.req.prdata[0] == 1) begin
                tx_done = 1;
                `uvm_info("VSEQ", "TX_DONE Detected!", UVM_LOW)
            end else begin
                if(timeout++ > 1000) begin 
                     `uvm_error("VSEQ", "Timeout waiting for TX_DONE")
                     break;
                end
                #10us; 
            end
        end
        `uvm_info("VSEQ", "===  TEST COMPLETED ===", UVM_MEDIUM)
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
        `uvm_info("VSEQ", "=== STARTING PARITY ERROR INJECTION TEST ===", UVM_MEDIUM)

        // 1. Tạo Config BẮT BUỘC có Parity
        err_cfg = apb_uart_config::type_id::create("err_cfg");
        if(!err_cfg.randomize() with {
            parity_en == PARITY_EN; 
            data_width == DATA_8BIT;
        }) `uvm_fatal("VSEQ", "Config Randomization Failed")

        // 2. Setup DUT (Trên APB Sequencer)
        `uvm_do_on_with(apb_cfg, p_sequencer.apb_sqr, { 
            cfg == err_cfg; 
        })

        // 3. Setup UART UVC (Trên UART Sequencer)
        `uvm_do_on_with(uart_sync, p_sequencer.uart_sqr, { 
            cfg == err_cfg; 
        })

        // 4. Tiêm lỗi từ UART (Trên UART Sequencer)
        `uvm_info("VSEQ", "Injecting Bad Parity Packets...", UVM_LOW)
        `uvm_do_on(uart_err_seq, p_sequencer.uart_sqr)

        // 5. Kiểm tra thanh ghi trạng thái (Trên APB Sequencer)
        `uvm_do_on(stt_seq, p_sequencer.apb_sqr)
        `uvm_info("VSEQ", $sformatf("Status Register Readback: 0x%h", stt_seq.req.prdata), UVM_LOW)

        `uvm_info("VSEQ", "=== ERROR INJECTION TEST COMPLETED ===", UVM_MEDIUM)
    endtask
endclass
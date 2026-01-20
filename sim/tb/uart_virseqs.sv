class system_config_seq extends uvm_sequence;
    `uvm_object_utils(system_config_seq)
    
    `uvm_declare_p_sequencer(uart_virsequencer)

    rand apb_uart_config shared_cfg; 
    apb_config_frame_seq apb_seq;    
    uart_config_frame_seq uart_seq;  

    function new(string name="system_config_seq");
        super.new(name);
    endfunction

    virtual task body();
        shared_cfg = apb_uart_config::type_id::create("shared_cfg");
        
        if(!shared_cfg.randomize()) begin
            `uvm_fatal("VSEQ", "Randomize config failed")
        end

        `uvm_info("VSEQ", "-------------------------------------------------", UVM_NONE)
        `uvm_info("VSEQ", "       GENERATED SHARED CONFIGURATION            ", UVM_NONE)
        `uvm_info("VSEQ", "-------------------------------------------------", UVM_NONE)
        // .name to print name of enum type
        `uvm_info("VSEQ", $sformatf("Data Size   : %s", shared_cfg.data_width.name()), UVM_NONE)
        `uvm_info("VSEQ", $sformatf("Stop Bits   : %s", shared_cfg.stop_bits.name()), UVM_NONE)
        `uvm_info("VSEQ", $sformatf("Parity Mode : %s", shared_cfg.parity_en.name()), UVM_NONE)
        `uvm_info("VSEQ", $sformatf("Parity Type : %s", shared_cfg.parity_type.name()), UVM_NONE)
        `uvm_info("VSEQ", $sformatf("Baud Rate   : %0d", shared_cfg.baud_rate), UVM_NONE)
        `uvm_info("VSEQ", "-------------------------------------------------", UVM_NONE)

        `uvm_info("VSEQ", "[STEP 1] Sending Config Sequence to APB UVC (Target: DUT Registers)...", UVM_LOW)
        
        apb_seq = apb_config_frame_seq::type_id::create("apb_seq");
        apb_seq.cfg = shared_cfg; 
        
        apb_seq.start(p_sequencer.apb_sqr);
        `uvm_info("VSEQ", " -> DUT Configuration Completed via APB.", UVM_LOW)

        `uvm_info("VSEQ", "[STEP 2] Sending Config Sequence to UART UVC (Target: Driver Frame Generation)...", UVM_LOW)
        `uvm_info("VSEQ", "         Ensuring UART Frame matches DUT Configuration...", UVM_LOW)
        
        uart_seq = uart_config_frame_seq::type_id::create("uart_seq");
        uart_seq.cfg = shared_cfg;

        uart_seq.start(p_sequencer.uart_sqr);
        `uvm_info("VSEQ", " -> UART Synchronized Frame Sent.", UVM_LOW)
        
        `uvm_info("VSEQ", "-------------------------------------------------", UVM_NONE)
        `uvm_info("VSEQ", "       TEST SEQUENCE FINISHED                    ", UVM_NONE)
        `uvm_info("VSEQ", "-------------------------------------------------", UVM_NONE)

    endtask

endclass

class vseq_simple_transfer extends uvm_sequence;
    `uvm_object_utils(vseq_simple_transfer)
    `uvm_declare_p_sequencer(uart_virsequencer) 

    apb_uart_config shared_cfg;
    system_config_seq config_vseq;  
    apb_trans_data_seq data_apb_seq; 

    function new(string name="vseq_simple_transfer");
        super.new(name);
    endfunction

    virtual task body();
        // Đồng bộ cấu hình giữa DUT (qua APB) và UART Driver
        config_vseq = system_config_seq::type_id::create("config_vseq");
        config_vseq.shared_cfg = shared_cfg; 
        config_vseq.start(p_sequencer); // Chạy trên Virtual Sequencer 

        // Ghi dữ liệu vào thanh ghi TX_DATA và kích hoạt truyền (Start TX)
        data_apb_seq = apb_trans_data_seq::type_id::create("data_apb_seq");
        
        // Random dữ liệu gửi đi
        if(!data_apb_seq.randomize()) `uvm_fatal("VSEQ", "Randomize data failed")
        
        `uvm_info("VSEQ", "[STEP 3] Starting APB Data Transfer...", UVM_LOW)
        data_apb_seq.start(p_sequencer.apb_sqr); // Chạy trực tiếp trên APB Sequencer
        
        // Đợi cho đến khi quá trình truyền hoàn tất
        `uvm_info("VSEQ", "[STEP 4] Waiting for TX_DONE status...", UVM_LOW)
        data_apb_seq.wait_for_tx_done(); // Poll thanh ghi 0x10 
    endtask
endclass

class vseq_apb_to_uart extends uvm_sequence;
  `uvm_object_utils(vseq_apb_to_uart)
  `uvm_declare_p_sequencer(uart_virsequencer) // Khai báo p_sequencer 

  // Khai báo các sequence con đã có
  apb_config_frame_seq   apb_cfg_seq;
  uart_config_frame_seq  uart_sync_seq;
  apb_trans_data_seq     apb_write_seq;

  rand apb_uart_config   vseq_cfg;

  function new(string name="vseq_apb_to_uart");
    super.new(name);
  endfunction

  // Quản lý Objection theo chuẩn UVM 1.2 trong file tham khảo 
  task pre_body();
    uvm_phase phase;
    `ifdef UVM_VERSION_1_2
      phase = get_starting_phase();
    `else
      phase = starting_phase;
    `endif
    if (phase != null) phase.raise_objection(this, get_type_name());
  endtask

  task body();
    if (vseq_cfg == null) vseq_cfg = apb_uart_config::type_id::create("vseq_cfg");
    void'(vseq_cfg.randomize());

    `uvm_info(get_type_name(), "Executing basic APB to UART transfer", UVM_LOW)

    // Bước 1: Đồng bộ cấu hình Frame cho cả DUT và UART Driver
    apb_cfg_seq = apb_config_frame_seq::type_id::create("apb_cfg_seq");
    apb_cfg_seq.cfg = vseq_cfg;
    `uvm_do_on(apb_cfg_seq, p_sequencer.apb_sqr) // Chạy trên APB Sequencer 

    uart_sync_seq = uart_config_frame_seq::type_id::create("uart_sync_seq");
    uart_sync_seq.cfg = vseq_cfg;
    `uvm_do_on(uart_sync_seq, p_sequencer.uart_sqr) // Chạy trên UART Sequencer 

    // Bước 2: Gửi dữ liệu qua APB (Ghi 0x00 và Kích hoạt 0x0C)
    apb_write_seq = apb_trans_data_seq::type_id::create("apb_write_seq");
    void'(apb_write_seq.randomize());
    `uvm_do_on(apb_write_seq, p_sequencer.apb_sqr)

    // Bước 3: Đợi trạng thái TX DONE từ thanh ghi 0x10
    apb_write_seq.wait_for_tx_done();
  endtask

  task post_body();
    uvm_phase phase;
    `ifdef UVM_VERSION_1_2
      phase = get_starting_phase();
    `else
      phase = starting_phase;
    `endif
    if (phase != null) phase.drop_objection(this, get_type_name());
  endtask
endclass
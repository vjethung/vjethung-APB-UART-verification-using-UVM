// --------------------------------------------------------------------------
// BASE TEST: Chứa cấu hình môi trường chung
// --------------------------------------------------------------------------
class base_test extends uvm_test;

  `uvm_component_utils(base_test)

  apb_uart_env env;
  apb_uart_config cfg;

  function new (string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    // Bật tính năng ghi lại Waveform (Transaction Recording)
    uvm_config_int::set( this, "*", "recording_detail", 1);
    
    // Tạo và Set Config object
    cfg = apb_uart_config::type_id::create("cfg");
    if(!cfg.randomize()) `uvm_fatal("TEST", "Config Randomization Failed");

    system_config::set(this, "env", "cfg", cfg);
    
    // Tạo Environment
    env = apb_uart_env::type_id::create("env", this);
  endfunction : build_phase

  function void end_of_elaboration_phase(uvm_phase phase);
    `uvm_info(get_type_name(), "Printing topology:", UVM_LOW)
    uvm_top.print_topology();
  endfunction

  function void start_of_simulation_phase(uvm_phase phase);
    `uvm_info(get_type_name(), {"start of simulation for ", get_full_name()}, UVM_HIGH);
  endfunction : start_of_simulation_phase

  task run_phase(uvm_phase phase);
    // Drain time: Thời gian chờ thêm sau khi sequence kết thúc.
    // UART Baud 115200 -> 1 bit ~ 8.6us. 
    uvm_objection obj = phase.get_objection();
    obj.set_drain_time(this, 150us); 
  endtask : run_phase

  function void check_phase(uvm_phase phase);
    check_config_usage();
  endfunction
endclass

// --------------------------------------------------------------------------
// TEST 1: SIMPLE TRANSFER (Sanity Check)
// Mục tiêu: Kiểm tra luồng dữ liệu APB -> DUT -> UART UVC
// --------------------------------------------------------------------------
class simple_test extends base_test;
  `uvm_component_utils(simple_test)

  function new (string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    uvm_config_wrapper::set(this, 
                            "env.vir_seqr.run_phase", 
                            "default_sequence", 
                            system_config_seq::get_type());
    
    super.build_phase(phase);
    
    `uvm_info("TEST", "\n####======================== Build phase: SIMPLE TEST configured with system_config_seq ========================#####", UVM_LOW)
  endfunction

endclass

class test_send_1_frame extends base_test;
  `uvm_component_utils(test_send_1_frame)

  function new (string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    uvm_config_wrapper::set(this, 
                            "env.vir_seqr.run_phase", 
                            "default_sequence", 
                            vseq_send_TX::get_type());
    
    super.build_phase(phase);
    
    cfg.monitor_mode = MON_TX_ONLY;
    
    `uvm_info("TEST", "\n####======================== SEND 1 FRAME configured (TX Monitoring Only) ========================#####", UVM_LOW)
  endfunction
endclass 

class test_send_N_frame extends base_test;
  `uvm_component_utils(test_send_N_frame)

  function new (string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    uvm_config_wrapper::set(this, 
                            "env.vir_seqr.run_phase", 
                            "default_sequence", 
                            vseq_send_N_TX::get_type());
    
    super.build_phase(phase);
    
    cfg.monitor_mode = MON_TX_ONLY;
    
    `uvm_info("TEST", "\n####======================== SEND N FRAME configured (TX Monitoring Only) ========================#####", UVM_LOW)
  endfunction
endclass 

class test_received_1_frame extends base_test;
  `uvm_component_utils(test_received_1_frame)

  function new (string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    // 1. Gán sequence mặc định cho Virtual Sequencer
    uvm_config_wrapper::set(this, 
                            "env.vir_seqr.run_phase", 
                            "default_sequence", 
                            vseq_receive_RX::get_type()); // Dùng vseq nhận RX bạn vừa đổi tên

    // 2. Gọi super.build_phase để base_test tạo và randomize đối tượng cfg 
    super.build_phase(phase);
    
    // 3. Thiết lập chế độ giám sát (Monitor Mode)
    // MON_RX_ONLY: Chỉ giám sát hướng từ UVC đẩy vào DUT (RX path) 
    cfg.monitor_mode = MON_RX_ONLY; 
    
    `uvm_info("TEST", "\n####======================== RECEIVE 1 FRAME configured (RX Monitoring only) ========================#####", UVM_LOW)
  endfunction
endclass

class test_received_N_frame extends base_test;
  `uvm_component_utils(test_received_N_frame)

  function new (string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    // 1. Gán sequence mặc định cho Virtual Sequencer
    uvm_config_wrapper::set(this, 
                            "env.vir_seqr.run_phase", 
                            "default_sequence", 
                            vseq_receive_N_RX::get_type()); // Dùng vseq nhận RX bạn vừa đổi tên

    // 2. Gọi super.build_phase để base_test tạo và randomize đối tượng cfg 
    super.build_phase(phase);
    
    // 3. Thiết lập chế độ giám sát (Monitor Mode)
    // MON_RX_ONLY: Chỉ giám sát hướng từ UVC đẩy vào DUT (RX path) 
    cfg.monitor_mode = MON_RX_ONLY; 
    cfg.parity_err_target = GOOD_PARITY;
    `uvm_info("TEST", "\n####======================== RECEIVE N FRAME configured (RX Monitoring only) ========================#####", UVM_LOW)
  endfunction
endclass
// --------------------------------------------------------------------------
// TEST 2: PARITY ERROR INJECTION (Negative Test)
// Mục tiêu: Kiểm tra DUT xử lý thế nào khi nhận gói tin lỗi Parity từ UART
// --------------------------------------------------------------------------
class test_parity_error extends base_test;
  `uvm_component_utils(test_parity_error)

  function new (string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    uvm_config_wrapper::set(this, 
                            "env.vir_seqr.run_phase", 
                            "default_sequence", 
                            vseq_receive_RX_ErrorInject::get_type());

    super.build_phase(phase);

    if (!cfg.randomize() with { monitor_mode == MON_RX_ONLY; 
                                parity_en    == PARITY_EN; 
                                parity_err_target == BAD_PARITY; // Ràng buộc này sẽ thắng 'soft' constraint
    }) begin
        `uvm_fatal("TEST", "\n####======================== Randomization of cfg failed in test_parity_error! ========================#####")
    end

    `uvm_info("TEST", "\n####======================== TEST PARITY DETECT OF DUT ========================#####", UVM_LOW)
  endfunction
endclass

class test_N_parity_error extends base_test;
  `uvm_component_utils(test_N_parity_error)

  function new (string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    uvm_config_wrapper::set(this, 
                            "env.vir_seqr.run_phase", 
                            "default_sequence", 
                            vseq_receive_N_RX_ErrorInject::get_type());

    super.build_phase(phase);

    if (!cfg.randomize() with { monitor_mode == MON_RX_ONLY; 
                                parity_en    == PARITY_EN;
                                parity_err_target == BAD_PARITY;
    }) begin
        `uvm_fatal("TEST", "Randomization of cfg failed in test_parity_error!")
    end

    `uvm_info("TEST", "\n####======================== TEST N trans PARITY DETECT OF DUT ========================#####", UVM_LOW)
  endfunction
endclass

class test_check_reset extends base_test;
  `uvm_component_utils(test_check_reset)

  function new (string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    uvm_config_wrapper::set(this, 
                            "env.vir_seqr.run_phase", 
                            "default_sequence", 
                            vseq_check_reset::get_type());

    super.build_phase(phase);

    `uvm_info("TEST", "\n####======================== TEST VALUE OF REGISTER ========================#####", UVM_LOW)
  endfunction
endclass

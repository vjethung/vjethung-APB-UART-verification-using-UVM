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

    system_config::set(this, "env.*", "cfg", cfg);
    
    // Tạo Environment
    env = apb_uart_env::type_id::create("env", this);
  endfunction : build_phase

  function void end_of_elaboration_phase(uvm_phase phase);
    `uvm_info(get_type_name(), "Printing topology:", UVM_HIGH)
    uvm_top.print_topology();
  endfunction

  function void start_of_simulation_phase(uvm_phase phase);
    `uvm_info(get_type_name(), {"start of simulation for ", get_full_name()}, UVM_HIGH);
  endfunction : start_of_simulation_phase

  task run_phase(uvm_phase phase);
    // Drain time: Thời gian chờ thêm sau khi sequence kết thúc.
    // UART Baud 115200 -> 1 bit ~ 8.6us. 
    uvm_objection obj = phase.get_objection();
    obj.set_drain_time(this, 100us); 
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
    
    `uvm_info("TEST", "Build phase: simple_test configured with system_config_seq", UVM_LOW)
  endfunction

endclass

// --------------------------------------------------------------------------
// TEST 2: PARITY ERROR INJECTION (Negative Test)
// Mục tiêu: Kiểm tra DUT xử lý thế nào khi nhận gói tin lỗi Parity từ UART
// --------------------------------------------------------------------------
// class test_parity_error extends base_test;
//   `uvm_component_utils(test_parity_error)

//   function new (string name, uvm_component parent);
//     super.new(name, parent);
//   endfunction

//   virtual function void build_phase(uvm_phase phase);
//     uvm_config_wrapper::set(this, 
//                             "env.vir_seqr.run_phase", 
//                             "default_sequence", 
//                             vseq_parity_error_test::get_type());

//     super.build_phase(phase);
//     `uvm_info("TEST", "Build phase: test_parity_error configured", UVM_LOW)
//   endfunction
// endclass
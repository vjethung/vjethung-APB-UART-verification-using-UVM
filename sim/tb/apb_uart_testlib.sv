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
    // obj.set_drain_time(this, 150us); 
    obj.set_drain_time(this, 100_000_000); 
  endtask : run_phase

  function void check_phase(uvm_phase phase);
    check_config_usage();
  endfunction
endclass

// --------------------------------------------------------------------------
// TEST 1: SIMPLE TRANSFER (Sanity Check)
// Mục tiêu: Kiểm tra luồng dữ liệu APB -> DUT -> UART UVC
// --------------------------------------------------------------------------
// test ghi config 
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

// APB & register =======================================================================================
// APB & register =======================================================================================
// APB & register =======================================================================================
// APB & register =======================================================================================

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

class test_rxdata_write_ignored extends base_test;
  `uvm_component_utils(test_rxdata_write_ignored)

  function new (string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    uvm_config_wrapper::set(this, 
                            "env.vir_seqr.run_phase", 
                            "default_sequence", 
                            vseq_rxdata_write_ignored::get_type());

    super.build_phase(phase);

    `uvm_info("TEST", "\n####======================== TEST VALUE OF REGISTER ========================#####", UVM_LOW)
  endfunction
endclass

class test_cfg_wr_rd_check extends base_test;
  `uvm_component_utils(test_cfg_wr_rd_check)

  function new (string name, uvm_component parent);
    super.new(name, parent);
  endfunction   

  virtual function void build_phase(uvm_phase phase);
    uvm_config_wrapper::set(this, 
                            "env.vir_seqr.run_phase", 
                            "default_sequence", 
                            vseq_cfg_wr_rd_check::get_type());

    super.build_phase(phase);

    `uvm_info("TEST", "\n####======================== TEST VALUE OF REGISTER ========================#####", UVM_LOW)
  endfunction
endclass

// test đọc ghi data vào thanh ghi
class test_txdata_no_side_effect extends base_test;
  `uvm_component_utils(test_txdata_no_side_effect)

  function new (string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    uvm_config_wrapper::set(this, 
                            "env.vir_seqr.run_phase", 
                            "default_sequence", 
                            vseq_txdata_no_side_effect::get_type());

    super.build_phase(phase);

    `uvm_info("TEST", "\n####======================== TEST VALUE OF REGISTER ========================#####", UVM_LOW)
  endfunction
endclass


class test_send_TX_sweep_all_cfg_32 extends base_test;
  `uvm_component_utils(test_send_TX_sweep_all_cfg_32)

  function new (string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    uvm_config_wrapper::set(this, 
                            "env.vir_seqr.run_phase", 
                            "default_sequence", 
                            vseq_send_TX_sweep_all_cfg_32::get_type());

    super.build_phase(phase);

    `uvm_info("TEST", "\n####======================== TEST ALL CONFIG TO TRAN ========================#####", UVM_LOW)
  endfunction
endclass

class test_receive_RX_sweep_all_cfg_32 extends base_test;
  `uvm_component_utils(test_receive_RX_sweep_all_cfg_32)

  function new (string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    uvm_config_wrapper::set(this, 
                            "env.vir_seqr.run_phase", 
                            "default_sequence", 
                            vseq_receive_RX_sweep_all_cfg_32::get_type());

    super.build_phase(phase);

    `uvm_info("TEST", "\n####======================== TEST ALL CONFIG TO RECV ========================#####", UVM_LOW)
  endfunction
endclass

// =========== TX ====================================================================================
// =========== TX ====================================================================================
// =========== TX ====================================================================================
// =========== TX ====================================================================================

// test tx 1: kiểm tra có bit start khi start_tx reg = 1 
class test_tx_basic extends base_test;
  `uvm_component_utils (test_tx_basic)

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
    
    `uvm_info("TEST", "\n####======================== TEST TX GOES DOWN TO 0 WHEN START_TX GOES UP 1 ========================#####", UVM_LOW)
  endfunction
endclass 

// test tx 2: kiểm khi có cts_n = 0 thì uart truyền bình thường
class test_cts_asserted extends base_test;
  `uvm_component_utils (test_cts_asserted)

  function new (string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    uvm_config_wrapper::set(this, 
                            "env.vir_seqr.run_phase", 
                            "default_sequence", 
                            vseq_tx_cts_asserted::get_type());
    
    super.build_phase(phase);
    
    cfg.monitor_mode = MON_TX_ONLY;
    
    `uvm_info("TEST", "\n####======================== TEST CTS_N ASSERTED ========================#####", UVM_LOW)
  endfunction
endclass 

// test_tx 3: kiểm khi có cts_n = 1, ra lệnh truyền thì uart không truyền đợi bit start_tx reg được set
class test_cts_deasserted extends base_test;
  `uvm_component_utils (test_cts_deasserted)

  function new (string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    uvm_config_wrapper::set(this, 
                            "env.vir_seqr.run_phase", 
                            "default_sequence", 
                            vseq_tx_cts_deasserted::get_type());
    
    super.build_phase(phase);
    
    cfg.monitor_mode = MON_TX_ONLY;
    
    `uvm_info("TEST", "\n####======================== TEST CTS_N DEASSERTED ========================#####", UVM_LOW)
  endfunction
endclass 

// test_tx 4: đang gửi dở thì kéo cts_n lên 1
// class test_cts_mid_frame extends base_test;
//   `uvm_component_utils(test_cts_mid_frame)

//   function new (string name, uvm_component parent);
//     super.new(name, parent);
//   endfunction

//   virtual function void build_phase(uvm_phase phase);
//     uvm_config_wrapper::set(this, "env.vir_seqr.run_phase", "default_sequence", vseq_tx_cts_mid_frame::get_type());
    
//     super.build_phase(phase);
    
//     cfg.monitor_mode = MON_TX_ONLY; 
//   endfunction
// endclass

// tx test seq 4: theo doi tx_don reg, phải về 0 sau 1 chu kì khi start_tx = 1 và lên 1 khi truyền xong
class test_tx_done_pulse extends base_test;
  `uvm_component_utils(test_tx_done_pulse)

  function new (string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    uvm_config_wrapper::set(this, "env.vir_seqr.run_phase", "default_sequence", vseq_tx_done_pulse::get_type());
    super.build_phase(phase);
    
    cfg.monitor_mode = MON_TX_ONLY;

    `uvm_info("TEST", "\n####======================== TEST TX_DONE REG GOES DOWN TO 0 WHEN START_TX GOES UP 1========================#####", UVM_LOW)
    `uvm_info("TEST", "\n####======================== AFTER SEND COMPLETELY TX_DONE GOES UP TO 1 ========================#####", UVM_LOW)
  endfunction
endclass

// tx test seq 5: nạp dữ liệu mới ngay khi tx_done = 1, các khung truyền liên tiếp không có khoảng nghỉ thừa
// run: test_send_N_frame



// =========== RX ====================================================================================
// =========== RX ====================================================================================
// =========== RX ====================================================================================
// =========== RX ====================================================================================

// rx test 1 run: test_received_1_frame
// test rx 2: rts flow 
class test_rx_rts_dynamic extends base_test;
  `uvm_component_utils(test_rx_rts_dynamic)

  function new (string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    uvm_config_wrapper::set(this, 
        "env.vir_seqr.run_phase", 
        "default_sequence", 
        vseq_rx_rts_flow_control::get_type());
    super.build_phase(phase);
    
    cfg.monitor_mode = MON_RX_ONLY; 
  endfunction
endclass
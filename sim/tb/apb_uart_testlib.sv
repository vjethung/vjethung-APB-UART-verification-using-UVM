class base_test extends uvm_test;

  `uvm_component_utils(base_test)

  function new (string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  apb_uart_env env;
  apb_uart_config cfg;

  virtual function void build_phase(uvm_phase phase);

    super.build_phase(phase);

    uvm_config_int::set( this, "*", "recording_detail", 1);
    cfg = apb_uart_config::type_id::create("cfg");
    system_config::set(this, "env.*", "cfg", cfg);
    env = apb_uart_env::type_id::create("env", this);

  endfunction : build_phase

  function void end_of_elaboration_phase(uvm_phase phase);
    `uvm_info(get_type_name(), "Printing topology:", UVM_HIGH)
    uvm_top.print_topology();
  endfunction

  function void start_of_simulation_phase(uvm_phase phase);
    `uvm_info(get_type_name(), {"start of simulation for ", get_full_name()}, UVM_HIGH);
  endfunction : start_of_simulation_phase

  // task run_phase(uvm_phase phase);
  //   uvm_objection obj = phase.get_objection();
  //   obj.set_drain_time(this, 200ns);
  // endtask : run_phase

  task run_phase(uvm_phase phase);
    phase.raise_objection(this); 
    `uvm_info(get_type_name(), "Simulation Started", UVM_LOW)
    #1000ns; 
    phase.drop_objection(this);
  endtask

  function void check_phase(uvm_phase phase);
    check_config_usage();
  endfunction
endclass

// Test case cơ bản để kiểm tra luồng truyền nhận APB -> UART
class test_simple_transfer extends base_test;

  `uvm_component_utils(test_simple_transfer)

  function new (string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    uvm_config_wrapper::set(this, 
                            "env.vir_seqr.run_phase", 
                            "default_sequence", 
                            vseq_apb_to_uart::get_type());

    super.build_phase(phase);
    
    `uvm_info("TEST", "Build phase: simple_transfer_test configured", UVM_LOW)
  endfunction

endclass
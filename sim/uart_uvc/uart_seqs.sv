class uart_base_seq extends uvm_sequence #(uart_transaction);
    `uvm_object_utils(uart_base_seq)

    function new(string name="uart_base_seq");
      super.new(name);
    endfunction

  task pre_body();
    uvm_phase phase;
    `ifdef UVM_VERSION_1_2
      // in UVM1.2, get starting phase from method
      phase = get_starting_phase();
    `else
      phase = starting_phase;
    `endif

    if (phase != null) begin
      phase.raise_objection(this, get_type_name());
      `uvm_info(get_type_name(), "raise objection", UVM_MEDIUM)
    end
  endtask : pre_body

  task post_body();
    uvm_phase phase;
    `ifdef UVM_VERSION_1_2
      // in UVM1.2, get starting phase from method
      phase = get_starting_phase();
    `else
      phase = starting_phase;
    `endif

    if (phase != null) begin
      phase.drop_objection(this, get_type_name());
      `uvm_info(get_type_name(), "drop objection", UVM_MEDIUM)
    end
  endtask : post_body

endclass

// use in virtual sequence
class uart_config_frame_seq extends uart_base_seq;
  `uvm_object_utils(uart_config_frame_seq)

  rand apb_uart_config cfg; 

  function new(string name="uart_config_frame_seq");
    super.new(name);
  endfunction

  virtual task body();
    if (cfg == null) begin
        `uvm_fatal("UART_CONFIG_FRAME_SEQ", "Config object is NULL! Virtual Sequence must set it.")
    end

    `uvm_info("UART_CONFIG_FRAME_SEQ", "Driving UART Transaction based on Shared Config", UVM_MEDIUM)

    `uvm_do_with(req, {
        data_width  == cfg.data_width;
        parity_en   == cfg.parity_en;
        parity_type == cfg.parity_type;
        stop_bits   == cfg.stop_bits;
    })
  endtask
endclass

class uart_rand_data_trans_seq extends uart_base_seq;
  `uvm_object_utils(uart_rand_data_trans_seq)

  rand uart_data_size_e   cfg_data_width; 
  rand uart_parity_mode_e cfg_parity_en;

  constraint c_default {
      cfg_data_width == DATA_8BIT;
      cfg_parity_en  == PARITY_DIS;
  }

  function new(string name="uart_rand_data_trans_seq");
    super.new(name);
  endfunction

  virtual task body();
    `uvm_info(get_type_name(), "Executing Random UART Transaction Data", UVM_HIGH)
    
    `uvm_do_with(req, {
        data_width  == cfg_data_width;
        parity_en   == cfg_parity_en;
        // data, delay, error được random
    })
  endtask
endclass

class uart_error_inject_seq extends uart_base_seq;
  `uvm_object_utils(uart_error_inject_seq)

  function new(string name="uart_error_inject_seq");
    super.new(name);
  endfunction

  virtual task body();
    `uvm_info(get_type_name(), "Executing Error Injection Sequence (Bad Parity)", UVM_HIGH)

    repeat(10) begin
      `uvm_do_with(req, {
          data_width        == DATA_8BIT;
          parity_en         == PARITY_EN; 
          parity_err_inject == BAD_PARITY; 
          transmit_delay    inside {[1:5]};
      })
    end
  endtask
endclass

class uart_stress_seq extends uart_base_seq;
  `uvm_object_utils(uart_stress_seq)
  
  rand int count;
  constraint c_count { count inside {[20:50]}; }

  function new(string name="uart_stress_seq");
    super.new(name);
  endfunction

  virtual task body();
    `uvm_info(get_type_name(), $sformatf("Starting Stress Test: %0d packets back-to-back", count), UVM_HIGH)
    
    repeat(count) begin
       `uvm_do_with(req, {
           transmit_delay == 0;
       })
    end
  endtask
endclass
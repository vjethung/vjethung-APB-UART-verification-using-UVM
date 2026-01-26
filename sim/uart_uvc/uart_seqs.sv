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
        data_bit_num  == cfg.data_bit_num;
        parity_en   == cfg.parity_en;
        parity_type == cfg.parity_type;
        stop_bit_num   == cfg.stop_bit_num;
        parity_err_inject == cfg.parity_err_target;
    })
  endtask
endclass

// class receive_rx_data_seq extends uart_base_seq;
//   `uvm_object_utils(receive_rx_data_seq)

//   // Mở lại các biến để nhận config từ Virtual Sequence
//   rand uart_data_size_e   cfg_data_width; 
//   rand uart_stop_size_e   cfg_stop_bits;
//   rand uart_parity_mode_e cfg_parity_en;
//   rand uart_parity_type_e cfg_parity_type;

//   function new(string name="receive_rx_data_seq");
//     super.new(name);
//   endfunction

//   virtual task body();
//     `uvm_do_with(req, {
//         data_bit_num  == cfg_data_width;
//         stop_bit_num   == cfg_stop_bits;
//         parity_en   == cfg_parity_en;
//         parity_type == cfg_parity_type;
//     })
//   endtask
// endclass

// class uart_error_inject_seq extends uart_base_seq;
//   `uvm_object_utils(uart_error_inject_seq)

//   function new(string name="uart_error_inject_seq");
//     super.new(name);
//   endfunction

//   virtual task body();
//     `uvm_info(get_type_name(), "Executing Error Injection Sequence (Bad Parity)", UVM_HIGH)

//     repeat(10) begin
//       `uvm_do_with(req, {
//           data_bit_num        == DATA_8BIT;
//           parity_en         == PARITY_EN; 
//           parity_err_inject == BAD_PARITY; 
//           transmit_delay    inside {[1:5]};
//       })
//     end
//   endtask
// endclass

// class uart_stress_seq extends uart_base_seq;
//   `uvm_object_utils(uart_stress_seq)
  
//   rand int count;
//   constraint c_count { count inside {[20:50]}; }

//   function new(string name="uart_stress_seq");
//     super.new(name);
//   endfunction

//   virtual task body();
//     `uvm_info(get_type_name(), $sformatf("Starting Stress Test: %0d packets back-to-back", count), UVM_HIGH)
    
//     repeat(count) begin
//        `uvm_do_with(req, {
//            transmit_delay == 0;
//        })
//     end
//   endtask
// endclass
// hỗ trợ inject lỗi (Error Injection) - Riêng cho Transaction
typedef enum bit {GOOD_PARITY, BAD_PARITY} parity_quality_e;
typedef enum bit {GOOD_STOP, BAD_STOP}     stop_quality_e;

class uart_transaction extends uvm_sequence_item;

  rand bit [7:0] data;
  rand uart_data_size_e   data_width;   
  rand uart_stop_size_e   stop_bits;   
  rand uart_parity_mode_e parity_en;   
  rand uart_parity_type_e parity_type; 

  rand parity_quality_e parity_err_inject; 
  rand stop_quality_e   stop_err_inject;   
  rand int              transmit_delay;    

  // TRẠNG THÁI MONITOR error (Status) 
  bit parity_error_detected;
  bit framing_error_detected;

  `uvm_object_utils_begin(uart_transaction)
      `uvm_field_int(data, UVM_ALL_ON)
      `uvm_field_enum(uart_data_size_e, data_width, UVM_ALL_ON)
      `uvm_field_enum(uart_stop_size_e, stop_bits, UVM_ALL_ON)
      `uvm_field_enum(uart_parity_mode_e, parity_en, UVM_ALL_ON)
      `uvm_field_enum(uart_parity_type_e, parity_type, UVM_ALL_ON)
      
      `uvm_field_enum(parity_quality_e, parity_err_inject, UVM_ALL_ON)
      `uvm_field_enum(stop_quality_e, stop_err_inject, UVM_ALL_ON)
      `uvm_field_int(transmit_delay, UVM_ALL_ON | UVM_DEC | UVM_NOCOMPARE)
  `uvm_object_utils_end

  constraint c_data_mask {
      if (data_width == DATA_5BIT) data[7:5] == 0;
      else if (data_width == DATA_6BIT) data[7:6] == 0;
      else if (data_width == DATA_7BIT) data[7] == 0;
      // DATA_8BIT don't need mask
  }

  constraint c_cfg_dist {
      data_width dist {DATA_8BIT := 70, [DATA_5BIT:DATA_7BIT] := 30};
      parity_en  dist {PARITY_DIS := 50, PARITY_EN := 50};
  }

  constraint c_error_dist {
      parity_err_inject dist {GOOD_PARITY := 90, BAD_PARITY := 10};
      stop_err_inject   dist {GOOD_STOP := 95, BAD_STOP := 5};
  }
  
  constraint c_delay { transmit_delay inside {[0:20]}; }


  function new (string name = "uart_transaction");
    super.new(name);
  endfunction

  function bit calc_parity();
      bit p;
      bit [7:0] masked_data;
      
      case(data_width)
          DATA_5BIT: masked_data = data & 8'h1F; // 0001 1111
          DATA_6BIT: masked_data = data & 8'h3F; // 0011 1111
          DATA_7BIT: masked_data = data & 8'h7F; // 0111 1111
          DATA_8BIT: masked_data = data & 8'hFF; // 1111 1111
      endcase

      p = ^masked_data; 

      if (parity_type == PARITY_EVEN) 
          return p;      
      else 
          return ~p;     
  endfunction

endclass : uart_transaction
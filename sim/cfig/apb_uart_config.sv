`include "uvm_macros.svh"
import uvm_pkg::*;

class apb_uart_config extends uvm_object;
  // Baud rate cố định theo Spec 
  int baud_rate = 115200;

  rand uart_data_size_e   data_bit_num;
  // uart_data_size_e   data_bit_num = DATA_8BIT;
  rand uart_stop_size_e   stop_bit_num;
  // uart_stop_size_e   stop_bit_num = STOP_2BIT;
  rand uart_parity_mode_e parity_en;
  rand uart_parity_type_e parity_type;
  rand uart_mon_mode_e    monitor_mode = MON_BOTH; // Mặc định giám sát cả 2

  rand parity_quality_e   parity_err_target; 
  
  cover_e coverage_control = COV_DISABLE;

  `uvm_object_utils_begin(apb_uart_config)
    `uvm_field_int(baud_rate,                    UVM_ALL_ON | UVM_DEC)
    `uvm_field_enum(uart_mon_mode_e, monitor_mode, UVM_ALL_ON)
    `uvm_field_enum(uart_data_size_e, data_bit_num,  UVM_ALL_ON)
    `uvm_field_enum(uart_stop_size_e, stop_bit_num,   UVM_ALL_ON)
    `uvm_field_enum(uart_parity_mode_e, parity_en, UVM_ALL_ON)
    `uvm_field_enum(uart_parity_type_e, parity_type, UVM_ALL_ON)
    `uvm_field_enum(parity_quality_e, parity_err_target, UVM_ALL_ON)
  `uvm_object_utils_end

  function new(string name = "apb_uart_config");
    super.new(name);
  endfunction

  constraint c_default_valid_frame {
    soft parity_err_target == GOOD_PARITY; 
  }
  
  constraint c_parity_logic {
    if (parity_en == PARITY_EN) {
        parity_type inside {PARITY_ODD, PARITY_EVEN};
    }
  }

endclass
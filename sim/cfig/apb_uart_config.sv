`include "uvm_macros.svh"
import uvm_pkg::*;
class apb_uart_config extends uvm_object;
  `uvm_object_utils(apb_uart_config)

  // Baud rate cố định theo Spec 
  int baud_rate = 115200;

  rand uart_data_size_e   data_width;
  rand uart_stop_size_e   stop_bits;
  rand uart_parity_mode_e parity_en;
  rand uart_parity_type_e parity_type;
  
  cover_e coverage_control = COV_ENABLE;

  function new(string name = "apb_uart_config");
    super.new(name);
  endfunction

  constraint c_default_frame {
      soft data_width   == DATA_8BIT;
      soft stop_bits    == STOP_1BIT;
      soft parity_en    == PARITY_DIS;
      soft parity_type  == PARITY_EVEN; 
  }
endclass
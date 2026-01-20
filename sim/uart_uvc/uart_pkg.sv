package uart_pkg;
  import uvm_pkg::*;
  import uart_common_pkg::*;
  `include "uvm_macros.svh"
  
  typedef uvm_config_db#(virtual interface uart_if) uart_vif_config;
  typedef uvm_config_db#(apb_uart_config) system_config;

  `include "uart_transaction.sv"
  `include "uart_monitor.sv"
  // `include "uart_coverage_monitor.sv"
  `include "uart_seqs.sv"
  `include "uart_sequencer.sv" 
  `include "uart_driver.sv"
  `include "uart_agent.sv"
  `include "uart_uvc.sv"

endpackage
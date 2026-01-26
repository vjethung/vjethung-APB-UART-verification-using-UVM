package apb_pkg;
  import uvm_pkg::*;
  import uart_common_pkg::*;
  `include "uvm_macros.svh"

  typedef uvm_config_db#(virtual interface apb_if) apb_vif_config;
  
  `include "apb_transaction.sv"
  // `include "apb_monitor.sv"
  `include "apb_coverage_monitor.sv"
  `include "apb_seqs.sv"
  `include "apb_sequencer.sv" 
  `include "apb_driver.sv"
  `include "apb_agent.sv"
  `include "apb_uvc.sv"

endpackage : apb_pkg
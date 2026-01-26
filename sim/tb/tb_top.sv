`timescale 1ns/1ps
module tb_top;
  // import the UVM library
  import uvm_pkg::*;
  // include the UVM macros
  `include "uvm_macros.svh"

  import uart_common_pkg::*; 
  import apb_pkg::*;
  import uart_pkg::*;
  import uart_tb_pkg::*;

  initial begin
    // apb_vif_config::set(null, "*.env.apb_uvcc*", "vif", hw_top.aif);
    apb_vif_config::set(null, "*.env.*", "vif", hw_top.aif);
    uart_vif_config::set(null, "*.env.uart_uvcc*", "vif", hw_top.uif);
    run_test("base_test");
  end
endmodule : tb_top
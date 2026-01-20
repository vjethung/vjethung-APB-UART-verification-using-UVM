package uart_tb_pkg;
    import uvm_pkg::*;
    `include "uvm_macros.svh"
    
    import uart_common_pkg::*; 
    import apb_pkg::*;
    import uart_pkg::*;

    `include "uart_virsequencer.sv"
    `include "uart_virseqs.sv"
    // `include "scoreboard.sv"
    `include "apb_uart_env.sv"
    `include "apb_uart_testlib.sv"
endpackage
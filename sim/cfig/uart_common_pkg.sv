package uart_common_pkg;
    import uvm_pkg::*;
    `include "uvm_macros.svh"
    `include "types_param.sv"
    `include "apb_uart_config.sv"
    typedef uvm_config_db#(apb_uart_config) system_config;
endpackage
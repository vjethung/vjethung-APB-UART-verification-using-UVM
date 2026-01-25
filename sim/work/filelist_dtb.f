////////////////////////////////////////////////////////////////////////////////
//  Library Folder
////////////////////////////////////////////////////////////////////////////////

//  Global Defines and Global Params
////////////////////////////////////////////////////////////////////////////////


////////////////////////////////////////////////////////////////////////////////
//  Include Directories
////////////////////////////////////////////////////////////////////////////////
// +incdir+../inc 
//  +incdir+../libs/uvm-1.1d/src

// -y ../../libs

// +incdir+../cfig
// +incdir+../apb_uvc
// +incdir+../uart_uvc
// +incdir+../tb

// -----------------------------------------------------------
// INTERFACES
// Phải compile trước để Top module và UVM Driver có thể sử dụng
// -----------------------------------------------------------
// ../cfig/uart_common_pkg.sv
// ../apb_uvc/apb_if.sv
// ../uart_uvc/uart_if.sv

// -----------------------------------------------------------
// UVM PACKAGES
// Chứa Agent, Driver, Monitor, Sequence Item...
// Thường các file con đã được include trong file _pkg.sv
// -----------------------------------------------------------
// ../apb_uvc/apb_pkg.sv
// ../uart_uvc/uart_pkg.sv

// ../tb/uart_tb_pkg.sv
// -----------------------------------------------------------
// TB COMPONENTS
// Các thành phần môi trường, scoreboard, virtual sequences
// -----------------------------------------------------------
// Lưu ý: Thứ tự compile quan trọng (Sequencer -> Seqs -> Env)
// ../tb/uart_virsequencer.sv
// ../tb/uart_virseqs.sv
// ../tb/scoreboard.sv
// ../tb/apb_uart_env.sv

// -----------------------------------------------------------
// TEST LIBRARY
// Chứa các test case (extends uvm_test)
// -----------------------------------------------------------
// ../tb/apb_uart_testlib.sv

// -----------------------------------------------------------
// Hardware Top 
// -----------------------------------------------------------
// ../tb/hw_top.sv

////////////////////////////////////////////////////////////////////////////////
//  Top Testbench Level Module
////////////////////////////////////////////////////////////////////////////////

// ../tb/uart_core_tb.sv
// ../tb/tb_uart.sv
../tb_direct/tb_uart_tx.sv
// ../tb_direct/tb_uart_rx.sv




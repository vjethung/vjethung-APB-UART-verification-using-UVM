class uart_virsequencer extends uvm_sequencer;
  `uvm_component_utils(uart_virsequencer)

  apb_sequencer apb_sqr;
  uart_sequencer uart_sqr;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction
endclass
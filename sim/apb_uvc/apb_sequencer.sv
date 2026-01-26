class apb_sequencer extends uvm_sequencer #(apb_transaction);

  `uvm_component_utils(apb_sequencer)


  function new (string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void start_of_simulation_phase(uvm_phase phase);
    `uvm_info(get_type_name(), {"start of simulation for ", get_full_name()}, UVM_HIGH)
  endfunction

endclass
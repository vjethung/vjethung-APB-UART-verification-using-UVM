// APB UVC chứa Agents
class apb_uvc extends uvm_env;

  `uvm_component_utils(apb_uvc)

  apb_agent agent;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    agent = apb_agent::type_id::create("agent", this);
  endfunction

  virtual function void start_of_simulation_phase(uvm_phase phase);
    `uvm_info(get_type_name(), {"Start of simulation for ", get_full_name()}, UVM_HIGH)
  endfunction

endclass : apb_uvc
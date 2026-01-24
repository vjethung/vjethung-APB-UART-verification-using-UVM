class apb_agent extends uvm_agent;

    // uvm_active_passive_enum is_active = UVM_ACTIVE; // default

    `uvm_component_utils_begin(apb_agent)
      `uvm_field_enum(uvm_active_passive_enum, is_active, UVM_ALL_ON)
    `uvm_component_utils_end

    apb_driver    driver;
    apb_sequencer sequencer;
    apb_monitor   monitor;

    function new(string name, uvm_component parent);
      super.new(name, parent);
      // Ép trạng thái luôn là ACTIVE để đóng vai trò Master 
      is_active = UVM_ACTIVE;
    endfunction

    virtual function void build_phase(uvm_phase phase);
      super.build_phase(phase);

      monitor = apb_monitor::type_id::create("monitor", this);
      sequencer = apb_sequencer::type_id::create("sequencer", this);
      driver    = apb_driver::type_id::create("driver", this);
    endfunction

    virtual function void connect_phase(uvm_phase phase);
        // Kết nối cổng item_port của driver tới export của sequencer 
        driver.seq_item_port.connect(sequencer.seq_item_export);
    endfunction

    virtual function void start_of_simulation_phase(uvm_phase phase);
      `uvm_info(get_type_name(), {"Start of simulation for ", get_full_name()}, UVM_HIGH)
    endfunction

endclass : apb_agent
class uart_agent extends uvm_agent;
    `uvm_component_utils(uart_agent)
    
    apb_uart_config cfg;
    virtual interface uart_if vif;

    uart_driver    driver;
    uart_sequencer sequencer;
    uart_monitor   monitor; 

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    virtual function void build_phase (uvm_phase phase);
        super.build_phase(phase);

        if (!system_config::get(this, "", "cfg", cfg))
             `uvm_warning("AGENT", "Config not set!")
        
        if (!uart_vif_config::get(this, "", "vif", vif))
             `uvm_warning("AGENT", "VIF not set!")

        monitor = uart_monitor::type_id::create("monitor", this);
        system_config::set(this, "monitor", "cfg", cfg);
        uart_vif_config::set(this, "monitor", "vif", vif);

        if (get_is_active() == UVM_ACTIVE) begin
          sequencer = uart_sequencer::type_id::create("sequencer", this);
          driver    = uart_driver::type_id::create("driver", this);

          driver.cfg = this.cfg;
          driver.vif = this.vif;
          
          system_config::set(this, "driver", "cfg", cfg);
          uart_vif_config::set(this, "driver", "vif", vif);
        end
    endfunction

    virtual function void connect_phase(uvm_phase phase);
        // Kết nối cổng item_port của driver tới export của sequencer 
        if (is_active == UVM_ACTIVE) begin
          driver.seq_item_port.connect(sequencer.seq_item_export);
        end
    endfunction

    virtual function void start_of_simulation_phase(uvm_phase phase);
        `uvm_info(get_type_name(), "start_of_simulation_phase entered.", UVM_HIGH)
    endfunction

endclass
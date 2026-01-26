class uart_agent extends uvm_agent;
    `uvm_component_utils(uart_agent)
    
    apb_uart_config cfg; 

    uart_driver    driver;
    uart_sequencer sequencer;
    // uart_monitor   monitor; 
    uart_coverage_monitor monitor;

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    virtual function void build_phase (uvm_phase phase);
        super.build_phase(phase);

        // Config Object để điều phối trạng thái Active/Passive
        if (!system_config::get(this, "", "cfg", cfg)) begin
             `uvm_fatal("AGENT_CFG", "Config 'cfg' not found! Can not build.")
        end

        if (cfg.monitor_mode == MON_TX_ONLY) begin
            is_active = UVM_PASSIVE;
            `uvm_info(get_type_name(), "Agent set to PASSIVE (TX Only monitoring)", UVM_MEDIUM)
        end else begin
            is_active = UVM_ACTIVE;
        end

        // monitor = uart_monitor::type_id::create("monitor", this);
        monitor = uart_coverage_monitor::type_id::create("monitor", this);
    

        if (get_is_active() == UVM_ACTIVE) begin
          sequencer = uart_sequencer::type_id::create("sequencer", this);
          driver    = uart_driver::type_id::create("driver", this); 

        end
    endfunction

    virtual function void connect_phase(uvm_phase phase);
        if (get_is_active() == UVM_ACTIVE) begin
          driver.seq_item_port.connect(sequencer.seq_item_export);
        end
    endfunction

    virtual function void start_of_simulation_phase(uvm_phase phase);
        `uvm_info(get_type_name(), {"Start of simulation for ", get_full_name()}, UVM_HIGH)
        `uvm_info(get_type_name(), $sformatf("Agent started in %s mode.", is_active.name()), UVM_HIGH)
    endfunction

endclass : uart_agent
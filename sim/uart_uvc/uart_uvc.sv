class uart_uvc extends uvm_env;
    `uvm_component_utils(uart_uvc)

    uart_agent agent; 
    apb_uart_config cfg;
    virtual interface uart_if vif;

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      if (!system_config::get(this, "", "cfg", cfg)) begin
         `uvm_info("UART_UVC", "Config not found, creating default", UVM_LOW)
         cfg = apb_uart_config::type_id::create("cfg");
      end

      if (!uart_vif_config::get(this, "", "vif", vif)) begin
         `uvm_error("UART_UVC", "Virtual Interface not found!")
      end

      agent = uart_agent::type_id::create("agent", this);

      system_config::set(this, "agent", "cfg", cfg);
      uart_vif_config::set(this, "agent", "vif", vif); 
    endfunction
endclass
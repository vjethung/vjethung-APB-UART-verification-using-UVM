class apb_uart_env extends uvm_env;
  `uvm_component_utils(apb_uart_env)

  apb_uvc      apb_uvcc;
  uart_uvc     uart_uvcc;
  // apb_uart_scoreboard scoreboard;
  uart_virsequencer vir_seqr;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    `uvm_info("APB_UART_ENVIRONMENT", "The env is being build phase", UVM_HIGH)

    apb_uvcc    = apb_uvc::type_id::create("apb_uvcc", this);
    uart_uvcc   = uart_uvc::type_id::create("uart_uvcc", this);
    // scoreboard = apb_uart_scoreboard::type_id::create("scoreboard", this);
    vir_seqr      = uart_virsequencer::type_id::create("vir_seqr", this);
  endfunction

  virtual function void connect_phase(uvm_phase phase);
    vir_seqr.apb_sqr  = apb_uvcc.agent.sequencer;
    vir_seqr.uart_sqr = uart_uvcc.agent.sequencer;

    // apb_uvcc.agent.monitor.item_collected_port.connect(scoreboard.apb_in);
    // uart_uvcc.agent.monitor.item_collected_port.connect(scoreboard.uart_out);
  endfunction
endclass
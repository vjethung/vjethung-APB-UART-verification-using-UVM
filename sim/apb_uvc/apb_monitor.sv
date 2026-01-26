class apb_monitor extends uvm_monitor;
    apb_transaction trans;

    // Biến đếm số lượng giao dịch
    int num_trans_col;

    virtual interface apb_if vif;

    // Analysis port để gửi dữ liệu đi (Scoreboard/Coverage)
    uvm_analysis_port #(apb_transaction) item_collected_port;

    `uvm_component_utils_begin(apb_monitor)
      `uvm_field_int(num_trans_col, UVM_ALL_ON)
    `uvm_component_utils_end

    function new (string name, uvm_component parent);
      super.new(name, parent);
      item_collected_port = new("item_collected_port", this);
    endfunction

    virtual function void connect_phase(uvm_phase phase);
      if (!apb_vif_config::get(this, "", "vif", vif)) begin
        `uvm_error("NOVIF", {"Virtual interface must be set for: ", get_full_name(), ".vif"})
      end
    endfunction

    virtual function void start_of_simulation_phase(uvm_phase phase);
      `uvm_info(get_type_name(), {"Start of simulation for ", get_full_name()}, UVM_HIGH)
    endfunction

    virtual task run_phase(uvm_phase phase);
      // biến trung gian để thu thập từ Interface task
      logic [31:0] captured_data;
      logic        is_write;
      @(posedge vif.presetn); 
      forever begin
        trans = apb_transaction::type_id::create("trans", this);

        fork
          vif.collect_apb_transaction(trans.paddr, captured_data, is_write, trans.pstrb, trans.pslverr);
          // Kích hoạt recording dựa trên tín hiệu monitor_start từ interface
          @(negedge vif.penable) void'(begin_tr(trans, "Monitor_APB_Transaction"));
        join

        trans.pwrite = is_write; 

        if (is_write) begin
          trans.pwdata = captured_data; 
          trans.prdata = 32'h0;
          case (trans.paddr)
            12'h000: `uvm_info("MON", $sformatf("Writing TX Data: 0x%h", trans.pwdata[7:0]), UVM_MEDIUM) 
            12'h008: `uvm_info("MON", "Updating UART Configuration", UVM_MEDIUM) 
            12'h00C: `uvm_info("MON", trans.pwdata[0] ? "Start TX Triggered" : "Control Update", UVM_MEDIUM) 
            default: `uvm_error("MON", $sformatf("Write to invalid address: 0x%h", trans.paddr))
          endcase         
        end 
        else begin
          trans.prdata = captured_data; 
          trans.pwdata = 32'h0;         
        end

        end_tr(trans); // Kết thúc ghi lại transaction
        item_collected_port.write(trans); // Gửi tới Scoreboard 
        num_trans_col++;
      end
    endtask

    virtual function void report_phase(uvm_phase phase);
      `uvm_info(get_type_name(), $sformatf("Report: APB Monitor Collected %0d Transactions", num_trans_col), UVM_LOW)
    endfunction : report_phase

endclass
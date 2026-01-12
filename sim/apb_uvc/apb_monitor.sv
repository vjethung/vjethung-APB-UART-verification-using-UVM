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

    // 1. Connect Phase
    virtual function void connect_phase(uvm_phase phase);
      if (!apb_vif_config::get(this, "", "vif", vif)) begin
        `uvm_error("NOVIF", {"Virtual interface must be set for: ", get_full_name(), ".vif"})
      end
    endfunction

    // 2. Start of Simulation Phase
    virtual function void start_of_simulation_phase(uvm_phase phase);
      `uvm_info(get_type_name(), "Monitor started.", UVM_HIGH)
    endfunction

    // 3. Run Phase: Theo dõi reset và lặp lại việc thu thập
    virtual task run_phase(uvm_phase phase);
      @(posedge vif.presetn); 
    
      forever begin
        trans = apb_transaction::type_id::create("trans", this);

        // biến trung gian để thu thập từ Interface task
        logic [31:0] captured_data;
        logic        is_write;

        fork
          vif.collect_apb_transaction(trans.paddr, captured_data, is_write, trans.pstrb, trans.pslverr);
          // Kích hoạt recording dựa trên tín hiệu monitor_start từ interface
          @(posedge vif.monitor_start) void'(begin_tr(trans, "Monitor_APB_Transaction"));
        join

        trans.pwrite = is_write; 

        if (is_write) begin
          trans.pwdata = captured_data; 
          trans.prdata = 32'h0;         
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

    // 4. Report Phase: Tổng kết số lượng đã thu thập được
    virtual function void report_phase(uvm_phase phase);
      `uvm_info(get_type_name(), $sformatf("Report: APB Monitor Collected %0d Transactions", num_trans_col), UVM_LOW)
    endfunction : report_phase

endclass
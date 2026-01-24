class apb_driver extends uvm_driver #(apb_transaction);
    virtual interface apb_if vif;

    // Bộ đếm số giao dịch 
    int num_trans;

    `uvm_component_utils_begin(apb_driver)
      `uvm_field_int(num_trans, UVM_ALL_ON)
    `uvm_component_utils_end

    function new(string name, uvm_component parent);
      super.new(name, parent);
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
      fork
        get_and_drive();
        reset_signals();
      join
    endtask : run_phase

    task get_and_drive();
      // Chờ cho đến khi reset kết thúc (presetn mức cao) 
      @(posedge vif.presetn);
      `uvm_info(get_type_name(), "Reset released, APB Driver active", UVM_LOW)

      forever begin
        // Lấy yêu cầu mới từ sequencer
        seq_item_port.get_next_item(req);

        `uvm_info(get_type_name(), $sformatf("Driving APB Transaction:\n%s", req.sprint()), UVM_HIGH)

        // Thực thi song song: Lái tín hiệu và Ghi lại giao dịch (Transaction Recording)
        fork
          // Thực thi giao thức thông qua interface tasks
          begin
            if (req.pwrite)
              vif.write_task(req.paddr, req.pwdata, req.pstrb);
            else
              vif.read_task(req.paddr, req.prdata);
          end
          // Kích hoạt recording dựa trên tín hiệu drive_start từ interface 
          @(posedge vif.drive_start) void'(begin_tr(req, "Driver_APB_Transaction"));
        join

        // Kết thúc ghi lại giao dịch
        end_tr(req);
        num_trans++;

        // Thông báo cho sequencer đã hoàn thành item này
        seq_item_port.item_done();
      end
    endtask : get_and_drive

    task reset_signals();
      forever begin
        @(negedge vif.presetn);
        vif.psel    <= 1'b0;
        vif.penable <= 1'b0;
        vif.pwrite  <= 1'b0;
        vif.paddr   <= 12'h0;
        `uvm_info(get_type_name(), "Reset detected, signals cleared", UVM_LOW)
        @(posedge vif.presetn);
      end
    endtask : reset_signals

    function void report_phase(uvm_phase phase);
      `uvm_info(get_type_name(), $sformatf("Report: APB Driver sent %0d transactions", num_trans), UVM_LOW)
    endfunction : report_phase

endclass
class apb_coverage_monitor extends uvm_monitor;
    apb_transaction trans;
    virtual interface apb_if vif;

    uvm_analysis_port #(apb_transaction) item_collected_port;
    int num_trans_col;
    cover_e coverage_control = COV_ENABLE;

    `uvm_component_utils_begin(apb_coverage_monitor)
      `uvm_field_int(num_trans_col, UVM_ALL_ON)
      `uvm_field_enum(cover_e, coverage_control, UVM_ALL_ON)
    `uvm_component_utils_end

    // --- ĐỊNH NGHĨA COVERGROUP ---
    covergroup apb_trans_cg;
        option.per_instance = 1;

        // 1. Bao phủ các địa chỉ thanh ghi quan trọng
        cp_paddr: coverpoint trans.paddr {
          bins TX_DATA  = {12'h000};
          bins RX_DATA  = {12'h004};
          bins CFG_REG  = {12'h008};
          bins CTRL_REG = {12'h00C};
          bins STT_REG  = {12'h010};
          bins ILLEGAL  = default;  
        }

        // 2. Bao phủ hướng truyền (Đọc/Ghi)
        cp_pwrite: coverpoint trans.pwrite {
          bins WRITE = {1'b1};
          bins READ  = {1'b0};
        }

        // 3. Bao phủ bit pstrb[0] (tín hiệu ghi byte thấp)
        cp_pstrb_bit0: coverpoint trans.pstrb[0] {
          bins ACTIVE   = {1'b1};
          bins INACTIVE = {1'b0};
        }

        // 4. Kiểm tra lỗi phản hồi từ Slave (PSLVERR)
        cp_pslverr: coverpoint trans.pslverr {
          bins OK    = {1'b0};
          bins ERROR = {1'b1};
        }

        // 5. Cross Coverage: Đảm bảo mọi thanh ghi đều được Đọc và Ghi
        cross_addr_pwrite: cross cp_paddr, cp_pwrite;
        
        // Cross: Địa chỉ, Strobe và hướng Ghi
        cross_addr_strobe0: cross cp_paddr, cp_pstrb_bit0, cp_pwrite {
          ignore_bins read_cases = binsof(cp_pwrite) intersect {1'b0};
        }
    endgroup

    function new (string name, uvm_component parent);
        super.new(name, parent);
        item_collected_port = new("item_collected_port", this);
        if (coverage_control == COV_ENABLE) begin
          apb_trans_cg = new();
          apb_trans_cg.set_inst_name({get_full_name(), ".apb_trans_cg"});
        end
    endfunction

    virtual function void connect_phase(uvm_phase phase);
        if (!apb_vif_config::get(this, get_full_name(), "vif", vif)) begin
          `uvm_error("NOVIF", {"Virtual interface must be set for: ", get_full_name(), ".vif"})
        end
    endfunction

    virtual function void start_of_simulation_phase(uvm_phase phase);
      `uvm_info(get_type_name(), {"Start of simulation for ", get_full_name()}, UVM_HIGH)
    endfunction

    virtual task run_phase(uvm_phase phase);
        logic [31:0] captured_data;
        logic        is_write;
        @(posedge vif.presetn);
        forever begin
          trans = apb_transaction::type_id::create("trans", this);
          // fork
          //   vif.collect_apb_transaction(trans.paddr, captured_data, is_write, trans.pstrb, trans.pslverr);
          //   @(posedge vif.penable) void'(begin_tr(trans, "Monitor_APB_Coverage"));
          //   // @(vif.monitor_start) void'(begin_tr(trans, "Monitor_APB_Transaction"));
          // join
          vif.collect_apb_transaction(trans.paddr, captured_data, is_write, trans.pstrb, trans.pslverr);
          void'(begin_tr(trans, "Monitor_APB_Coverage")); // Gọi sau khi collect xong
          
          trans.pwrite = is_write;
          if (is_write) begin
            trans.pwdata = captured_data;
            trans.prdata = 32'h0;
            case (trans.paddr)
            12'h000: `uvm_info("MON", $sformatf("Writing TX Data: 0x%h", trans.pwdata[7:0]), UVM_MEDIUM) 
            12'h008: `uvm_info("MON", "Updating UART Configuration", UVM_MEDIUM) 
            12'h00C: `uvm_info("MON", trans.pwdata[0] ? "Start TX Triggered" : "Control Update", UVM_MEDIUM) 
            12'h004, 12'h010: begin
              // Ghi nhận hành vi ghi vào thanh ghi RO
              `uvm_warning("MON_RO_WRITE", $sformatf("Illegal Write attempt to RO register at 0x%h", trans.paddr))
            end
            default: `uvm_info("MON_INVALID", $sformatf("Access to unmapped address 0x%h", trans.paddr), UVM_LOW)
          endcase
          end else begin
            trans.prdata = captured_data;
            trans.pwdata = 32'h0;
          end

          if (coverage_control == COV_ENABLE) begin
            apb_trans_cg.sample();
          end

          end_tr(trans);  // Kết thúc ghi lại transaction
          item_collected_port.write(trans); // Gửi tới Scoreboard 
          num_trans_col++;
        end
    endtask

    virtual function void report_phase(uvm_phase phase);
      `uvm_info(get_type_name(), $sformatf("Report: APB Monitor Collected %0d Transactions", num_trans_col), UVM_LOW)
    endfunction : report_phase
endclass
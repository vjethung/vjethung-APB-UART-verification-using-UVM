class apb_coverage_monitor extends uvm_monitor;
    apb_transaction trans;
    virtual interface apb_if vif;

    uvm_analysis_port #(apb_transaction) item_collected_port;
    int num_trans_col;

    // Biến điều khiển việc thu thập coverage
    cover_e coverage_control = COV_ENABLE;

    `uvm_component_utils_begin(apb_coverage_monitor)
      `uvm_field_int(num_trans_col, UVM_ALL_ON)
      `uvm_field_enum(cover_e, coverage_control, UVM_ALL_ON)
    `uvm_component_utils_end

    // --- ĐỊNH NGHĨA COVERGROUP ---
    covergroup apb_trans_cg;
        option.per_instance = 1;
        // = 0. Công cụ chỉ báo cáo tổng cộng độ bao phủ của tất cả các thực thể (instances) của covergroup đó.
        // = 1. Công cụ sẽ theo dõi và hiển thị báo cáo độ bao phủ cho từng thực thể riêng biệt.

        // 1. Kiểm tra bao phủ các địa chỉ thanh ghi quan trọng 
        cp_paddr: coverpoint trans.paddr {
          bins TX_DATA = {12'h000};
          bins RX_DATA = {12'h004};
          bins CFG_REG = {12'h008};
          bins CTRL_REG = {12'h00C};
          bins STT_REG  = {12'h010};
          bins ILLEGAL  = default; 
        }

        // 2. Kiểm tra bao phủ hướng truyền (Đọc/Ghi)
        cp_pwrite: coverpoint trans.pwrite {
          bins WRITE = {1'b1};
          bins READ  = {1'b0};
        }

      // 3. Kiểm tra bao phủ bit pstrb[0] 
        cp_pstrb_bit0: coverpoint trans.pstrb[0] {
          bins ACTIVE   = {1'b1}; 
          bins INACTIVE = {1'b0}; 
        }

        // 4. Kiểm tra lỗi phản hồi từ Slave
        cp_pslverr: coverpoint trans.pslverr {
          bins OK    = {1'b0};
          bins ERROR = {1'b1};
        }

        // 5. Cross Coverage: Đảm bảo mọi thanh ghi đều đã được Đọc và Ghi 
        cross_addr_pwrite: cross cp_paddr, cp_pwrite;

        // Cross: Địa chỉ và Strobe (đặc biệt quan trọng cho TX_DATA và CFG_REG)
        cross_addr_strobe0: cross cp_paddr, cp_pstrb_bit0, cp_pwrite {
          ignore_bins read_cases = binsof(cp_pwrite) intersect {1'b0};
        }
    endgroup

    function new (string name, uvm_component parent);
        super.new(name, parent);
        item_collected_port = new("item_collected_port", this);

        // Khởi tạo covergroup nếu được bật
        if (coverage_control == COV_ENABLE) begin
          apb_trans_cg = new();
          apb_trans_cg.set_inst_name({get_full_name(), ".apb_trans_cg"});
        end
    endfunction

    // 1. Connect Phase
    virtual function void connect_phase(uvm_phase phase);
        if (!apb_vif_config::get(this, get_full_name(), "vif", vif)) begin
          `uvm_error("NOVIF", {"Virtual interface must be set for: ", get_full_name(), ".vif"})
        end
    endfunction

    // 2. Start of Simulation Phase
    virtual function void start_of_simulation_phase(uvm_phase phase);
        `uvm_info(get_type_name(), "Monitor started.", UVM_HIGH)
    endfunction

    // 3. Run Phase: Theo dõi reset và lặp lại việc thu thập
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
            @(posedge vif.monitor_start) void'(begin_tr(trans, "Monitor_APB_Coverage"));
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

          // --- COVERAGE ---
          if (coverage_control == COV_ENABLE) begin
            apb_trans_cg.sample();
          end

          end_tr(trans); // Kết thúc ghi lại transaction
          item_collected_port.write(trans); // Gửi tới Scoreboard 
          num_trans_col++;
        end
    endtask

    virtual function void report_phase(uvm_phase phase);
        `uvm_info(get_type_name(), $sformatf("Report: APB Coverage Monitor Collected %0d Trans", num_trans_col), UVM_LOW) 
    endfunction

endclass
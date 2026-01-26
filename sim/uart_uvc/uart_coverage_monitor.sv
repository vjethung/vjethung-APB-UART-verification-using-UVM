class uart_coverage_monitor extends uvm_monitor;
    `uvm_component_utils(uart_coverage_monitor)

    virtual interface uart_if vif;
    apb_uart_config cfg; 
    uart_transaction trans;
    
    uvm_analysis_port #(uart_transaction) item_collected_port; 
    
    // Biến đếm số lượng giao dịch
    int num_trans_col; 
    cover_e coverage_control = COV_ENABLE; 

    // --- ĐỊNH NGHĨA COVERGROUP UART ---
    covergroup uart_cfg_cg;
        option.per_instance = 1;

        // 1. Độ dài dữ liệu (5, 6, 7, 8 bits) 
        cp_data_size: coverpoint cfg.data_bit_num {
            bins BITS_5 = {DATA_5BIT};
            bins BITS_6 = {DATA_6BIT};
            bins BITS_7 = {DATA_7BIT};
            bins BITS_8 = {DATA_8BIT};
        }

        // 2. Số lượng Stop Bit [cite: 552]
        cp_stop_size: coverpoint cfg.stop_bit_num {
            bins STOP1 = {STOP_1BIT};
            bins STOP2 = {STOP_2BIT};
        }

        // 3. Chế độ Parity [cite: 553]
        cp_parity_en: coverpoint cfg.parity_en {
            bins DISABLED = {PARITY_DIS};
            bins ENABLED  = {PARITY_EN};
        }

        // 4. Loại Parity [cite: 554]
        cp_parity_type: coverpoint cfg.parity_type {
            bins ODD  = {PARITY_ODD};
            bins EVEN = {PARITY_EVEN};
        }

        // 5. Hướng truyền (TX: DUT->UVC, RX: UVC->DUT) 
        cp_direction: coverpoint trans.is_tx {
            bins TX = {1'b1};
            bins RX = {1'b0};
        }

        // 6. Lỗi vật lý
        cp_parity_err: coverpoint trans.parity_error_detected {
            bins NO_ERR = {1'b0};
            bins ERROR  = {1'b1};
        }
        cp_frame_err: coverpoint trans.framing_error_detected {
            bins NO_ERR = {1'b0};
            bins ERROR  = {1'b1};
        }

        // 7. Cross Coverage: Tổ hợp các cấu hình khung truyền
        cross_frame_cfg: cross cp_data_size, cp_stop_size, cp_parity_en, cp_parity_type {
            // Loại bỏ trường hợp parity_type khi parity_en bị vô hiệu hóa
            ignore_bins no_parity = binsof(cp_parity_en) intersect {PARITY_DIS} && 
                                    binsof(cp_parity_type) intersect {PARITY_EVEN};
        }
    endgroup

    function new(string name, uvm_component parent);
        super.new(name, parent);
        item_collected_port = new("item_collected_port", this);
        if (coverage_control == COV_ENABLE) begin
            uart_cfg_cg = new();
            uart_cfg_cg.set_inst_name({get_full_name(), ".uart_cfg_cg"});
        end
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!system_config::get(this, "", "cfg", cfg)) begin
            `uvm_fatal("COV_MON_CFG", "Monitor cannot get config from DB!")
        end
    endfunction

    virtual function void connect_phase(uvm_phase phase);
        if (!uart_vif_config::get(this, "", "vif", vif)) begin 
            `uvm_fatal("NOVIF", $sformatf("Virtual interface must be set for: %s.vif", get_full_name()))
        end
    endfunction

    virtual task run_phase(uvm_phase phase);
        if (cfg != null) vif.set_baud_rate(cfg.baud_rate);
        else vif.set_baud_rate(115200);

        wait(vif.rst_n === 1);
        `uvm_info(get_type_name(), "Coverage Monitor started.", UVM_HIGH)

        fork
            if (cfg.monitor_mode == MON_RX_ONLY || cfg.monitor_mode == MON_BOTH) begin
                collect_and_sample(0); // RX Mode (UVC -> DUT)
            end
            if (cfg.monitor_mode == MON_TX_ONLY || cfg.monitor_mode == MON_BOTH) begin
                collect_and_sample(1); // TX Mode (DUT -> UVC)
            end
        join_none
    endtask

    // Task này mô phỏng lại collect_transfer của uart_monitor để sample coverage
    task automatic collect_and_sample(bit is_tx);
        // uart_transaction trans;
        logic bit_val;
        int num_data_bits;
        logic [7:0] captured_data;
        bit received_parity, calculated_parity;

        string tag = is_tx ? "MON_TX" : "MON_RX";
        string tr_label = is_tx ? "Monitor_DUT_TX_to_UVC" : "Monitor_UVC_to_DUT_RX";

        forever begin
            trans = uart_transaction::type_id::create("trans");
            trans.is_tx = is_tx;
            
            if (is_tx) 
                @(negedge vif.tx); 
            else 
                @(negedge vif.rx);

            vif.sample_bit(bit_val, is_tx); 
            if (bit_val != 1'b0) begin
                `uvm_warning(tag, "Glitch detected on Start Bit")
                continue;
            end

            case(cfg.data_bit_num)
                DATA_5BIT: num_data_bits = 5;
                DATA_6BIT: num_data_bits = 6;
                DATA_7BIT: num_data_bits = 7;
                DATA_8BIT: num_data_bits = 8;
                default:   num_data_bits = 8;
            endcase

            captured_data = 8'h00;
            for (int i = 0; i < num_data_bits; i++) begin
                vif.sample_bit(bit_val, is_tx);
                captured_data[i] = bit_val;
            end
            trans.data = captured_data;
            trans.data_bit_num = cfg.data_bit_num;

            if (cfg.parity_en == PARITY_EN) begin
                vif.sample_bit(received_parity, is_tx);

                trans.parity_type = cfg.parity_type;
                trans.parity_en   = PARITY_EN;
                calculated_parity = trans.calc_parity();

                if (received_parity != calculated_parity && is_tx) begin
                    `uvm_error(tag, $sformatf("Parity Error! Recv: %b, Exp: %b", received_parity, calculated_parity))
                    trans.parity_error_detected = 1;
                end
            end
            
            // Check Stop Bit 1
            vif.sample_bit(bit_val, is_tx);
            
            if (bit_val != 1'b1 && is_tx) begin
                `uvm_error(tag, "Framing Error! Stop bit is 0") 
                trans.framing_error_detected = 1;
            end
            
            if (cfg.stop_bit_num == STOP_2BIT) begin
                vif.sample_bit(bit_val, is_tx);
                if (bit_val != 1'b1 && is_tx) begin
                   `uvm_error(tag, "Framing Error on 2nd Stop bit") 
                   trans.framing_error_detected = 1; 
                end 
            end

            // --- SAMPLE COVERAGE ---
            if (coverage_control == COV_ENABLE && trans != null) begin
                uart_cfg_cg.sample();
            end

            void'(begin_tr(trans, tr_label));
            end_tr(trans);
            item_collected_port.write(trans);
            num_trans_col++;

             if (is_tx)
                `uvm_info(tag, $sformatf("DATA is monitored from TX: 0x%h", trans.data), UVM_MEDIUM)
            else 
                `uvm_info(tag, $sformatf("DATA is monitored from RX: 0x%h", trans.data), UVM_MEDIUM)
        end
    endtask

    virtual function void report_phase(uvm_phase phase);
        `uvm_info(get_type_name(), $sformatf("Report: UART Monitor Collected %0d Transactions", num_trans_col), UVM_LOW)
    endfunction
endclass
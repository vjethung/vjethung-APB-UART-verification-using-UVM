class uart_monitor extends uvm_monitor;
    `uvm_component_utils(uart_monitor)

    // Biến đếm số lượng giao dịch
    int num_trans_col;
    
    virtual interface uart_if vif;
    apb_uart_config cfg;
    
    // Analysis port để gửi dữ liệu đi
    uvm_analysis_port #(uart_transaction) item_collected_port;

    function new(string name, uvm_component parent);
      super.new(name, parent);
      item_collected_port = new("item_collected_port", this);
    endfunction

    virtual function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      if (!system_config::get(this, "", "cfg", cfg)) begin
          `uvm_fatal("MON_CFG", "Monitor cannot get config from DB!")
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
        `uvm_info(get_type_name(), "Monitor started.", UVM_HIGH)

        fork
            if (cfg.monitor_mode == MON_RX_ONLY || cfg.monitor_mode == MON_BOTH) begin
                collect_transfer(0); // RX Mode (UVC -> DUT)
            end
            if (cfg.monitor_mode == MON_TX_ONLY || cfg.monitor_mode == MON_BOTH) begin
                collect_transfer(1); // TX Mode (DUT -> UVC) 
            end
        join_none
    endtask

    task automatic collect_transfer(bit is_tx);
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
                default: num_data_bits = 8;
            endcase

            captured_data = 8'h00;
            for (int i = 0; i < num_data_bits; i++) begin
                vif.sample_bit(bit_val, is_tx); 
                captured_data[i] = bit_val;
            end
            trans.data = captured_data;
            trans.data_bit_num = cfg.data_bit_num;

            // Check Parity
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
            if (bit_val != 1'b1 ) begin
                if (is_tx) begin
                   `uvm_error(tag, "Framing Error! Stop bit is 0") 
                    trans.framing_error_detected = 1;
                end
            end

            // Check Stop Bit 2
            if (cfg.stop_bit_num == STOP_2BIT) begin
                vif.sample_bit(bit_val, is_tx); 
                if (bit_val != 1'b1) begin
                    if (is_tx) begin
                        trans.framing_error_detected = 1;
                        `uvm_error(tag, "Framing Error on 2nd Stop bit")
                    end
                end
            end

            // Record & Write to Port
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
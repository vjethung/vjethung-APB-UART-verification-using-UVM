

class apb_uart_scoreboard extends uvm_scoreboard;
    `uvm_analysis_imp_decl(_apb)
    `uvm_analysis_imp_decl(_uart)
      
    `uvm_component_utils(apb_uart_scoreboard)

    uvm_analysis_imp_apb #(apb_transaction, apb_uart_scoreboard) apb_in;
    uvm_analysis_imp_uart #(uart_transaction, apb_uart_scoreboard) uart_out;

    uart_transaction exp_packet_q[$];

    uart_data_size_e   current_width  = DATA_8BIT;
    uart_parity_mode_e current_par_en = PARITY_DIS;
    uart_parity_type_e current_par_typ= PARITY_EVEN;

    int matches, miscompares, config_updates;

    function new(string name, uvm_component parent);
      super.new(name, parent);
      apb_in   = new("apb_in", this);
      uart_out = new("uart_out", this);
    endfunction

    virtual function void write_apb(apb_transaction tr);
      if (tr.pwrite && (tr.paddr == 12'h008)) begin
        current_width   = uart_data_size_e'(tr.pwdata[1:0]);  
        current_par_en  = uart_parity_mode_e'(tr.pwdata[3]); 
        current_par_typ = uart_parity_type_e'(tr.pwdata[4]); 
        config_updates++;
        `uvm_info("SB_CFG", $sformatf("DUT Config Updated: %s, Parity %s (%s)", 
                  current_width.name(), current_par_en.name(), current_par_typ.name()), UVM_MEDIUM)
      end

      if (tr.pwrite && (tr.paddr == 12'h000)) begin
        uart_transaction exp_tr = uart_transaction::type_id::create("exp_tr");
        exp_tr.data        = tr.pwdata[7:0];
        exp_tr.data_width  = current_width;
        exp_tr.parity_en   = current_par_en;
        exp_tr.parity_type = current_par_typ;

        exp_packet_q.push_back(exp_tr);
        `uvm_info("SB_APB", $sformatf("Expected Packet Queued: Data=0x%h", exp_tr.data), UVM_HIGH)
      end
    endfunction

    virtual function void write_uart(uart_transaction tr);
      uart_transaction exp;
      bit parity_valid;

      if (exp_packet_q.size() == 0) begin
        `uvm_error("SB_UNEXP", "Received UART packet but no APB data expected!")
        return;
      end

      exp = exp_packet_q.pop_front();

      if (tr.data !== exp.data) begin
        `uvm_error("SB_DATA_MIS", $sformatf("Data Mismatch! Exp: 0x%h, Got: 0x%h", exp.data, tr.data))
        miscompares++;
      end 
      else begin
        // 2. Kiểm tra Parity (Quan trọng)
        // Monitor đã tự tính và so sánh Parity vật lý với config 
        // Scoreboard chỉ cần kiểm tra xem Monitor có báo lỗi Parity không
        if (tr.parity_error_detected) begin
          `uvm_error("SB_PAR_ERR", "UART Monitor detected a Parity Error on a valid APB transfer!")
          miscompares++;
        end 
        else begin
          `uvm_info("SB_MATCH", $sformatf("Full Match (Data & Parity): 0x%h", tr.data), UVM_LOW)
          matches++;
        end
      end
    endfunction

    virtual function void report_phase(uvm_phase phase);
      `uvm_info("SB_REPORT", $sformatf("\n--- Scoreboard Report ---\n Config Updates: %0d\n Matches: %0d\n Mismatches: %0d\n-----------------------", config_updates, matches, miscompares), UVM_LOW)
    endfunction
endclass
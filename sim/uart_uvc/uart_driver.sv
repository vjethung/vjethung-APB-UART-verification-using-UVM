class uart_driver extends uvm_driver #(uart_transaction);
  `uvm_component_utils(uart_driver)

  virtual interface uart_if vif;
  apb_uart_config cfg;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!system_config::get(this, "", "cfg", cfg)) begin
      `uvm_warning("NOCFG", "UART Config not found in DB, using default!")
    end
  endfunction

  virtual function void connect_phase(uvm_phase phase);
    if (!uart_vif_config::get(this, "", "vif", vif)) begin
      `uvm_fatal("NOVIF", $sformatf("Virtual interface must be set for: %s.vif", get_full_name()))
    end
  endfunction

  virtual task run_phase(uvm_phase phase);
    if (cfg != null)
        vif.set_baud_rate(cfg.baud_rate);
    else 
        vif.set_baud_rate(115200); 

    vif.init_signals();// rx=1, cts_n=0

    wait(vif.rst_n === 1);
    `uvm_info(get_type_name(), "Reset released. UART Driver started.", UVM_LOW)

    forever begin
      // get transaction from Sequencer
      // Nếu chỉ MON_TX_ONLY, Driver sẽ đứng đợi và không tiêu thụ gói tin từ Sequencer
        if (cfg.monitor_mode == MON_RX_ONLY || cfg.monitor_mode == MON_BOTH) begin
            seq_item_port.get_next_item(req);
            drive_transfer(req); // Thực hiện lái bit vào chân RX 
            seq_item_port.item_done();
        end 
        else begin
            // Nếu ở chế độ MON_TX_ONLY, Driver giữ chân RX ở mức Idle (1) và chờ đợi
            vif.rx <= 1'b1; 
            // vif.rts_n <= 1'b0;
            #1us; // Tránh loop vô hạn làm treo mô phỏng
        end
    end
  endtask

  // send data from uvc to dut
  virtual task drive_transfer(uart_transaction trans);
    int num_data_bits;
    bit parity_bit;
    logic [7:0] payload;

    `uvm_info(get_type_name(), $sformatf("\n#####===Driving Trans: DATA=0x%h,%s, %s, %s, %s===#####", 
                                         trans.data, trans.data_bit_num.name(), 
                                         trans.stop_bit_num.name(),
                                         trans.parity_en.name(),
                                         cfg.parity_type.name()), UVM_HIGH)

    vif.wait_rts_active();

    vif.drive_bit(1'b0);

    case(trans.data_bit_num)
      DATA_5BIT: num_data_bits = 5;
      DATA_6BIT: num_data_bits = 6;
      DATA_7BIT: num_data_bits = 7;
      DATA_8BIT: num_data_bits = 8;
      default:   num_data_bits = 8;
    endcase

    payload = trans.data;
    for (int i = 0; i < num_data_bits; i++) begin
      vif.drive_bit(payload[i]); // Lái từng bit từ LSB -> MSB
    end

    if (trans.parity_en == PARITY_EN) begin
      parity_bit = trans.calc_parity(); 

      // Error Injection
      if (trans.parity_err_inject == BAD_PARITY) begin
         `uvm_info(get_type_name(), "Injecting Parity Error!", UVM_LOW)
         parity_bit = ~parity_bit;
      end

      vif.drive_bit(parity_bit);
    end

    vif.drive_bit(1'b1);

    if (trans.stop_bit_num == STOP_2BIT) begin
       vif.drive_bit(1'b1);
    end

    if (trans.transmit_delay > 0) begin
       vif.wait_bit_periods(trans.transmit_delay);
    end

  endtask

endclass
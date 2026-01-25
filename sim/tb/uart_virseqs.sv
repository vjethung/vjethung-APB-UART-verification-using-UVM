// BASE VIRTUAL SEQUENCE
class base_vseq extends uvm_sequence;
  `uvm_object_utils(base_vseq)
  
  // Các lớp con truy cập: p_sequencer.apb_sqr và p_sequencer.uart_sqr
  `uvm_declare_p_sequencer(uart_virsequencer)

  function new(string name="base_vseq");
    super.new(name);
  endfunction

  task pre_body();
    uvm_phase phase;
    `ifdef UVM_VERSION_1_2
      phase = get_starting_phase();
    `else
      phase = starting_phase;
    `endif
    if (phase != null) begin
      phase.raise_objection(this, get_type_name());
      `uvm_info(get_type_name(), "raise objection", UVM_HIGH)
    end
  endtask : pre_body

  task post_body();
    uvm_phase phase;
    `ifdef UVM_VERSION_1_2
      phase = get_starting_phase();
    `else
      phase = starting_phase;
    `endif
    if (phase != null) begin
      phase.drop_objection(this, get_type_name());
      `uvm_info(get_type_name(), "drop objection", UVM_HIGH)
    end
  endtask : post_body
  task print_frame_cfg(apb_uart_config cfg);
    if (cfg == null) return;
    `uvm_info("VSEQ", $sformatf("\n#####===NUM DATA BIT = %s, NUM STOP BIT = %s, PARITY EN = %s, PARITY TYPE = %s===#####", 
                  cfg.data_width.name(), 
                  cfg.stop_bits.name(), 
                  cfg.parity_en.name(),
                  cfg.parity_type.name()), UVM_LOW)
  endtask
endclass

// SEQUENCE: SYSTEM CONFIGURATION
class system_config_seq extends base_vseq;
    `uvm_object_utils(system_config_seq)

    rand apb_uart_config shared_cfg;
    
    // Khai báo sequence con
    apb_config_frame_seq apb_seq;    
    uart_config_frame_seq uart_seq;  

    function new(string name="system_config_seq");
        super.new(name);
    endfunction

  virtual task body();
    if (!system_config::get(p_sequencer, "", "cfg", shared_cfg)) begin
        `uvm_fatal("VSEQ", "Cannot find 'cfg' in Config DB associated with p_sequencer!")
    end

    `uvm_info("VSEQ", "Configuring System using shared object from Test...", UVM_LOW)

    // Cấu hình APB luôn chạy
    apb_seq = apb_config_frame_seq::type_id::create("apb_seq");
    apb_seq.cfg = shared_cfg; 
    apb_seq.start(p_sequencer.apb_sqr);

    if (shared_cfg.monitor_mode == MON_RX_ONLY || shared_cfg.monitor_mode == MON_BOTH) begin
        `uvm_info("VSEQ", "Activating UART Driver for RX path", UVM_MEDIUM)
        uart_seq = uart_config_frame_seq::type_id::create("uart_seq");
        uart_seq.cfg = shared_cfg; 
        uart_seq.start(p_sequencer.uart_sqr);
    end else begin
        `uvm_info("VSEQ", "UART Driver remains IDLE (TX Only Mode)", UVM_MEDIUM)
    end
  endtask
endclass

// SEQUENCE:  TEST (DUT -> uart_UVC)
class vseq_send_TX extends base_vseq;
    `uvm_object_utils(vseq_send_TX)

    system_config_seq     config_vseq;  
    send_tx_data_seq      apb_write_send_seq; 
    read_status_reg_seq   stt_seq;
    apb_uart_config       shared_cfg;
    apb_config_frame_seq  dis_StartTX_seq;    

    // apb_transaction dis_StartTX_tr;

    function new(string name="vseq_send_TX");
        super.new(name);
    endfunction

    virtual task body();
        bit tx_done = 0;
        int timeout = 0;
        
        int num_data_bits;
        int total_frame_bits;
        real bit_period_ns;

        `uvm_info("VSEQ", "=== STARTING  TEST: DUT -> uart UVC ===", UVM_MEDIUM)

        // Lấy Config từ DB
        if (!system_config::get(null, get_full_name(), "cfg", shared_cfg)) begin
            `uvm_fatal("VSEQ", "Cannot find 'cfg' in Config DB!")
        end

        config_vseq = system_config_seq::type_id::create("config_vseq");
        config_vseq.shared_cfg = shared_cfg;
        `uvm_do(config_vseq) 

        // TÍNH TOÁN DELAY TỰ ĐỘNG
        case(shared_cfg.data_width)
            DATA_5BIT: num_data_bits = 5;
            DATA_6BIT: num_data_bits = 6;
            DATA_7BIT: num_data_bits = 7;
            DATA_8BIT: num_data_bits = 8;
            default:   num_data_bits = 8;
        endcase

        // Tổng số bit trong 1 khung = 1 (Start) + Data + Parity + Stop 
        total_frame_bits = 1 + num_data_bits; 
        if (shared_cfg.parity_en == PARITY_EN) total_frame_bits += 1;
        total_frame_bits += (shared_cfg.stop_bits == STOP_2BIT) ? 2 : 1;

        // Tính thời gian 1 bit (ns) dựa trên Baudrate 
        bit_period_ns = 1000000000.0 / shared_cfg.baud_rate;
        print_frame_cfg(shared_cfg);
        `uvm_info("VSEQ", $sformatf("\n#####===Calculation: Data=%0d bits, Baud=%0d, Tbit=%0.2fns===#####", 
                  total_frame_bits, shared_cfg.baud_rate, bit_period_ns), UVM_LOW)

        // Gửi dữ liệu qua APB
        `uvm_do_on(apb_write_send_seq, p_sequencer.apb_sqr)

        // Chờ đúng khoảng thời gian truyền hết khung vật lý
        repeat(total_frame_bits+1) #(bit_period_ns * 1ns); 

        // dis_StartTX_tr = apb_transaction::type_id::create("dis_StartTX_tr");
        // `uvm_do_on_with(dis_StartTX_tr, p_sequencer.apb_sqr, {
        //     paddr  == 12'h00C; 
        //     pwrite == 1'b1;
        //     pwdata == 32'h0;   
        //     pstrb  == 4'h1;   
        // })
        // `uvm_info("VSEQ", "StartTX bit cleared. DUT is now IDLE.", UVM_MEDIUM)

        #(bit_period_ns * 1ns); 
        // Polling trạng thái
        // #1000;
        stt_seq = read_status_reg_seq::type_id::create("stt_seq"); 
        `uvm_do_on(stt_seq, p_sequencer.apb_sqr)
        if(stt_seq.read_data[0] == 1) begin 
          `uvm_info("VSEQ", "TX_DONE Detected!", UVM_LOW)
        end
        else begin
          `uvm_error("VSEQ", "Timeout waiting for TX_DONE")
        end


        `uvm_info("VSEQ", "===  TEST COMPLETED ===", UVM_MEDIUM)
    endtask
endclass

class vseq_send_N_TX extends base_vseq;
    `uvm_object_utils(vseq_send_N_TX)

    rand int num_frames;
    
    constraint c_num_frames { num_frames inside {[5:10]}; }

    vseq_send_TX single_tx_vseq;

    function new(string name="vseq_send_N_TX");
        super.new(name);
    endfunction

    virtual task body();
        `uvm_info("VSEQ_N", $sformatf("=== STARTING TEST: SEND %0d FRAMES ===", num_frames), UVM_MEDIUM)

        for (int i = 1; i <= num_frames; i++) begin
            `uvm_info("VSEQ_N", $sformatf(
              "\n#####========================Executing FRAME %0d/%0d...========================#####", 
              i, num_frames), UVM_LOW)
            
            `uvm_do(single_tx_vseq)
        end

        `uvm_info("VSEQ_N", "=== SEND N FRAMES COMPLETED ===", UVM_MEDIUM)
    endtask
endclass

// SEQUENCE:  TEST (uart_UVC -> DUT)
class vseq_receive_RX extends base_vseq;
    `uvm_object_utils(vseq_receive_RX)

    system_config_seq    config_vseq;  
    read_rx_data_seq     apb_read_seq;  
    apb_uart_config      shared_cfg;

    function new(string name="vseq_receive_RX");
        super.new(name);
    endfunction

    virtual task body();
        real bit_period_ns;
        int  actual_data_bits; 
        int  total_frame_bits;
        
        bit [7:0] data_mask;
        bit [7:0] masked_sent_data;
        bit [7:0] masked_read_data;

        `uvm_info("VSEQ", "=== STARTING RX TEST (With Data Masking) ===", UVM_MEDIUM)

        if (!system_config::get(p_sequencer, "", "cfg", shared_cfg)) begin
            `uvm_fatal("VSEQ", "Cannot find 'cfg' in Config DB!")
        end
        
        config_vseq = system_config_seq::type_id::create("config_vseq");
        config_vseq.shared_cfg = shared_cfg;
        `uvm_do(config_vseq) 

        bit_period_ns = 1000000000.0 / shared_cfg.baud_rate; 

        // 1. THIẾT LẬP MASK DỰA TRÊN DATA_WIDTH
        case(shared_cfg.data_width) 
            DATA_5BIT: begin actual_data_bits = 5; data_mask = 8'h1F; end // 5'b11111 
            DATA_6BIT: begin actual_data_bits = 6; data_mask = 8'h3F; end // 6'b111111 
            DATA_7BIT: begin actual_data_bits = 7; data_mask = 8'h7F; end // 7'b1111111 
            DATA_8BIT: begin actual_data_bits = 8; data_mask = 8'hFF; end // 8'b11111111 
            default:   begin actual_data_bits = 8; data_mask = 8'hFF; end
        endcase

        total_frame_bits = actual_data_bits; 
        if (shared_cfg.parity_en == PARITY_EN) total_frame_bits += 1; 
        total_frame_bits += (shared_cfg.stop_bits == STOP_2BIT) ? 2 : 1; 
        print_frame_cfg(shared_cfg);
        // CHỜ DỮ LIỆU TRUYỀN XONG
        repeat(total_frame_bits) #(bit_period_ns * 1ns); 

        apb_read_seq = read_rx_data_seq::type_id::create("apb_read_seq");
        `uvm_do_on(apb_read_seq, p_sequencer.apb_sqr) 

        masked_sent_data = config_vseq.uart_seq.req.data & data_mask; 
        masked_read_data = apb_read_seq.rx_data & data_mask;

        if (masked_read_data == masked_sent_data) begin
            `uvm_info("VSEQ_MATCH", $sformatf("SUCCESS! Masked Match: %b (Raw Sent: %b, Read: %b)", 
                      masked_read_data, config_vseq.uart_seq.req.data, apb_read_seq.rx_data), UVM_LOW) 
        end else begin
            `uvm_error("VSEQ_MISMATCH", $sformatf("FAILED! Mask: %b, Masked Sent: %b, Masked Read: %b", 
                       data_mask, masked_sent_data, masked_read_data))
        end
    endtask
endclass

class vseq_receive_N_RX extends base_vseq;
  `uvm_object_utils(vseq_receive_N_RX)

  rand int num_frames;
    
  constraint c_num_frames { num_frames inside {[5:10]}; }

  vseq_receive_RX single_rx_vseq;

    function new(string name="vseq_send_N_TX");
        super.new(name);
    endfunction

    virtual task body();
        `uvm_info("VSEQ_N", $sformatf("=== STARTING TEST: SEND %0d FRAMES ===", num_frames), UVM_MEDIUM)

        for (int i = 1; i <= num_frames; i++) begin
            `uvm_info("VSEQ_N", $sformatf(
              "\n#####========================Executing FRAME %0d/%0d...========================#####",  
              i, num_frames), UVM_LOW)
            
            `uvm_do(single_rx_vseq)
        end

        `uvm_info("VSEQ_N", "=== SEND N FRAMES COMPLETED ===", UVM_MEDIUM)
    endtask
endclass 

// SEQUENCE: ERROR INJECTION TEST
class vseq_parity_error_test extends base_vseq;
    `uvm_object_utils(vseq_parity_error_test)

    apb_uart_config       err_cfg;
    apb_config_frame_seq  apb_cfg;
    uart_config_frame_seq uart_sync;
    uart_error_inject_seq uart_err_seq;
    read_status_reg_seq   stt_seq;

    function new(string name="vseq_parity_error_test");
        super.new(name);
    endfunction

    virtual task body();
        `uvm_info("VSEQ", "=== STARTING PARITY ERROR INJECTION TEST ===", UVM_MEDIUM)

        // 1. Tạo Config BẮT BUỘC có Parity
        err_cfg = apb_uart_config::type_id::create("err_cfg");
        if(!err_cfg.randomize() with {
            parity_en == PARITY_EN; 
            data_width == DATA_8BIT;
        }) `uvm_fatal("VSEQ", "Config Randomization Failed")

        // 2. Setup DUT (Trên APB Sequencer)
        `uvm_do_on_with(apb_cfg, p_sequencer.apb_sqr, { 
            cfg == err_cfg; 
        })

        // 3. Setup UART UVC (Trên UART Sequencer)
        `uvm_do_on_with(uart_sync, p_sequencer.uart_sqr, { 
            cfg == err_cfg; 
        })

        // 4. Tiêm lỗi từ UART (Trên UART Sequencer)
        `uvm_info("VSEQ", "Injecting Bad Parity Packets...", UVM_LOW)
        `uvm_do_on(uart_err_seq, p_sequencer.uart_sqr)

        // 5. Kiểm tra thanh ghi trạng thái (Trên APB Sequencer)
        `uvm_do_on(stt_seq, p_sequencer.apb_sqr)
        `uvm_info("VSEQ", $sformatf("Status Register Readback: 0x%h", stt_seq.req.prdata), UVM_LOW)

        `uvm_info("VSEQ", "=== ERROR INJECTION TEST COMPLETED ===", UVM_MEDIUM)
    endtask
endclass
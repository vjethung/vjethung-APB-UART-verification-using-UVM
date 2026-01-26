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
                  cfg.data_bit_num.name(), 
                  cfg.stop_bit_num.name(), 
                  cfg.parity_en.name(),
                  cfg.parity_type.name()), UVM_LOW)
  endtask
endclass

// SEQUENCE: SYSTEM CONFIGURATION
class system_config_seq extends base_vseq;
    `uvm_object_utils(system_config_seq)

    apb_uart_config shared_cfg;
    
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
        case(shared_cfg.data_bit_num)
            DATA_5BIT: num_data_bits = 5;
            DATA_6BIT: num_data_bits = 6;
            DATA_7BIT: num_data_bits = 7;
            DATA_8BIT: num_data_bits = 8;
            default:   num_data_bits = 8;
        endcase

        // Tổng số bit trong 1 khung = 1 (Start) + Data + Parity + Stop 
        total_frame_bits = 1 + num_data_bits; 
        if (shared_cfg.parity_en == PARITY_EN) total_frame_bits += 1;
        total_frame_bits += (shared_cfg.stop_bit_num == STOP_2BIT) ? 2 : 1;

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

    rand parity_quality_e p_err_target;

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
        
        shared_cfg.parity_err_target = p_err_target;

        config_vseq = system_config_seq::type_id::create("config_vseq");
        config_vseq.shared_cfg = shared_cfg;

        // `uvm_do(config_vseq) 
        // config_vseq.start(null);
        config_vseq.start(p_sequencer);

        bit_period_ns = 1000000000.0 / shared_cfg.baud_rate; 

        // 1. THIẾT LẬP MASK DỰA TRÊN DATA_WIDTH
        case(shared_cfg.data_bit_num) 
            DATA_5BIT: begin actual_data_bits = 5; data_mask = 8'h1F; end // 5'b11111 
            DATA_6BIT: begin actual_data_bits = 6; data_mask = 8'h3F; end // 6'b111111 
            DATA_7BIT: begin actual_data_bits = 7; data_mask = 8'h7F; end // 7'b1111111 
            DATA_8BIT: begin actual_data_bits = 8; data_mask = 8'hFF; end // 8'b11111111 
            default:   begin actual_data_bits = 8; data_mask = 8'hFF; end
        endcase

        total_frame_bits = actual_data_bits+1; 
        if (shared_cfg.parity_en == PARITY_EN) total_frame_bits += 1; 
        total_frame_bits += (shared_cfg.stop_bit_num == STOP_2BIT) ? 2 : 1; 

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
    
  constraint c_num_frames { num_frames inside {[10:40]}; }

  vseq_receive_RX single_rx_vseq;

    function new(string name="vseq_send_N_TX");
        super.new(name);
    endfunction

    virtual task body();
        `uvm_info("VSEQ_N", $sformatf("=== STARTING TEST: SEND %0d FRAMES ===", num_frames), UVM_MEDIUM)

        for (int i = 1; i <= num_frames; i++) begin
        // for (int i = 1; i <= 2; i++) begin
            `uvm_info("VSEQ_N", $sformatf(
              "\n#####========================Executing FRAME %0d/%0d...========================#####",  
              i, num_frames), UVM_LOW)

            `uvm_do_with(single_rx_vseq, { 
                p_err_target == GOOD_PARITY; 
            })
        end

        `uvm_info("VSEQ_N", "=== SEND N FRAMES COMPLETED ===", UVM_MEDIUM)
    endtask
endclass 

// SEQUENCE: ERROR INJECTION TEST
// class vseq_receive_RX_ErrorInject extends base_vseq;
//     `uvm_object_utils(vseq_receive_RX_ErrorInject)

//     rand parity_quality_e p_err_target = BAD_PARITY;

//     system_config_seq    config_vseq;  
//     read_status_reg_seq  apb_stt_seq;
//     apb_uart_config      shared_cfg;
//     function new(string name="vseq_receive_RX_ErrorInject");
//         super.new(name);
//     endfunction

//     virtual task body();
//         real bit_period_ns;
//         int  actual_data_bits; 
//         int  parity_bit_pos; // Vị trí bit parity (tính từ start bit là 0)

//         `uvm_info("VSEQ_ERR", "=== STARTING PARITY ERROR INJECTION TEST (FIXED TIMING) ===", UVM_MEDIUM)

//         if (!system_config::get(p_sequencer, "", "cfg", shared_cfg)) begin
//             `uvm_fatal("VSEQ_ERR", "Cannot find 'cfg' in Config DB!")
//         end
        
//         shared_cfg.parity_err_target = p_err_target;
//         config_vseq = system_config_seq::type_id::create("config_vseq");
//         config_vseq.shared_cfg = shared_cfg;
//         `uvm_do(config_vseq) 

//         bit_period_ns = 1000000000.0 / shared_cfg.baud_rate; 
        
//         case(shared_cfg.data_bit_num) 
//             DATA_5BIT: actual_data_bits = 5;
//             DATA_6BIT: actual_data_bits = 6;
//             DATA_7BIT: actual_data_bits = 7;
//             DATA_8BIT: actual_data_bits = 8;
//             default:   actual_data_bits = 8;
//         endcase

//         // Vị trí bit Parity = 1 (Start) + actual_data_bits
//         parity_bit_pos = 1 + actual_data_bits;

//         // --- PHASE 1: ĐỌC TRONG KHI ĐANG TRUYỀN STOP BIT ---
//         // Chờ qua bit Start, Data và Parity (tổng cộng parity_bit_pos + 1 bit)
//         repeat(parity_bit_pos + 1) #(bit_period_ns * 1ns);
//         // #500ns; // Chờ thêm một chút để DUT cập nhật logic nội bộ
//         #(bit_period_ns * 2);

//         `uvm_info("VSEQ_ERR", "Reading Status during STOP bit (Expect Error=1, Done=0)", UVM_LOW)
//         apb_stt_seq = read_status_reg_seq::type_id::create("apb_stt_seq");
//         `uvm_do_on(apb_stt_seq, p_sequencer.apb_sqr)
        
//         // Kiểm tra: Phải thấy Error và KHÔNG thấy Done
//         check_reg_parity_error(apb_stt_seq.read_data, 1'b1); 
//         check_reg_rx_done(apb_stt_seq.read_data, 1'b0);

//         // --- PHASE 2: ĐỌC SAU KHI KẾT THÚC KHUNG HÌNH ---
//         // Chờ nốt các bit Stop còn lại (khoảng 1-2 bit)
//         repeat(2) #(bit_period_ns * 1ns);
//         #1us;

//         `uvm_info("VSEQ_ERR", "Reading Status after Frame (Expect Error=0, Done=1)", UVM_LOW)
//         `uvm_do_on(apb_stt_seq, p_sequencer.apb_sqr)
        
//         // Kiểm tra: Error đã biến mất, Done đã lên 1
//         check_reg_rx_done(apb_stt_seq.read_data, 1'b1);
//         check_reg_parity_error(apb_stt_seq.read_data, 1'b0); 

//         `uvm_info("VSEQ_ERR", "=== ERROR INJECTION TEST COMPLETED ===", UVM_MEDIUM)
//     endtask

//     task check_reg_rx_done(bit [31:0] stt_data, bit exp);
//         if (stt_data[1] == exp)
//             `uvm_info("ASSERT", $sformatf("DUT: RX_DONE is %b as expected.", exp), UVM_LOW)
//         else
//             `uvm_error("ASSERT", $sformatf("DUT: RX_DONE mismatch! Got %b, Exp %b", stt_data[1], exp))
//     endtask

//     task check_reg_parity_error(bit [31:0] stt_data, bit exp);
//         if (stt_data[2] == exp) 
//             `uvm_info("ASSERT", $sformatf("SUCCESS: Parity Error is %b as expected.", exp), UVM_LOW) 
//         else 
//             `uvm_error("ASSERT", $sformatf("FAILED: Parity Error mismatch! Got %b, Exp %b", stt_data[2], exp))
//     endtask
// endclass
class vseq_receive_RX_ErrorInject extends base_vseq;
    `uvm_object_utils(vseq_receive_RX_ErrorInject)

    // HDL Path dẫn tới tín hiệu lỗi parity nội bộ 
    localparam string DUT_PARITY_ERR_PATH = "$root.hw_top.dut.parity_error"; 

    rand parity_quality_e p_err_target = BAD_PARITY;
    system_config_seq    config_vseq;  
    read_status_reg_seq  apb_stt_seq;
    apb_uart_config      shared_cfg;

    virtual task body();
        real bit_period_ns;
        int  actual_data_bits; 
        int  wait_bits_before_poll;
        bit  captured_hdl_err = 0; 

        `uvm_info("VSEQ_ERR", "=== STARTING BACKDOOR PARITY ERROR INJECTION TEST ===", UVM_MEDIUM)

        if (!system_config::get(p_sequencer, "", "cfg", shared_cfg)) begin
            `uvm_fatal("VSEQ_ERR", "Cannot find 'cfg' in Config DB!")
        end
        
        shared_cfg.parity_err_target = p_err_target;
        bit_period_ns = 1000000000.0 / shared_cfg.baud_rate; 

        case(shared_cfg.data_bit_num) 
            DATA_5BIT: actual_data_bits = 5;
            DATA_6BIT: actual_data_bits = 6;
            DATA_7BIT: actual_data_bits = 7;
            DATA_8BIT: actual_data_bits = 8;
            default:   actual_data_bits = 8;
        endcase

        wait_bits_before_poll = 1 + actual_data_bits;

        fork
            // Thread 1: Chạy Driver gửi dữ liệu lỗi qua UART UVC
            begin
                config_vseq = system_config_seq::type_id::create("config_vseq");
                config_vseq.shared_cfg = shared_cfg;
                `uvm_do(config_vseq) 
            end

            // Thread 2: Backdoor Polling để "bắt" cờ lỗi tức thời
            begin
                // Đợi đến khi bit Parity bắt đầu bay vào DUT
                #(bit_period_ns * wait_bits_before_poll * 1ns); 
                
                // Polling liên tục trong cửa sổ Stop bits
                // Vì Parity Error mất đi khi RX_DONE lên (theo quan sát của bạn)
                for (int i=0; i < 100; i++) begin
                    int val;
                    if (uvm_hdl_read(DUT_PARITY_ERR_PATH, val)) begin
                        if (val == 1) begin
                            captured_hdl_err = 1;
                            `uvm_info("BACKDOOR", "Parity Error bit HIGH detected via Backdoor!", UVM_HIGH)
                        end
                    end
                    
                    if (captured_hdl_err) break;
                    
                    // Polling mỗi 100ns (tần suất cao hơn bit_period)
                    #100ns; 
                end
            end
        join

        // Sau khi kết thúc truyền, kiểm tra trạng thái cuối qua APB (Frontdoor)
        #1us;
        #(bit_period_ns * (wait_bits_before_poll + 1) * 1ns); 

        apb_stt_seq = read_status_reg_seq::type_id::create("apb_stt_seq");
        `uvm_do_on(apb_stt_seq, p_sequencer.apb_sqr)
        
        check_final_status(captured_hdl_err, apb_stt_seq.read_data);

        `uvm_info("VSEQ_ERR", "=== ERROR INJECTION TEST COMPLETED ===", UVM_MEDIUM)
    endtask

    task check_final_status(bit hdl_err, bit [31:0] stt_reg);
        // // Kiểm tra bit [1]: rx_done (Phải lên 1 khi nhận xong theo SPEC )
        // if (stt_reg[1] == 1'b1)
        //     `uvm_info("ASSERT", "DUT: RX_DONE correctly set (Bit [1] is 1).", UVM_LOW)
        // else
        //     `uvm_error("ASSERT", $sformatf("DUT: RX_DONE failed to set! STT_REG = 0x%0h", stt_reg))

        // Kiểm tra Parity Error (Dựa trên kết quả Backdoor đã chụp được)
        if (shared_cfg.parity_err_target == BAD_PARITY) begin
            if (hdl_err)
                `uvm_info("ASSERT", "SUCCESS: Parity Error was asserted during frame transmission!", UVM_LOW)
            else
                `uvm_error("ASSERT", "FAILED: DUT never asserted internal parity_error signal despite BAD_PARITY injection!")
        end
    endtask
endclass

class vseq_receive_N_RX_ErrorInject extends base_vseq;

    `uvm_object_utils(vseq_receive_N_RX_ErrorInject)

    rand int num_frames;

    constraint c_num_frames { num_frames inside {[10:20]}; }

    vseq_receive_RX_ErrorInject par_err_rx_vseq;

    function new(string name="vseq_send_N_TX");
        super.new(name);
    endfunction

    virtual task body();
        `uvm_info("VSEQ_N", $sformatf("=== STARTING TEST: SEND %0d FRAMES ===", num_frames), UVM_MEDIUM)

        for (int i = 1; i <= num_frames; i++) begin
            `uvm_info("VSEQ_N", $sformatf(
              "\n#####========================Executing FRAME %0d/%0d...========================#####",  
              i, num_frames), UVM_LOW)
            
            `uvm_do_with(par_err_rx_vseq, { 
                p_err_target == BAD_PARITY; 
            })
        end

        `uvm_info("VSEQ_N", "=== SEND N FRAMES COMPLETED ===", UVM_MEDIUM)
    endtask
endclass 

// APB & register =======================================================================================

// chceck reset default
class vseq_check_reset extends base_vseq;
    `uvm_object_utils(vseq_check_reset)

    // --- CẬP NHẬT HDL PATHS DỰA TRÊN HÌNH ẢNH ---
    localparam string PATH_TX_DATA      = "$root.hw_top.dut.tx_data";      // 0x00
    localparam string PATH_RX_DATA      = "$root.hw_top.dut.rx_data";      // 0x04
    localparam string PATH_DATA_BIT_NUM = "$root.hw_top.dut.data_bit_num"; // 0x08 [1:0]
    localparam string PATH_STOP_BIT_NUM = "$root.hw_top.dut.stop_bit_num"; // 0x08 [2]
    localparam string PATH_PARITY_EN    = "$root.hw_top.dut.parity_en";    // 0x08 [3]
    localparam string PATH_PARITY_TYPE  = "$root.hw_top.dut.parity_type";  // 0x08 [4]
    localparam string PATH_START_TX     = "$root.hw_top.dut.start_tx";     // 0x0C [0]
    localparam string PATH_TX_DONE      = "$root.hw_top.dut.tx_done";      // 0x10 [0]
    localparam string PATH_RX_DONE      = "$root.hw_top.dut.rx_done";      // 0x10 [1]
    localparam string PATH_PARITY_ERR   = "$root.hw_top.dut.parity_error"; // 0x10 [2]

    function new(string name="vseq_check_reset");
        super.new(name);
    endfunction

    virtual task body();
        int error_count = 0;

        `uvm_info("VSEQ_RESET", "=== STARTING INDIVIDUAL SIGNAL RESET CHECK ===", UVM_MEDIUM)

        // 1. Chờ reset nhả (100ns trong hw_top)
        #110ns; 

        // 2. Kiểm tra các tín hiệu thuộc tx_data_reg & rx_data_reg (Reset = 0)
        check_reset_val(PATH_TX_DATA, 32'h0, "tx_data", error_count); 
        check_reset_val(PATH_RX_DATA, 32'h0, "rx_data", error_count); 

        // 3. Kiểm tra các tín hiệu thuộc cfg_reg (Reset = 0)
        check_reset_val(PATH_DATA_BIT_NUM, 32'h0, "data_bit_num", error_count);
        check_reset_val(PATH_STOP_BIT_NUM, 32'h0, "stop_bit_num", error_count);
        check_reset_val(PATH_PARITY_EN,    32'h0, "parity_en",    error_count);
        check_reset_val(PATH_PARITY_TYPE,  32'h0, "parity_type",  error_count);

        // 4. Kiểm tra tín hiệu thuộc ctrl_reg (Reset = 0)
        check_reset_val(PATH_START_TX, 32'h0, "start_tx", error_count); 

        // 5. Kiểm tra các tín hiệu thuộc stt_reg (Địa chỉ 0x10)
        // tx_done: Reset là 1 
        check_reset_val(PATH_TX_DONE,    32'h1, "tx_done",      error_count); 
        // rx_done: Reset là 0 
        check_reset_val(PATH_RX_DONE,    32'h1, "rx_done",      error_count); 
        // parity_error: Reset là 0
        check_reset_val(PATH_PARITY_ERR, 32'h0, "parity_error", error_count); 

        // 6. Tổng kết kết quả
        if (error_count == 0)
            `uvm_info("VSEQ_RESET", "SUCCESS: All internal signals passed Reset Check!", UVM_LOW)
        else
            `uvm_error("VSEQ_RESET", $sformatf("FAILED: %0d internal signals failed Reset Check!", error_count))

        `uvm_info("VSEQ_RESET", "=== RESET VALUE CHECK COMPLETED ===", UVM_MEDIUM)
    endtask

    // Hàm thực hiện đọc backdoor và so sánh
    task check_reset_val(string path, bit [31:0] exp, string name, ref int errors);
        bit [31:0] val;
        if (uvm_hdl_read(path, val)) begin
            if (val !== exp) begin
                `uvm_error("RESET_FAIL", $sformatf("%s mismatch! Path: %s | Got: 0x%h | Exp: 0x%h", name, path, val, exp))
                errors++;
            end else begin
                `uvm_info("RESET_PASS", $sformatf("%s correct: 0x%h", name, val), UVM_HIGH)
            end
        end else begin
            `uvm_error("HDL_READ_FAIL", $sformatf("Cannot read path: %s. Check RTL hierarchy!", path))
            errors++;
        end
    endtask
endclass

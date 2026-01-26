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
      #10us;
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

    repeat(10) #20;

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
        // #10;
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
    
    constraint c_num_frames { num_frames inside {[50:60]}; }

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

        // total_frame_bits = actual_data_bits;
        // total_frame_bits = actual_data_bits - 5;
        total_frame_bits = actual_data_bits - 2; 
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

    rand parity_quality_e   p_err_target = BAD_PARITY;
    system_config_seq       config_vseq;  
    read_status_reg_seq     apb_stt_seq;
    read_rx_data_seq        apb_data_seq;
    apb_uart_config         shared_cfg;

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

        `uvm_info("VSEQ_ERR", "Reading RX Data Register (0x04) to trigger Scoreboard", UVM_LOW)
        apb_data_seq = read_rx_data_seq::type_id::create("apb_data_seq");
        `uvm_do_on(apb_data_seq, p_sequencer.apb_sqr)
        
        check_final_status(captured_hdl_err, apb_stt_seq.read_data);

        `uvm_info("VSEQ_ERR", "=== ERROR INJECTION TEST COMPLETED ===", UVM_MEDIUM)
    endtask

    task check_final_status(bit hdl_err, bit [31:0] stt_reg);
        // // Kiểm tra bit [1]: rx_done (Phải lên 1 khi nhận xong theo SPEC )
        if (stt_reg[1] == 1'b1)
            `uvm_info("ASSERT", "DUT: RX_DONE correctly set (Bit [1] is 1).", UVM_LOW)
        else
            `uvm_error("ASSERT", $sformatf("DUT: RX_DONE failed to set! STT_REG = 0x%0h", stt_reg))

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

    constraint c_num_frames { num_frames inside {[50:60]}; }

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
// APB & register =======================================================================================
// APB & register =======================================================================================
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

class vseq_cfg_wr_rd_check extends base_vseq;
  `uvm_object_utils(vseq_cfg_wr_rd_check)

  apb_uart_config          shared_cfg;
  apb_config_frame_seq     wr_cfg_seq;   // đã có trong apb_seqs.sv
  apb_read_reg_seq         rd_cfg_seq;   // cái mới bạn vừa thêm

  function new(string name="vseq_cfg_wr_rd_check");
    super.new(name);
  endfunction

  virtual task body();
    logic [31:0] exp_wdata;
    logic [31:0] got_rdata;

    `uvm_info("VSEQ_CFG", "=== START vseq_cfg_wr_rd_check ===", UVM_MEDIUM)

    // Lấy cfg từ config_db giống style bạn đang dùng
    if (!system_config::get(null, get_full_name(), "cfg", shared_cfg)) begin
      `uvm_fatal("VSEQ_CFG", "Cannot find 'cfg' in Config DB!")
    end

    exp_wdata = 32'h0;
    exp_wdata[1:0] = shared_cfg.data_bit_num;
    exp_wdata[2]   = shared_cfg.stop_bit_num;
    exp_wdata[3]   = shared_cfg.parity_en;
    exp_wdata[4]   = shared_cfg.parity_type;

    print_frame_cfg(shared_cfg);

    wr_cfg_seq = apb_config_frame_seq::type_id::create("wr_cfg_seq");
    wr_cfg_seq.cfg = shared_cfg;
    wr_cfg_seq.start(p_sequencer.apb_sqr);


    rd_cfg_seq = apb_read_reg_seq::type_id::create("rd_cfg_seq");
    rd_cfg_seq.addr = 12'h008;
    rd_cfg_seq.start(p_sequencer.apb_sqr);
    got_rdata = rd_cfg_seq.rdata;

    if (got_rdata[4:0] !== exp_wdata[4:0]) begin
      `uvm_error("VSEQ_CFG", $sformatf(
        "CFG_REG mismatch @0x008. EXP[4:0]=0x%0h GOT[4:0]=0x%0h (EXP full=0x%08h GOT full=0x%08h)",
        exp_wdata[4:0], got_rdata[4:0], exp_wdata, got_rdata
      ))
    end
    else begin
      `uvm_info("VSEQ_CFG", $sformatf(
        "CFG_REG OK @0x008. value[4:0]=0x%0h (full=0x%08h)",
        got_rdata[4:0], got_rdata
      ), UVM_MEDIUM)
    end

    `uvm_info("VSEQ_CFG", "=== DONE vseq_cfg_wr_rd_check ===", UVM_MEDIUM)
  endtask
endclass

class vseq_rxdata_write_ignored extends base_vseq;
  `uvm_object_utils(vseq_rxdata_write_ignored)

  apb_transaction tr; 

  function new(string name="vseq_rxdata_write_ignored");
    super.new(name);
  endfunction

  virtual task body();
    // Danh sách các địa chỉ cần test: 0x04 (RO), 0x10 (RO), 0x20 (Unmapped)
    logic [11:0] test_addrs[] = '{12'h004, 12'h010, 12'h020};
    logic [31:0] original_val, read_back_val;

    `uvm_info("VSEQ_RO", "=== STARTING SYSTEMATIC RO & UNMAPPED WRITE TEST ===", UVM_LOW)

    foreach (test_addrs[i]) begin
      logic [11:0] addr = test_addrs[i];
      
      // Đọc giá trị ban đầu
      `uvm_do_on_with(tr, p_sequencer.apb_sqr, {
          paddr == addr; 
          pwrite == 1'b0; 

          if (addr == 12'h004 || addr == 12'h010) addr_type == ADDR_RO;
          else if (addr == 12'h020) addr_type == ADDR_INVALID;
          else addr_type == ADDR_VALID;
          
          write_true_flase == (addr <= 12'h010) ? WRITE_ADDR_TRUE : WRITE_ADDR_FALSE;
      })
      original_val = tr.prdata;

      // Cố gắng ghi đè dữ liệu 
      `uvm_do_on_with(tr, p_sequencer.apb_sqr, {
          paddr == addr; 
          pwrite == 1'b1; 
          pwdata == 32'hDEAD_BEEF;
          if (addr == 12'h004 || addr == 12'h010) addr_type == ADDR_RO;
          else if (addr == 12'h020) addr_type == ADDR_INVALID;
          else addr_type == ADDR_VALID;
          
          write_true_flase == (addr <= 12'h010) ? WRITE_ADDR_TRUE : WRITE_ADDR_FALSE;
      })
      
    //   // Kiểm tra phản hồi lỗi pslverr cho địa chỉ Unmapped (0x20) 
    //   if (addr == 12'h020 && tr.pslverr == 1'b0) begin
    //       `uvm_error("VSEQ_RO", $sformatf("Unmapped addr 0x%0h failed to assert PSLVERR!", addr))
    //   end

      // Đọc lại để xác nhận giá trị không đổi
      `uvm_do_on_with(tr, p_sequencer.apb_sqr, {
          paddr == addr; 
          pwrite == 1'b0;
          if (addr == 12'h004 || addr == 12'h010) addr_type == ADDR_RO;
          else if (addr == 12'h020) addr_type == ADDR_INVALID;
          else addr_type == ADDR_VALID;
          
          write_true_flase == (addr <= 12'h010) ? WRITE_ADDR_TRUE : WRITE_ADDR_FALSE;
      })
      read_back_val = tr.prdata; 

      // So sánh kết quả 
      if (read_back_val[7:0] !== original_val[7:0]) begin
        `uvm_error("VSEQ_RO", $sformatf("ADDR 0x%0h: BUG! Write NOT ignored. Old=0x%h, New=0x%h", 
                   addr, original_val, read_back_val))
      end else begin
        `uvm_info("VSEQ_RO", $sformatf("ADDR 0x%0h: SUCCESS. Write ignored. Val=0x%h", 
                   addr, read_back_val), UVM_MEDIUM)
      end
    end
  endtask
endclass

class vseq_txdata_no_side_effect extends base_vseq;
  `uvm_object_utils(vseq_txdata_no_side_effect)

  apb_read_reg_seq  rd;
  apb_write_reg_seq wr;

  function new(string name="vseq_txdata_no_side_effect");
    super.new(name);
  endfunction

  virtual task body();
    logic [31:0] rx_before, cfg_before;
    logic [31:0] rx_after,  cfg_after;

    `uvm_info("VSEQ_SIDEFX", "=== START: write 0x0, check 0x4/0x8 unchanged ===", UVM_MEDIUM)

    // 1) Read RX_DATA (0x4) before
    rd = apb_read_reg_seq::type_id::create("rd_rx_before");
    rd.addr = 12'h004;
    rd.start(p_sequencer.apb_sqr);
    rx_before = rd.rdata;

    // 2) Read CFG (0x8) before
    rd = apb_read_reg_seq::type_id::create("rd_cfg_before");
    rd.addr = 12'h008;
    rd.start(p_sequencer.apb_sqr);
    cfg_before = rd.rdata;

    // 3) Write TX_DATA (0x0)
    wr = apb_write_reg_seq::type_id::create("wr_txdata");
    wr.addr  = 12'h000;
    wr.wdata = 32'h0000_00A5; // bạn muốn random cũng được
    wr.start(p_sequencer.apb_sqr);

    // 4) Read RX_DATA (0x4) after
    rd = apb_read_reg_seq::type_id::create("rd_rx_after");
    rd.addr = 12'h004;
    rd.start(p_sequencer.apb_sqr);
    rx_after = rd.rdata;

    // 5) Read CFG (0x8) after
    rd = apb_read_reg_seq::type_id::create("rd_cfg_after");
    rd.addr = 12'h008;
    rd.start(p_sequencer.apb_sqr);
    cfg_after = rd.rdata;

    // 6) Check unchanged
    if (rx_after[7:0] !== rx_before[7:0]) begin
      `uvm_error("VSEQ_SIDEFX",
        $sformatf("RX_DATA changed after writing TX_DATA! BEFORE=0x%08h AFTER=0x%08h",
                  rx_before, rx_after))
    end
    else begin
      `uvm_info("VSEQ_SIDEFX",
        $sformatf("RX_DATA unchanged OK. VAL=0x%08h", rx_after),
        UVM_MEDIUM)
    end

    if (cfg_after[4:0] !== cfg_before[4:0]) begin
      `uvm_error("VSEQ_SIDEFX",
        $sformatf("CFG changed after writing TX_DATA! BEFORE=0x%08h AFTER=0x%08h",
                  cfg_before, cfg_after))
    end
    else begin
      `uvm_info("VSEQ_SIDEFX",
        $sformatf("CFG unchanged OK. VAL=0x%08h", cfg_after),
        UVM_MEDIUM)
    end

    `uvm_info("VSEQ_SIDEFX", "=== DONE ===", UVM_MEDIUM)
  endtask
endclass

class vseq_send_TX_sweep_all_cfg_32 extends base_vseq;
  `uvm_object_utils(vseq_send_TX_sweep_all_cfg_32)

  apb_uart_config cfg;
  vseq_send_TX    one_tx;

  function new(string name="vseq_send_TX_sweep_all_cfg_32");
    super.new(name);
  endfunction

  task automatic get_cfg_once();
    if (cfg == null) begin
      if (!system_config::get(p_sequencer, "", "cfg", cfg)) begin
        `uvm_fatal("CFG32", "Cannot get cfg from p_sequencer (key='cfg')")
      end
    end
  endtask

  task automatic banner(string s);
    string line = "======================================================================";
    `uvm_info("CFG32", "", UVM_NONE)
    `uvm_info("CFG32", line, UVM_NONE)
    `uvm_info("CFG32", s,    UVM_NONE)
    `uvm_info("CFG32", line, UVM_NONE)
  endtask

  // Apply cfg fields (NO randomize) and publish back
  task automatic set_cfg_fields(int idx,
                                uart_data_size_e db,
                                uart_stop_size_e sb,
                                uart_parity_mode_e  pe,
                                uart_parity_type_e pt);
    get_cfg_once();

    cfg.data_bit_num      = db;
    cfg.stop_bit_num      = sb;
    cfg.parity_en         = pe;
    cfg.parity_type       = pt;
    cfg.parity_err_target = GOOD_PARITY;

    // TX-only để tránh kích RX path không cần thiết
    cfg.monitor_mode      = MON_TX_ONLY;

    // publish lại (phòng trường hợp vseq con get() ở scope khác)
    system_config::set(p_sequencer, "", "cfg", cfg);
    system_config::set(null, "*", "cfg", cfg);

    `uvm_info("CFG32", $sformatf(
      "[%0d/32] APPLY CFG: data=%s stop=%s parity_en=%s parity_type=%s (GOOD_PARITY)",
      idx,
      cfg.data_bit_num.name(),
      cfg.stop_bit_num.name(),
      cfg.parity_en.name(),
      cfg.parity_type.name()
    ), UVM_LOW)
  endtask

  virtual task body();
    int idx = 0;

    // Bạn đổi enum type ở đây nếu tên enum trong project khác.
    uart_data_size_e      db_list[4] = '{DATA_5BIT, DATA_6BIT, DATA_7BIT, DATA_8BIT};
    uart_parity_mode_e      pe_list[2] = '{PARITY_DIS, PARITY_EN};
    uart_parity_type_e    pt_list[2] = '{PARITY_ODD, PARITY_EVEN};
    uart_stop_size_e      sb_list[2] = '{STOP_1BIT, STOP_2BIT};

    banner("START: Sweep ALL 32 UART CFGs (GOOD_PARITY) and SEND 1 TX each");

    // Loop all combinations: 4*2*2*2 = 32
    foreach (db_list[dbi]) begin
      foreach (pe_list[pei]) begin
        foreach (pt_list[pti]) begin
          foreach (sb_list[sbi]) begin
            `uvm_info("VSEQ_N", $sformatf(
            "\n#####======================== Executing FRAME %0d/32 ========================#####",
            idx), UVM_LOW)
            // Nếu parity_en = DIS thì parity_type thực ra don't-care,
            // nhưng bạn yêu cầu đủ 32 config => vẫn chạy cả 2 parity_type luôn.

            idx++;

            set_cfg_fields(idx, db_list[dbi], sb_list[sbi], pe_list[pei], pt_list[pti]);

            // Gửi 1 frame TX với config hiện tại
            one_tx = vseq_send_TX::type_id::create($sformatf("one_tx_cfg%0d", idx));
            one_tx.start(p_sequencer);

          end
        end
      end
    end

    banner("DONE: Sweep 32 CFGs completed ");
  endtask
endclass

class vseq_receive_RX_sweep_all_cfg_32 extends base_vseq;
  `uvm_object_utils(vseq_receive_RX_sweep_all_cfg_32)

  apb_uart_config cfg;

  vseq_receive_RX one_rx;

  function new(string name="vseq_receive_RX_sweep_all_cfg_32");
    super.new(name);
  endfunction

  task automatic get_cfg_once();
    if (cfg == null) begin
      if (!system_config::get(p_sequencer, "", "cfg", cfg)) begin
        `uvm_fatal("RXCFG32", "Cannot get cfg from p_sequencer (key='cfg')")
      end
    end
  endtask

  task automatic banner(string s);
    string line = "======================================================================";
    `uvm_info("RXCFG32", "", UVM_NONE)
    `uvm_info("RXCFG32", line, UVM_NONE)
    `uvm_info("RXCFG32", s,    UVM_NONE)
    `uvm_info("RXCFG32", line, UVM_NONE)
  endtask

  task automatic set_cfg_fields(int idx,
                                uart_data_size_e db,
                                uart_stop_size_e sb,
                                uart_parity_mode_e  pe,
                                uart_parity_type_e pt);
    get_cfg_once();

    cfg.data_bit_num      = db;
    cfg.stop_bit_num      = sb;
    cfg.parity_en         = pe;
    cfg.parity_type       = pt;
    cfg.parity_err_target = GOOD_PARITY;

    // RX test: ép RX-only để tránh kích TX path
    cfg.monitor_mode      = MON_RX_ONLY;
    cfg.monitor_mode = MON_BOTH;
    // publish lại để vseq con get() đâu cũng thấy đúng handle
    system_config::set(p_sequencer, "", "cfg", cfg);
    system_config::set(null, "*", "cfg", cfg);

    `uvm_info("RXCFG32", $sformatf(
      "[%0d/32] APPLY RX CFG: data=%s stop=%s parity_en=%s parity_type=%s (%s)",
      idx,
      cfg.data_bit_num.name(),
      cfg.stop_bit_num.name(),
      cfg.parity_en.name(),
      cfg.parity_type.name(),
      cfg.parity_err_target.name()
    ), UVM_LOW)
  endtask

  virtual task body();
    int idx = 0;

    // Bạn đổi enum type ở đây nếu tên enum trong project khác.
    uart_data_size_e      db_list[4] = '{DATA_5BIT, DATA_6BIT, DATA_7BIT, DATA_8BIT};
    uart_parity_mode_e      pe_list[2] = '{PARITY_DIS, PARITY_EN};
    uart_parity_type_e    pt_list[2] = '{PARITY_ODD, PARITY_EVEN};
    uart_stop_size_e      sb_list[2] = '{STOP_1BIT, STOP_2BIT};

    banner("START: Sweep ALL 32 RX CFGs (GOOD_PARITY) and RECEIVE 1 frame each");

    foreach (db_list[dbi]) begin
      foreach (pe_list[pei]) begin
        foreach (pt_list[pti]) begin
          foreach (sb_list[sbi]) begin
            `uvm_info("VSEQ_N", $sformatf(
            "\n#####======================== Executing FRAME %0d/32 ========================#####",
            idx), UVM_LOW)
            idx++;

            // Bạn muốn đủ 32 combo => parity_en=DIS vẫn chạy cả 2 parity_type
            set_cfg_fields(idx, db_list[dbi], sb_list[sbi], pe_list[pei], pt_list[pti]);

            // Receive 1 frame
            one_rx = vseq_receive_RX::type_id::create($sformatf("one_rx_cfg%0d", idx));
            one_rx.start(p_sequencer);
          end
        end
      end
    end

    banner("DONE: Sweep 32 RX CFGs completed ");
  endtask
endclass

// =========== TX ====================================================================================
// =========== TX ====================================================================================
// =========== TX ====================================================================================
// =========== TX ====================================================================================

// tx test 1:
// check basic tx start: set start_tx = 1 sau khi nạp tx_dat, chân tx hạ xuống 0, chạy sequence vseq_send_TX

// test_tx 2: để kiểm khi có cts_n = 0 thì uart truyền bình thường
class vseq_tx_cts_asserted extends base_vseq;
    `uvm_object_utils(vseq_tx_cts_asserted)

    // HDL Path trỏ thẳng tới tín hiệu cts_n trong interface tại hw_top
    localparam string CTS_N_PATH = "$root.hw_top.uif.cts_n";

    vseq_send_TX single_tx_vseq;

    virtual task body();
        `uvm_info("TX_CTS_TEST", "=== STARTING TEST: CTS ASSERTED (Only Virseqs Mode) ===", UVM_LOW)

        // Giải phóng force cũ (nếu có) và nạp giá trị 0
        if (!uvm_hdl_deposit(CTS_N_PATH, 1'b0)) begin
            `uvm_error("BACKDOOR_ERR", $sformatf("Cannot deposit value to %s", CTS_N_PATH))
        end
        
        `uvm_info("TX_CTS_TEST", "CTS_N forced to 0 via Backdoor path.", UVM_MEDIUM)

        single_tx_vseq = vseq_send_TX::type_id::create("single_tx_vseq");
        `uvm_do(single_tx_vseq)

        `uvm_info("TX_CTS_TEST", "=== CTS ASSERTED TEST COMPLETED ===", UVM_LOW)
    endtask
endclass

// test_tx 3: để kiểm khi có cts_n = 1, ra lệnh truyền thì uart không truyền đợi bit start_tx reg được set
class vseq_tx_cts_deasserted extends base_vseq;
    `uvm_object_utils(vseq_tx_cts_deasserted)

    localparam string CTS_N_PATH = "$root.hw_top.uif.cts_n";
    localparam string TX_PATH = "$root.hw_top.uif.tx";
    
    send_tx_data_seq  apb_send_vseq;

    function new(string name="vseq_tx_cts_deasserted");
        super.new(name);
    endfunction

    virtual task body();
        `uvm_info("TX_CTS_TEST", "=== STARTING TEST: CTS DE-ASSERTED (cts_n=1) ===", UVM_LOW)

        // 1. Ép chân CTS_N lên 1 (Trạng thái bận) 
        // Sử dụng void'() để xóa cảnh báo biên dịch vlog-2240
        if (!uvm_hdl_force(CTS_N_PATH, 1'b1)) begin
            `uvm_error("BACKDOOR_ERR", $sformatf("Cannot force %s", CTS_N_PATH))
        end
        `uvm_info("TX_CTS_TEST", "CTS_N is FORCED to 1. DUT must NOT transmit.", UVM_MEDIUM)

        // 2. Chuẩn bị dữ liệu truyền qua APB
        apb_send_vseq = send_tx_data_seq::type_id::create("apb_send_vseq");
        apb_send_vseq.tx_byte = 8'h5A; 
        
        fork
            // Thread 1: Gửi lệnh truyền qua APB (Ghi data và set start_tx)
            begin
                `uvm_do_on(apb_send_vseq, p_sequencer.apb_sqr)
            end

            // Thread 2: Giám sát chân TX vật lý 
            begin
                fork
                    begin
                        // Đợi cạnh xuống của chân TX (Nếu thiết kế sai, nó sẽ hạ xuống 0) 
                        // Dùng đường dẫn phân cấp để tránh lỗi "No field named vif"
                        @(negedge TX_PATH); 
                        `uvm_error("TX_CTS_FAIL", "DUT transmitted data even though CTS_N = 1!") 
                    end
                    begin
                        // Thời gian chờ đủ lâu để xác nhận DUT đang thực sự "đợi" 
                        #200us; 
                        `uvm_info("TX_CTS_PASS", "DUT correctly remained IDLE while CTS_N = 1.", UVM_LOW) 
                    end
                join_any
                disable fork; // Dừng việc đứng canh khi 1 trong 2 sự kiện trên xảy ra 
            end
        join

        // 3. Giải phóng chân CTS_N để UART có thể truyền tiếp (nếu muốn) 
        void'(uvm_hdl_release(CTS_N_PATH)); 
        
        `uvm_info("TX_CTS_TEST", "=== CTS DE-ASSERTED TEST COMPLETED ===", UVM_LOW)
    endtask
endclass

// test tx 4. Kéo cts_n lên 1 khi đang gửi bit dữ liệu thứ 4. Phải truyền xong khung hiện tại mới được dừng.
// class vseq_tx_cts_mid_frame extends base_vseq;
//     `uvm_object_utils(vseq_tx_cts_mid_frame)

//     localparam string CTS_N_PATH = "$root.hw_top.uif.cts_n";
//     localparam string TX_PATH = "$root.hw_top.uif.tx";

//     apb_uart_config shared_cfg;
//     vseq_send_TX single_tx_vseq;

//     // rand int delay;

//     // constraint c_delay { delay inside {[2:5]}; }

//     function new(string name="vseq_tx_cts_mid_frame");
//         super.new(name);
//     endfunction

//     virtual task body();
//         real bit_period_ns;

//         if (!system_config::get(p_sequencer, "", "cfg", shared_cfg)) begin
//             `uvm_fatal("VSEQ_MID", "Cannot find 'cfg' in Config DB!")
//         end
//         bit_period_ns = 1000000000.0 / shared_cfg.baud_rate;

//         `uvm_info("TX_CTS_MID", "=== STARTING TEST: CTS DE-ASSERTED MID-FRAME ===", UVM_LOW)

//         // Đảm bảo ban đầu CTS_N = 0 để DUT bắt đầu truyền
//         void'(uvm_hdl_force(CTS_N_PATH, 1'b0));

//         // Chạy kịch bản truyền 1 frame
//         single_tx_vseq = vseq_send_TX::type_id::create("single_tx_vseq");

//         fork
//             // Thread 1: Thực hiện các lệnh APB để truyền dữ liệu
//             begin
//                 `uvm_do(single_tx_vseq)
//             end

//             // Thread 2: Canh thời gian để kéo CTS_N lên 1 tại bit dữ liệu thứ 4
//             begin
//                 // Đợi cho đến khi thấy Start bit (TX: 1 -> 0)
//                 @(negedge TX_PATH);
                
//                 // Đợi: 1 bit Start + 3 bit Data + 0.5 bit (để rơi vào giữa bit thứ 4)
//                 #(bit_period_ns * 4.5 * 1ns); 
                
//                 void'(uvm_hdl_force(CTS_N_PATH, 1'b1));
//                 `uvm_info("TX_CTS_MID", "CTS_N forced to 1 during Data Bit 4. DUT must continue!", UVM_MEDIUM)
//             end
//         join

//         // 4. Giải phóng chân CTS_N
//         void'(uvm_hdl_release(CTS_N_PATH));
        
//         `uvm_info("TX_CTS_MID", "=== CTS MID-FRAME TEST COMPLETED ===", UVM_LOW)
//     endtask
// endclass

// tx test seq 4: theo doi tx_don reg, phải về 0 sau 1 chu kì khi start_tx = 1 và lên 1 khi truyền xong
class vseq_tx_done_pulse extends base_vseq;
    `uvm_object_utils(vseq_tx_done_pulse)

    localparam string PATH_TX_DONE  = "$root.hw_top.dut.tx_done";
    localparam string PATH_START_TX = "$root.hw_top.dut.start_tx";
    localparam string CTS_N_PATH    = "$root.hw_top.uif.cts_n";
    
    send_tx_data_seq apb_send_vseq;
    apb_uart_config  shared_cfg;

    virtual task body();
        int val;
        real bit_period_ns;
        int total_bits;

        if (!system_config::get(p_sequencer, "", "cfg", shared_cfg)) begin
            `uvm_fatal("VSEQ", "Cannot find 'cfg' in Config DB!")
        end

        bit_period_ns = 1000000000.0 / shared_cfg.baud_rate; 
        total_bits = 1 + (shared_cfg.data_bit_num == DATA_5BIT ? 5 : 
                         shared_cfg.data_bit_num == DATA_6BIT ? 6 :
                         shared_cfg.data_bit_num == DATA_7BIT ? 7 : 8);
        if (shared_cfg.parity_en == PARITY_EN) total_bits += 1;
        total_bits += (shared_cfg.stop_bit_num == STOP_2BIT) ? 2 : 1;

        `uvm_info("TX_DONE_PULSE", $sformatf("=== STARTING TEST: Frame width = %0d bits ===", total_bits), UVM_LOW)

        void'(uvm_hdl_force(CTS_N_PATH, 1'b0));
        apb_send_vseq = send_tx_data_seq::type_id::create("apb_send_vseq");
        
        if(!apb_send_vseq.randomize()) `uvm_error("VSEQ", "Randomization failed")

        fork
            begin
                `uvm_do_on(apb_send_vseq, p_sequencer.apb_sqr)
            end

            begin
                // Đợi start_tx nội bộ lên 1 
                wait_hdl_val(PATH_START_TX, 1);
                
                // Kiểm tra tx_done phải về 0 sau 1 bit (Start bit)
                #(bit_period_ns * 2 * 1ns); 
                void'(uvm_hdl_read(PATH_TX_DONE, val));
                if (val == 0) 
                    `uvm_info("TX_DONE_PULSE", "SUCCESS: tx_done dropped to 0 during transmission", UVM_LOW)
                else 
                    `uvm_error("TX_DONE_PULSE", "FAILED: tx_done did not drop to 0!")

                // Đợi tx_done thực sự quay lại 1 từ RTL
                wait_hdl_val(PATH_TX_DONE, 1);
                
                #(bit_period_ns * 2.0 * 1ns); 
                
                `uvm_info("TX_DONE_PULSE", "SUCCESS: tx_done returned to 1 and Monitor finished.", UVM_LOW)
            end
        join

        void'(uvm_hdl_release(CTS_N_PATH)); 
        `uvm_info("TX_DONE_PULSE", "=== TX_DONE PULSE TEST COMPLETED ===", UVM_LOW)
    endtask

    task wait_hdl_val(string path, int exp);
        int val;
        forever begin
            void'(uvm_hdl_read(path, val));
            if (val == exp) break;
            #50; 
        end
    endtask
endclass

// =========== RX ====================================================================================
// =========== RX ====================================================================================
// =========== RX ====================================================================================
// =========== RX ====================================================================================

// test rx 2 rts flow 
class vseq_rx_rts_flow_control extends base_vseq;
    `uvm_object_utils(vseq_rx_rts_flow_control)

    localparam string RTS_N_PATH = "$root.hw_top.uif.rts_n";
    
    system_config_seq    config_vseq;  
    read_rx_data_seq     apb_read_seq;  
    apb_uart_config      shared_cfg;

    function new(string name="vseq_rx_rts_flow_control");
        super.new(name);
    endfunction

    virtual task body();
        real bit_period_ns;
        int  actual_data_bits; 
        int  total_frame_bits;
        int  val;

        `uvm_info("RTS_TEST", "=== STARTING RTS FLOW CONTROL TEST (READY & BUSY) ===", UVM_MEDIUM)

        // Lấy cấu hình từ Config DB [cite: 138, 156]
        if (!system_config::get(p_sequencer, "", "cfg", shared_cfg)) begin
            `uvm_fatal("VSEQ", "Cannot find 'cfg' in Config DB!")
        end

        // BƯỚC 1: KIỂM TRA RTS SAU RESET (Trạng thái Ready khởi tạo) 
        #110ns; // Đợi ngay sau khi nhả reset
        void'(uvm_hdl_read(RTS_N_PATH, val));
        if (val === 1'b0) begin
            `uvm_info("RTS_PASS", "\n======================== RTS correctly high (Busy/Not Init) after reset. ========================", UVM_LOW)
        end else begin
            `uvm_error("RTS_FAIL", "\n======================== RTS is 0 (Ready) immediately after reset - Design should wait for init! ========================")
        end

        // Cấu hình UART UVC bắt đầu gửi dữ liệu
        config_vseq = system_config_seq::type_id::create("config_vseq");
        config_vseq.shared_cfg = shared_cfg;

        // Tính toán thời gian bit và tổng số bit khung hình 
        bit_period_ns = 1000000000.0 / shared_cfg.baud_rate; 
        case(shared_cfg.data_bit_num) 
            DATA_5BIT: actual_data_bits = 5;
            DATA_6BIT: actual_data_bits = 6;
            DATA_7BIT: actual_data_bits = 7;
            DATA_8BIT: actual_data_bits = 8;
            default:   actual_data_bits = 8;
        endcase

        total_frame_bits = 1 + actual_data_bits; // Start + Data
        if (shared_cfg.parity_en == PARITY_EN) total_frame_bits += 1; 
        total_frame_bits += (shared_cfg.stop_bit_num == STOP_2BIT) ? 2 : 1; 

        fork
            begin
                config_vseq.start(p_sequencer);
            end
            begin
                 // --------------------------------------------------------------------------
                // BƯỚC 2: KIỂM TRA RTS BUSY (Khi đang nhận dữ liệu - Mid-frame)
                // --------------------------------------------------------------------------
                // Chờ qua bit Start và 2 bit dữ liệu
                #(bit_period_ns * 2.5 * 1ns); 
                void'(uvm_hdl_read(RTS_N_PATH, val));
                if (val === 1'b1) begin
                    `uvm_info("RTS_PASS", "\n======================== RTS is 1 (Busy) while receiving data. ========================", UVM_LOW)
                end else begin
                    `uvm_error("RTS_FAIL", "\n======================== DUT BUG: RTS is 0 (Ready) while receiving frame! ========================")
                end
            end
        join
       

        // --------------------------------------------------------------------------
        // BƯỚC 3: KIỂM TRA RTS BUSY (Dữ liệu chưa được CPU đọc)
        // --------------------------------------------------------------------------
        // Chờ truyền xong hoàn toàn khung hình
        // repeat(total_frame_bits) #(bit_period_ns * 1ns); 
        #(bit_period_ns * 2 * 1ns);
        // void'(uvm_hdl_read(RTS_N_PATH, val));
        // if (val === 1'b0) begin
        //     `uvm_info("RTS_PASS", "\n======================== RTS correctly stays 0 (READY) when data is pending read. ========================", UVM_LOW)
        // end else begin
        //     `uvm_error("RTS_FAIL", "\n======================== DUT BUG: RTS_N = 1  before CPU read the data! ========================")
        // end

        // --------------------------------------------------------------------------
        // BƯỚC 4: KIỂM TRA RTS READY (Sau khi APB đọc dữ liệu) 
        // --------------------------------------------------------------------------
        apb_read_seq = read_rx_data_seq::type_id::create("apb_read_seq");
        `uvm_do_on(apb_read_seq, p_sequencer.apb_sqr) 

        #100ns; // Đợi một khoảng ngắn cho logic nội bộ cập nhật
        void'(uvm_hdl_read(RTS_N_PATH, val));
        if (val === 1'b0) begin
            `uvm_info("RTS_PASS", "\n======================== RTS dropped to 0 (Ready) after APB Read completed. ========================", UVM_LOW)
        end else begin
            `uvm_error("RTS_FAIL", "\n======================== RTS stayed 1 (Busy) even after data was read! ========================")
        end

        config_vseq.start(p_sequencer);

        `uvm_info("RTS_TEST", "=== RTS FLOW CONTROL TEST COMPLETED ===", UVM_MEDIUM)
    endtask
endclass
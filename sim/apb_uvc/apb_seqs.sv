class apb_base_seq extends uvm_sequence #(apb_transaction);
    `uvm_object_utils(apb_base_seq)

    function new(string name="apb_base_seq");
      super.new(name);
    endfunction

  task pre_body();
    uvm_phase phase;
    `ifdef UVM_VERSION_1_2
      // in UVM1.2, get starting phase from method
      phase = get_starting_phase();
    `else
      phase = starting_phase;
    `endif

    if (phase != null) begin
      phase.raise_objection(this, get_type_name());
      `uvm_info(get_type_name(), "raise objection", UVM_MEDIUM)
    end
  endtask : pre_body

  task post_body();
    uvm_phase phase;
    `ifdef UVM_VERSION_1_2
      // in UVM1.2, get starting phase from method
      phase = get_starting_phase();
    `else
      phase = starting_phase;
    `endif

    if (phase != null) begin
      phase.drop_objection(this, get_type_name());
      `uvm_info(get_type_name(), "drop objection", UVM_MEDIUM)
    end
  endtask : post_body

endclass //apb_base_seq extends superClass

// sequence cấu hình cho uart
class apb_config_seq extends apb_base_seq;
    `uvm_object_utils(apb_config_seq)

    function new(string name="apb_config_seq");
      super.new(name);
    endfunction

    virtual task body();
      `uvm_info(get_type_name(), "Configuring UART Frame: 8 bits, 1 Stop bit, No Parity", UVM_LOW)

      // Ghi vào cfg_reg (0x8) 
      // Bit [1:0] = 2'b11 (8 bits) 
      // Bit [2]   = 1'b0  (1 stop bit) 
      // Bit [3]   = 1'b0  (Disable parity) 
      `uvm_do_with(req, { 
        paddr  == 12'h008; 
        pwrite == 1'b1; 
        pwdata == 32'h0000_0003; 
        pstrb  == 4'hf;
      })
    endtask
endclass

class apb_config_random_seq extends apb_base_seq;
    `uvm_object_utils(apb_config_random_seq)
    
    rand uart_data_size_e   data_bit_num;
    rand uart_stop_size_e   stop_bit_num;
    rand uart_parity_mode_e parity_en;
    rand uart_parity_type_e parity_type;
    rand bit                pstrb_bit0; 

    constraint c_uart_cfg {
      data_bit_num dist { DATA_8BIT := 60, [DATA_5BIT:DATA_7BIT] := 40 };
    }

    function new(string name="apb_config_random_seq");
      super.new(name);
    endfunction

    virtual task body();
      bit [31:0] cfg_data = 32'h0;

      cfg_data[1:0] = data_bit_num;
      cfg_data[2]   = stop_bit_num;
      cfg_data[3]   = parity_en;
      cfg_data[4]   = parity_type;

      `uvm_info(get_type_name(), $sformatf("Random Config: Size=%s, Stop=%s, Parity=%s, Type=%s, PSTRB0=%b", 
                data_bit_num.name(), stop_bit_num.name(), parity_en.name(), parity_type.name(), pstrb_bit0), UVM_LOW)

      `uvm_do_with(req, { 
        paddr  == 12'h008; 
        pwrite == 1'b1; 
        pwdata == cfg_data; 
        pstrb  == {3'b000, pstrb_bit0};
      })
    endtask
endclass

// use in virtual 
class apb_config_frame_seq extends apb_base_seq;
  `uvm_object_utils(apb_config_frame_seq)

  apb_uart_config cfg; 

  function new(string name="apb_config_frame_seq");
    super.new(name);
  endfunction

  virtual task body();
    bit [31:0] wdata = 0;

    if (cfg == null) begin
        `uvm_fatal("APB_CFG_SEQ", "Config object is NULL! Virtual Sequence must set it.")
    end
    
    wdata[1:0] = cfg.data_width;
    wdata[2]   = cfg.stop_bits;
    wdata[3]   = cfg.parity_en;
    wdata[4]   = cfg.parity_type;

    `uvm_info("APB_WR_SEQ", $sformatf("Writing Config to DUT: 0x%h (Size=%s)", wdata, cfg.data_width.name()), UVM_LOW)

    `uvm_do_with(req, { 
        paddr  == 12'h008; 
        pwrite == 1'b1; 
        pwdata == wdata; 
        pstrb  == 4'hf;
    })
  endtask
endclass

// sequence truyền dữ liệu 
class apb_trans_data_seq extends apb_base_seq;
    `uvm_object_utils(apb_trans_data_seq)
  
    rand logic [7:0] tx_byte;

    function new(string name="apb_trans_data_seq");
      super.new(name);
    endfunction

    virtual task body();
      `uvm_info(get_type_name(), $sformatf("Executing TX sequence with data: 0x%0h", tx_byte), UVM_LOW)

      // Bước 1: Ghi dữ liệu vào tx_data_reg (0x0) 
      `uvm_do_with(req, { 
        paddr  == 12'h000; 
        pwrite == 1'b1; 
        pwdata == tx_byte; 
        pstrb  == 4'hf;
      })

      // Bước 2: Kích hoạt truyền bằng cách set bit start_tx trong ctrl_reg (0xC) 
      `uvm_do_with(req, { 
        paddr  == 12'h00C; 
        pwrite == 1'b1; 
        pwdata == 32'h0000_0001; // start_tx = bit [0] 
        pstrb  == 4'hf;
      })
    endtask

    task wait_for_tx_done();
        bit done = 0;
        while (!done) begin
            `uvm_do_with(req, { paddr == 12'h010; pwrite == 1'b0; })
            done = req.prdata[0]; 
            if (!done) #10ns; 
        end
    endtask
endclass

class apb_trans_random_data_seq extends apb_base_seq;
    `uvm_object_utils(apb_trans_random_data_seq)

    rand logic [31:0] random_data;
    rand bit          pstrb_bit0;

    function new(string name="apb_trans_random_data_seq");
      super.new(name);
    endfunction

    virtual task body();
      `uvm_info(get_type_name(), $sformatf("Executing TX Random: Data=0x%0h, PSTRB=0x%0h", 
                random_data, pstrb_bit0), UVM_LOW)

      // BƯỚC 1: Ghi dữ liệu ngẫu nhiên vào thanh ghi TX_DATA (Địa chỉ 0x0) 
      `uvm_do_with(req, { 
        paddr  == 12'h000; 
        pwrite == 1'b1; 
        pwdata == random_data; 
        pstrb  == {3'b000, pstrb_bit0}; 
      })

      // BƯỚC 2: Kích hoạt lệnh truyền (Start TX) tại thanh ghi CTRL (Địa chỉ 0xC)z
      `uvm_do_with(req, { 
        paddr  == 12'h00C; 
        pwrite == 1'b1; 
        pwdata == 32'h0000_0001; // bit [0] là start_tx
        pstrb  == 4'h1;
      })
    endtask

endclass

class apb_multiple_trans_seq extends apb_base_seq;
    `uvm_object_utils(apb_multiple_trans_seq)

    rand int count;
    constraint c_count { count inside {[3:10]}; }

    function new(string name="apb_multiple_trans_seq");
      super.new(name);
    endfunction

    virtual task body();
      `uvm_info(get_type_name(), $sformatf("Executing multiple TX: %0d packets", count), UVM_LOW)

      repeat(count) begin

        apb_trans_random_data_seq single_tx;
        
        `uvm_do(single_tx) 
      end
    endtask
endclass

// seq đọc thanh ghi trạng thái stt_reg
class apb_read_status_seq extends apb_base_seq;
    `uvm_object_utils(apb_read_status_seq)

    function new(string name="apb_read_status_seq");
      super.new(name);
    endfunction

    virtual task body();
      `uvm_info(get_type_name(), "Reading UART Status Register (0x10)", UVM_LOW)
      `uvm_do_with(req, { 
        paddr  == 12'h010; 
        pwrite == 1'b0; 
      })
      // Sau khi Driver thực hiện xong, dữ liệu nằm trong req.prdata 
    endtask

endclass

// equence Kiểm Tra Lỗi Protocol
class apb_protocol_error_seq extends apb_base_seq;
    `uvm_object_utils(apb_protocol_error_seq)

    virtual task body();
      `uvm_info(get_type_name(), "Testing Illegal Access (Invalid Address)", UVM_LOW)

      // Ghi vào địa chỉ "lạ" không có trong Spec (ví dụ 0xFFF)
      `uvm_do_with(req, { 
        paddr  == 12'hFFF; 
        pwrite == 1'b1; 
        pwdata == 32'hDEAD_BEEF;
        pstrb  == 4'b1010; // Strobe "lạ" 
      })

      // mong đợi pslverr trả về từ Monitor
    endtask
endclass
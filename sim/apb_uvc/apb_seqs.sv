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

endclass 

// use in virtual 
class apb_config_frame_seq extends apb_base_seq;
  `uvm_object_utils(apb_config_frame_seq)

  rand apb_uart_config cfg; 

  function new(string name="apb_config_frame_seq");
    super.new(name);
  endfunction

  virtual task body();
    bit [31:0] wdata = 0;

    if (cfg == null) begin
        `uvm_fatal("APB_CFG_SEQ", "Config object is NULL! Virtual Sequence must set it.")
    end
    
    wdata[1:0] = cfg.data_bit_num;
    wdata[2]   = cfg.stop_bit_num;
    wdata[3]   = cfg.parity_en;
    wdata[4]   = cfg.parity_type;

    `uvm_info("APB_WR_SEQ", $sformatf("Writing Config to DUT: 0x%h \n (%s, %s, %s, %s)", wdata, 
                                      cfg.data_bit_num.name(),
                                      cfg.parity_en.name(),
                                      cfg.parity_type.name(),
                                      cfg.stop_bit_num.name()), UVM_MEDIUM)

    `uvm_do_with(req, { 
        paddr  == 12'h008; 
        pwrite == 1'b1; 
        pwdata == wdata; 
        pstrb  == 4'h1;
    })
  endtask
endclass

// sequence truyền dữ liệu 
class send_tx_data_seq extends apb_base_seq;
    `uvm_object_utils(send_tx_data_seq)
  
    rand logic [7:0] tx_byte;

    function new(string name="send_tx_data_seq");
      super.new(name);
    endfunction

    virtual task body();
      `uvm_info(get_type_name(), $sformatf("Send TX with data: 0x%0h", tx_byte), UVM_HIGH)

      // Bước 1: Ghi dữ liệu vào tx_data_reg (0x0) 
      `uvm_do_with(req, { 
        paddr  == 12'h000; 
        pwrite == 1'b1; 
        pwdata == tx_byte; 
        pstrb  == 4'h1;
      })

      // Bước 2: Kích hoạt truyền bằng cách set bit start_tx trong ctrl_reg (0xC) 
      `uvm_do_with(req, { 
        paddr  == 12'h00C; 
        pwrite == 1'b1; 
        pwdata == 32'h0000_0001; // start_tx = bit [0] 
        pstrb  == 4'h1;
      })
    endtask
endclass

class read_rx_data_seq extends apb_base_seq;
    `uvm_object_utils(read_rx_data_seq)
    
    logic [7:0] rx_data; 

    function new(string name="read_rx_data_seq");
      super.new(name);
    endfunction

    virtual task body();
      // Đọc thanh ghi RX_DATA (0x004) 
      `uvm_do_with(req, { paddr == 12'h004; pwrite == 1'b0; })
      rx_data = req.prdata[7:0];
      `uvm_info("APB_RX_SEQ", $sformatf("Read RX with DATA: %b", rx_data), UVM_LOW)
    endtask
endclass

// seq đọc thanh ghi trạng thái stt_reg
class read_status_reg_seq extends apb_base_seq;
    `uvm_object_utils(read_status_reg_seq)

    function new(string name="read_status_reg_seq");
      super.new(name);
    endfunction
    logic [31:0] read_data;
    virtual task body();
      `uvm_info(get_type_name(), "Reading UART Status Register (0x10)", UVM_LOW)
      `uvm_do_with(req, { 
        paddr  == 12'h010; 
        pwrite == 1'b0; 
      })
      // Sau khi Driver thực hiện xong, dữ liệu nằm trong req.prdata 
      read_data = req.prdata;
    endtask

endclass

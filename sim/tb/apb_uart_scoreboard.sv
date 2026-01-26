class apb_uart_scoreboard extends uvm_scoreboard;
  // TLM Port Declarations
  `uvm_analysis_imp_decl(_apb)
  `uvm_analysis_imp_decl(_uart)

  `uvm_component_utils(apb_uart_scoreboard)

  // -------- analysis imps ----------
  uvm_analysis_imp_apb  #(apb_transaction,  apb_uart_scoreboard) apb_port;
  uvm_analysis_imp_uart #(uart_transaction, apb_uart_scoreboard) uart_port;

  // -------- config ----------
  apb_uart_config cfg;
  virtual apb_if vif;

  bit cfg_check_pending;
  bit [31:0] last_cfg_pwdata;

  // -------- queues ----------
  apb_transaction  read_queue [$];   // chỉ chứa APB read từ RX DATA (0x004)
  apb_transaction  write_queue[$];   // chỉ chứa APB write vào TX DATA (0x000)
  
  uart_transaction tx_queue[$];      // UART monitor bắt trên TX (DUT->UVC)
  uart_transaction rx_queue[$];      // UART monitor bắt trên RX (UVC->DUT)

  // -------- DUT HDL paths (theo repo của bạn) ----------
  localparam string DUT_DATA_BIT_NUM_PATH = "$root.hw_top.dut.data_bit_num"; // [1:0]
  localparam string DUT_STOP_BIT_NUM_PATH = "$root.hw_top.dut.stop_bit_num"; // [0]
  localparam string DUT_PARITY_EN_PATH    = "$root.hw_top.dut.parity_en";    // [0]
  localparam string DUT_PARITY_TYPE_PATH  = "$root.hw_top.dut.parity_type";  // [0]

  // -------- counters ----------
  int tx_match, tx_mis;
  int rx_match, rx_mis;
  int cfg_ok, cfg_bad;

  function new(string name="apb_uart_scoreboard", uvm_component parent=null);
    super.new(name, parent);
    apb_port  = new("apb_port",  this);
    uart_port = new("uart_port", this);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    if (!system_config::get(this, "", "cfg", cfg)) begin
      `uvm_fatal("SB_CFG", "Scoreboard cannot get cfg from DB (system_config::get)!")
    end

    if (!apb_vif_config::get(this, "", "vif", vif)) begin
      `uvm_fatal("SB", {"Virtual interface must be set for: ", get_full_name(), ".vif"})
    end
  endfunction 

  // ============================================================
  // APB side
  // - write TXDATA (0x000) -> write_queue
  // - read  RXDATA (0x004) -> read_queue
  // - write CFG   (0x008)  -> immediate uvm_hdl_read check
  // ============================================================
  virtual function void write_apb(apb_transaction tr);

    if (tr.pwrite && tr.paddr == 12'h000) begin
      write_queue.push_back(tr);
      `uvm_info("SB_APB",
        $sformatf("APB->TXDATA queued: 0x%02h", tr.pwdata[7:0]),
        UVM_MEDIUM)
      return;
    end

    if (!tr.pwrite && tr.paddr == 12'h004) begin
      read_queue.push_back(tr);
      `uvm_info("SB_APB",
        $sformatf("APB<-RXDATA queued: 0x%02h", tr.prdata[7:0]),
        UVM_MEDIUM)
      return;
    end

    if (tr.pwrite && tr.paddr == 12'h008) begin
      last_cfg_pwdata = tr.pwdata;
      cfg_check_pending = 1'b1;
      return;
    end

  endfunction

  // ============================================================
  // UART side
  // - if is_tx==1 -> tx_queue
  // - else        -> rx_queue
  // ============================================================
  virtual function void write_uart(uart_transaction tr);
    if (tr.is_tx) begin
      tx_queue.push_back(tr);
      `uvm_info("SB_UART", $sformatf("UART TX queued: 0x%02h", tr.data), UVM_MEDIUM)
    end else begin
      rx_queue.push_back(tr);
      `uvm_info("SB_UART", $sformatf("UART RX queued: 0x%02h", tr.data), UVM_MEDIUM)
    end
  endfunction

  // ============================================================
  // Compare loops
  // - write_queue  vs tx_queue
  // - read_queue   vs rx_queue
  // ============================================================
  task run_phase(uvm_phase phase);
  fork
    compare_apb_write_vs_uart_tx();
    compare_apb_read_vs_uart_rx();
    cfg_backdoor_checker();
  join
endtask

task automatic cfg_backdoor_checker();
  forever begin
    wait(cfg_check_pending);

    @(negedge vif.pclk);
    
    check_cfg_write_backdoor(); 
    cfg_check_pending = 1'b0;
  end
endtask
function automatic int unsigned get_data_bits();
  return (int'(cfg.data_bit_num) + 5);
endfunction

function automatic logic [7:0] mask_data(logic [31:0] x);
  int unsigned n;
  logic [7:0] m;
  n = get_data_bits();           // 5..8
  m = (8'hFF >> (8 - n));        // n=5 -> 0x1F, 6 ->0x3F, 7->0x7F, 8->0xFF
  return logic'(x[7:0] & m);
endfunction
task automatic compare_apb_write_vs_uart_tx();
  apb_transaction  apb_tr;
  uart_transaction uart_tr;

  logic [7:0] exp_data;
  logic [7:0] act_data;

  forever begin
    wait(write_queue.size() > 0 && tx_queue.size() > 0);

    apb_tr  = write_queue.pop_front();
    uart_tr = tx_queue.pop_front();

    exp_data = mask_data(apb_tr.pwdata);
    act_data = mask_data({24'h0, uart_tr.data}); // đảm bảo cùng mask theo cfg

    if (exp_data !== act_data) begin
      tx_mis++;
      `uvm_error("SB_TX",
        $sformatf("Mismatch APB->TXDATA vs UART_TX! bits=%0d EXP=0x%02h ACT=0x%02h (raw APB=0x%02h raw UART=0x%02h)",
                  get_data_bits(), exp_data, act_data, apb_tr.pwdata[7:0], uart_tr.data))
    end
    else if (uart_tr.parity_error_detected || uart_tr.framing_error_detected) begin
      tx_mis++;
      `uvm_error("SB_TX",
        $sformatf("UART TX line error for data 0x%02h (parity_err=%0b framing_err=%0b)",
                  uart_tr.data, uart_tr.parity_error_detected, uart_tr.framing_error_detected))
    end
    else begin
      tx_match++;
      `uvm_info("SB_TX",
        $sformatf("Match  APB->TXDATA == UART_TX == 0x%02h (bits=%0d)", act_data, get_data_bits()),
        UVM_LOW)
    end
  end
endtask
task automatic compare_apb_read_vs_uart_rx();
  apb_transaction  apb_tr;
  uart_transaction uart_tr;

  logic [7:0] exp_data;
  logic [7:0] act_data;

  forever begin
    wait(read_queue.size() > 0 && rx_queue.size() > 0);

    apb_tr  = read_queue.pop_front();
    uart_tr = rx_queue.pop_front();

    act_data = mask_data(apb_tr.prdata);
    exp_data = mask_data({24'h0, uart_tr.data}); // RX monitor data (expected)

    if (act_data !== exp_data) begin
      rx_mis++;
      `uvm_error("SB_RX",
        $sformatf("Mismatch APB<-RXDATA vs UART_RX! bits=%0d EXP=0x%02h ACT=0x%02h (raw UART=0x%02h raw APB=0x%02h)",
                  get_data_bits(), exp_data, act_data, uart_tr.data, apb_tr.prdata[7:0]))
    end
    else if (uart_tr.parity_error_detected || uart_tr.framing_error_detected) begin
      rx_mis++;
      `uvm_error("SB_RX",
        $sformatf("UART RX line error for data 0x%02h (parity_err=%0b framing_err=%0b)",
                  uart_tr.data, uart_tr.parity_error_detected, uart_tr.framing_error_detected))
    end
    else begin
      rx_match++;
      `uvm_info("SB_RX",
        $sformatf("Match UART_RX == APB<-RXDATA == 0x%02h (bits=%0d)", act_data, get_data_bits()),
        UVM_LOW)
    end
  end
endtask

  // ============================================================
  // Backdoor check for CFG write (0x008)
  // Compare:
  //  - pwdata bits vs DUT internal signals
  //  - pwdata bits vs cfg object fields (để biết TB đang config đúng không)
  // ============================================================
  // task automatic check_cfg_write_backdoor();
  //   // Khai báo biến tạm để đọc dữ liệu thô từ HDL 
  //   bit [1:0] got_db;
  //   bit       got_sb, got_pe, got_pt;

  //   // Đọc các tín hiệu nội bộ từ DUT bằng Backdoor 
  //   void'(uvm_hdl_read(DUT_DATA_BIT_NUM_PATH, got_db));
  //   void'(uvm_hdl_read(DUT_STOP_BIT_NUM_PATH, got_sb));
  //   void'(uvm_hdl_read(DUT_PARITY_EN_PATH,    got_pe));
  //   void'(uvm_hdl_read(DUT_PARITY_TYPE_PATH,  got_pt));

  //   // Kiểm tra sự khác biệt giữa DUT và cấu hình mong muốn (cfg) 
  //   if (got_db !== cfg.data_bit_num || got_sb !== cfg.stop_bit_num ||
  //       got_pe !== cfg.parity_en    || got_pt !== cfg.parity_type) begin
      
  //     cfg_bad++;

  //     `uvm_error("SB_CFG_HDL", $sformatf(
  //       "CFG mismatch!\n  DUT: data_bit_num=%s stop_bit_num=%s parity_en=%s parity_type=%s\n  CFG: data_bit_num=%0d stop_bit_num=%0d parity_en=%0d parity_type=%0d",
  //       uart_data_size_e'(got_db).name(), 
  //       uart_stop_size_e'(got_sb).name(), 
  //       uart_parity_mode_e'(got_pe).name(), 
  //       uart_parity_type_e'(got_pt).name(),
  //       cfg.data_bit_num, 
  //       cfg.stop_bit_num, 
  //       cfg.parity_en, 
  //       cfg.parity_type))
  //   end else begin
  //     cfg_ok++; 
  //     `uvm_info("SB_CFG_HDL", "CFG Backdoor check PASSED", UVM_HIGH)
  //   end
  // endtask
task automatic check_cfg_write_backdoor();
    bit [1:0] got_db;
    bit       got_sb, got_pe, got_pt;

    // 2. Khai báo biến kiểu enum để lưu giá trị sau khi ép kiểu 
    uart_data_size_e   db_enum;
    uart_stop_size_e   sb_enum;
    uart_parity_mode_e pe_enum;
    uart_parity_type_e pt_enum;

    // Đọc các tín hiệu nội bộ từ DUT bằng Backdoor
    void'(uvm_hdl_read(DUT_DATA_BIT_NUM_PATH, got_db));
    void'(uvm_hdl_read(DUT_STOP_BIT_NUM_PATH, got_sb));
    void'(uvm_hdl_read(DUT_PARITY_EN_PATH,    got_pe));
    void'(uvm_hdl_read(DUT_PARITY_TYPE_PATH,  got_pt));

    // Thực hiện ép kiểu ra biến tạm trước khi so sánh hoặc in log
    db_enum = uart_data_size_e'(got_db);
    sb_enum = uart_stop_size_e'(got_sb);
    pe_enum = uart_parity_mode_e'(got_pe);
    pt_enum = uart_parity_type_e'(got_pt);

    // 3. Kiểm tra sự khác biệt giữa DUT và cấu hình mong muốn (cfg) 
    if (got_db !== cfg.data_bit_num || got_sb !== cfg.stop_bit_num ||
        got_pe !== cfg.parity_en    || got_pt !== cfg.parity_type) begin
      
      cfg_bad++; // Tăng biến đếm lỗi
      
      `uvm_error("SB_CFG_HDL", $sformatf(
        "CFG mismatch!\n  DUT: data_bit_num=%s stop_bit_num=%s parity_en=%s parity_type=%s\n  CFG: data_bit_num=%0d stop_bit_num=%0d parity_en=%0d parity_type=%0d",
        db_enum.name(), 
        sb_enum.name(), 
        pe_enum.name(), 
        pt_enum.name(),
        cfg.data_bit_num.name(), 
        cfg.stop_bit_num.name(), 
        cfg.parity_en.name(), 
        cfg.parity_type.name()))
    end else begin
      cfg_ok++;
      `uvm_info("SB_CFG_HDL", "CFG Backdoor check PASSED", UVM_HIGH)
    end
  endtask


  function void report_phase(uvm_phase phase);
    `uvm_info("SB_REPORT",
      $sformatf("\n--- APB-UART Scoreboard ---\nCFG backdoor: OK=%0d BAD=%0d\nTX compare : MATCH=%0d MIS=%0d\nRX compare : MATCH=%0d MIS=%0d\n--------------------------",
        cfg_ok, cfg_bad, tx_match, tx_mis, rx_match, rx_mis),
      UVM_LOW)
  endfunction

endclass

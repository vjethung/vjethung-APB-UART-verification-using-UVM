interface uart_if(input logic clk, input logic rst_n);
    // rx uvc
    logic cts_n; 
    logic tx;
    // tx uvc
    logic rx; 
    logic rts_n;

    real bit_period_ns; 

    function void set_baud_rate(int baud);
        if (baud <= 0) baud = 115200;
        bit_period_ns = 1000000000.0 / baud;
    endfunction
    // 50 MHz -> Tclk = 20ns, Tbit_dut = 20ns x (50M/115200) = 20ns x 434 = 8680ns // 10^9 ns / 115200

    // Điều khiển CTS để cho phép hoặc chặn DUT gửi dữ liệu
    task automatic set_cts(input bit value);
        cts_n <= value; 
        // value = 0: Ready 
        // value = 1: Busy  
    endtask

    // Chờ tín hiệu RTS từ DUT trước khi UVC gửi dữ liệu vào
    task automatic wait_rts_active();
        wait(rts_n === 1'b0);
    endtask

    task automatic drive_bit(input logic val);
        rx <= val;
        #(bit_period_ns);
    endtask

    task automatic init_signals();
        rx    <= 1'b1; // Idle
        cts_n <= 1'b0; // Default DUT dc gửi (Ready)
    endtask
    
    task automatic wait_bit_periods(input int num);
        if (num > 0)
            repeat(num) #(bit_period_ns);
    endtask

    // Center Sampling
    // is_tx_line = 1: Lấy mẫu chân TX (DUT gửi ra)
    // is_tx_line = 0: Lấy mẫu chân RX (UVC gửi vào)
    task automatic sample_bit(output logic val, input bit is_tx_line);
        #(bit_period_ns / 2.0);

        if (is_tx_line) 
            val = tx; 
        else            
            val = rx;

        #(bit_period_ns / 2.0);
    endtask
endinterface
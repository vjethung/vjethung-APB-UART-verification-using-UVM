module uart (
    input  wire        clk,          
    input  wire        reset_n,      
    input  wire        pclk,         
    input  wire        preset_n,     
    input  wire        psel,         
    input  wire        penable,      
    input  wire        pwrite,       
    input  wire [3:0]  pstrb,        
    input  wire [11:0] paddr,        
    input  wire [31:0] pwdata,       
    input  wire        rx,           
    input  wire        cts_n,        
    output wire        pready,       
    output wire        pslverr,   
    output wire [31:0] prdata,       
    output wire        tx,           
    output wire        rts_n         
);

    // =========================================================================
    // 1. KHAI BÁO TÍN HIỆU NỘI (INTERNAL SIGNALS)
    // =========================================================================
    wire        clk_tx;
    wire        clk_rx;
    
    // Tín hiệu điều khiển và dữ liệu
    logic [7:0]  tx_data;
    wire  [7:0]  rx_data;
    logic [1:0]  data_bit_num;
    logic        stop_bit_num;
    logic        parity_en;
    logic        parity_type;
    logic        start_tx;
    
    // Tín hiệu trạng thái
    wire        tx_done;
    wire        rx_done;
    wire        parity_error;

    // Các biến trạng thái máy FSM và bộ đếm (Khai báo trước khi sử dụng)
    logic [1:0] tx_state;
    logic [2:0] tx_cnt_data;
    logic [1:0] tx_cnt_stop;
    logic [2:0] tx_limit_data;
    logic [1:0] tx_limit_stop;
    logic [7:0] tx_data_shift;
    logic       tx_out_logic;

    logic [1:0] rx_state;
    logic [3:0] rx_cnt_sample;
    logic [3:0] rx_cnt_data;
    logic [1:0] rx_cnt_stop;
    logic [7:0] rx_shift_logic;
    logic       rx_par_calc;
    logic       rx_par_received;
    logic [3:0] rx_limit_data;
    logic [1:0] rx_limit_stop;
    logic       rx_done_logic;
    logic       par_err_logic;

    // =========================================================================
    // 2. BỘ CHIA BAUDRATE (BAUDRATE GENERATOR)
    // =========================================================================
    logic [4:0] cnt_rx_div;
    logic [8:0] cnt_tx_div;

    // clk_rx (oversampling 16x)
    always @(posedge clk or negedge reset_n) begin
        if (~reset_n) cnt_rx_div <= 0;
        else if (cnt_rx_div == 27) cnt_rx_div <= 0;
        else cnt_rx_div <= cnt_rx_div + 1;
    end
    assign clk_rx = (cnt_rx_div == 0); // Đã sửa lỗi [cite]

    // clk_tx (baudrate tick)
    always @(posedge clk or negedge reset_n) begin
        if (~reset_n) cnt_tx_div <= 0;
        else if (cnt_tx_div == 434) cnt_tx_div <= 0;
        else cnt_tx_div <= cnt_tx_div + 1;
    end
    assign clk_tx = (cnt_tx_div == 0); // Đã sửa lỗi [cite]

    // =========================================================================
    // 3. LOGIC TRUYỀN (TX LOGIC) - Tuân thủ Hình 3
    // =========================================================================
    always @(*) begin
        case (data_bit_num)
            2'b00: begin tx_limit_data = 3'd4; tx_data_shift = tx_data[4:0]; end
            2'b01: begin tx_limit_data = 3'd5; tx_data_shift = tx_data[5:0]; end
            2'b10: begin tx_limit_data = 3'd6; tx_data_shift = tx_data[6:0]; end
            2'b11: begin tx_limit_data = 3'd7; tx_data_shift = tx_data[7:0]; end
            default: begin tx_limit_data = 3'd7; tx_data_shift = tx_data[7:0]; end
        endcase
        
        case ({parity_en, stop_bit_num})
            2'b00: tx_limit_stop = 2'd0; // 1 stop bit
            2'b01: tx_limit_stop = 2'd1; // 2 stop bits
            2'b10: tx_limit_stop = 2'd1; // 1 parity + 1 stop
            2'b11: tx_limit_stop = 2'd2; // 1 parity + 2 stops
            default: tx_limit_stop = 2'd0;
        endcase
    end

    always @(posedge clk or negedge reset_n) begin
        if (~reset_n) begin
            tx_state <= 2'b00;
            tx_cnt_data <= 0; tx_cnt_stop <= 0;
        end else if (clk_tx) begin
            case (tx_state)
                2'b00: if (start_tx && !cts_n) tx_state <= 2'b01;
                2'b01: tx_state <= 2'b10;
                2'b10: if (tx_cnt_data == tx_limit_data) tx_state <= 2'b11;
                2'b11: if (tx_cnt_stop == tx_limit_stop) tx_state <= 2'b00;
            endcase
            
            if (tx_state == 2'b00) begin 
                tx_cnt_data <= 0; 
                tx_cnt_stop <= 0; 
            end else if (tx_state == 2'b10) begin
                tx_cnt_data <= tx_cnt_data + 1;
            end else if (tx_state == 2'b11) begin
                tx_cnt_stop <= tx_cnt_stop + 1;
            end
        end
    end

    always @(*) begin
        case (tx_state)
            2'b00: tx_out_logic = 1'b1;
            2'b01: tx_out_logic = 1'b0;
            2'b10: tx_out_logic = tx_data[tx_cnt_data];
            2'b11: if (parity_en && tx_cnt_stop == 0)
                       tx_out_logic = (parity_type ? (^tx_data_shift) : (~^tx_data_shift));
                   else tx_out_logic = 1'b1;
            default: tx_out_logic = 1'b1;
        endcase
    end
    assign tx = tx_out_logic;

    logic tx_done_logic;
    always @(posedge clk or negedge reset_n) begin
        if (~reset_n) tx_done_logic <= 1;
        else if (clk_tx) tx_done_logic <= ((tx_state == 2'b11 && tx_cnt_stop == tx_limit_stop) || tx_state == 2'b00);
    end
    assign tx_done = tx_done_logic;

    // =========================================================================
    // 4. LOGIC NHẬN (RX LOGIC) - Tuân thủ Hình 4
    // =========================================================================
    always @(*) begin
        case (data_bit_num)
            2'b00: rx_limit_data = 4'd4;
            2'b01: rx_limit_data = 4'd5;
            2'b10: rx_limit_data = 4'd6;
            2'b11: rx_limit_data = 4'd7;
            default: rx_limit_data = 4'd7;
        endcase
        case ({parity_en, stop_bit_num})
            2'b00: rx_limit_stop = 2'd0;
            2'b01: rx_limit_stop = 2'd1;
            2'b10: rx_limit_stop = 2'd1;
            2'b11: rx_limit_stop = 2'd2;
            default: rx_limit_stop = 2'd0;
        endcase
    end

    always @(posedge clk or negedge reset_n) begin
        if (~reset_n) begin
            rx_state <= 2'b11;
            rx_cnt_sample <= 0; rx_cnt_data <= 0; rx_cnt_stop <= 0; rx_par_calc <= 0;
            rx_shift_logic <= 8'b0; rx_par_received <= 0;
        end else begin
            case (rx_state)
                2'b11: begin // IDLE
                    rx_cnt_sample <= 0;
                    rx_par_calc <= 0;
                    if (!rx) rx_state <= 2'b00;
                end
                2'b00: if (clk_rx) begin // START BIT
                    rx_cnt_sample <= rx_cnt_sample + 1;
                    if (rx_cnt_sample == 15) rx_state <= 2'b01;
                end
                2'b01: if (clk_rx) begin // DATA BITS
                    rx_cnt_sample <= rx_cnt_sample + 1;
                    if (rx_cnt_sample == 8) begin
                        rx_shift_logic[rx_cnt_data] <= rx;
                        rx_cnt_data <= rx_cnt_data + 1;
                        rx_par_calc <= rx_par_calc ^ rx;
                    end
                    if (rx_cnt_sample == 15 && rx_cnt_data == (rx_limit_data + 1)) rx_state <= 2'b10;
                end
                2'b10: if (clk_rx) begin // PARITY/STOP BITS
                    rx_cnt_sample <= rx_cnt_sample + 1;
                    if (rx_cnt_sample == 8) begin
                        if (parity_en && rx_cnt_stop == 0) rx_par_received <= rx;
                        rx_cnt_stop <= rx_cnt_stop + 1;
                    end
                    if (rx_cnt_sample == 15 && rx_cnt_stop == rx_limit_stop) rx_state <= 2'b11;
                end
            endcase
            if (rx_state != 2'b01 && rx_state != 2'b10) begin 
                rx_cnt_data <= 0;
                rx_cnt_stop <= 0; 
            end
            if (clk_rx && rx_cnt_sample == 15) rx_cnt_sample <= 0;
        end
    end

    always @(*) begin
        case (rx_state)
            2'b11, 2'b00: rx_done_logic = 1'b1;
            2'b01: rx_done_logic = 1'b0;
            2'b10: rx_done_logic = (rx_cnt_sample == 15 && rx_cnt_stop == rx_limit_stop);
            default: rx_done_logic = 1'b0;
        endcase
        par_err_logic = (rx_state == 2'b10 && parity_en) ?
                        (parity_type ? (rx_par_calc != rx_par_received) : (~rx_par_calc != rx_par_received)) : 1'b0;
    end
    assign rx_data = rx_shift_logic;
    assign rx_done = rx_done_logic;
    assign parity_error = par_err_logic;
    assign rts_n = ~rx_done;

    // =========================================================================
    // 5. GIAO DIỆN APB (APB INTERFACE)
    // =========================================================================
    logic [7:0] rx_data_sync;
    logic tx_done_sync, rx_done_sync, par_err_sync;
    logic pready_logic;
    logic [31:0] prdata_logic;

    always @(posedge clk or negedge reset_n) begin
        if (~reset_n) begin
            rx_data_sync <= 0;
            tx_done_sync <= 1; rx_done_sync <= 0; par_err_sync <= 0;
        end else begin
            rx_data_sync <= rx_data;
            tx_done_sync <= tx_done;
            rx_done_sync <= rx_done; par_err_sync <= parity_error;
        end
    end

    always @(posedge clk or negedge reset_n) begin
        if (~reset_n) begin
            tx_data <= 0;
            data_bit_num <= 2'b00; stop_bit_num <= 0;
            parity_en <= 0; parity_type <= 0; start_tx <= 0;
        end else begin
            if (psel && penable && pwrite) begin
                case (paddr)
                    12'h000: if (pstrb[0]) tx_data <= pwdata[7:0];
                    12'h008: if (pstrb[0]) begin
                                data_bit_num <= pwdata[1:0];
                                stop_bit_num <= pwdata[2];
                                parity_en <= pwdata[3]; 
                                parity_type <= pwdata[4];
                             end
                    12'h00C: if (pstrb[0]) start_tx <= pwdata[0];
                    default: ;
                endcase
            end else begin
                start_tx <= 0;
            end
        end
    end

    always @(*) begin
        prdata_logic = 0;
        if (psel && penable && !pwrite) begin
            case (paddr)
                12'h000: prdata_logic = {24'b0, tx_data};
                12'h004: prdata_logic = {24'b0, rx_data_sync};
                12'h008: prdata_logic = {27'b0, parity_type, parity_en, stop_bit_num, data_bit_num};
                12'h00C: prdata_logic = {31'b0, start_tx};
                12'h010: prdata_logic = {29'b0, par_err_sync, rx_done_sync, tx_done_sync};
                default: prdata_logic = 32'b0;
            endcase
        end
    end

    assign prdata = prdata_logic;
    assign pready = psel;
    assign pslverr = (psel && penable && pwrite && (paddr == 12'h004 || paddr == 12'h010)) ? 1'b1 : 1'b0;

endmodule
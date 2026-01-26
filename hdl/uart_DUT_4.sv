module uart_DUT_4
    #(
        parameter   BAUD_RATE       = 115200        ,
        parameter   FREQUENCY_CLK   = 50000000          //f = 50MHz

    ) 
    (
        input                       clk             ,
        input                       reset_n         ,  
        input                       pclk            ,
        input                       preset_n         ,
        input                       psel            ,
        input                       penable         ,
        input                       pwrite          ,
        input       [3:0]           pstrb           ,
        input       [11:0]          paddr           ,
        input       [31:0]          pwdata          ,
        output      [31:0]          prdata          ,
        output                      pready          ,
        output                      pslverr         ,
        output                      tx              , 
        output                      rts_n           ,
        input                       rx              ,
        input                       cts_n

    );
        localparam                      baud_rate           = BAUD_RATE     ;
        localparam                      frequency           = FREQUENCY_CLK ;
        // signal of apb_slave, register_block
        logic          [31:0]           rdata                               ;
        logic          [11:0]           waddr                               ;
        logic          [31:0]           wdata                               ;
        logic                           pwrite_o                            ;
        logic          [11:0]           raddr                               ;
        logic                           radderr                             ;
        logic                           wadderr                             ;

        // signal of tx and rx
        logic          [7:0]            tx_data                             ;
        logic          [1:0]            data_bit_num                        ;
        logic                           stop_bit_num                        ;
        logic                           parity_en                           ;
        logic                           parity_type                         ;
        logic                           start_tx                            ;


        logic                           start_tx_re_cfg                     ;
        logic                           tx_done                             ;
        logic                           rx_done                             ;
        logic          [7:0]            rx_data                             ;
        logic                           parity_error                        ;
        logic                           host_read_data                      ;
    apb_slave apb_slave (
            .clk                        ( clk            )                  ,
            .reset_n                    ( reset_n        )                  ,
            .pclk                       ( clk            )                  ,
            .presetn                    ( preset_n       )                  ,
            .psel                       ( psel           )                  ,
            .penable                    ( penable        )                  ,
            .pwrite                     ( pwrite         )                  ,
            .pstrb                      ( pstrb          )                  ,
            .paddr                      ( paddr          )                  ,
            .pwdata                     ( pwdata         )                  ,
            .wadderr                    ( wadderr        )                  ,
            .radderr                    ( radderr        )                  ,
            .pready                     ( pready         )                  ,
            .pslverr                    ( pslverr        )                  ,
            .prdata                     ( prdata         )                  ,
            .waddr                      ( waddr          )                  ,
            .wdata                      ( wdata          )                  ,
            .pwrite_o                   ( pwrite_o       )                  ,
            .raddr                      ( raddr          )                  ,
            .rdata                      ( rdata          )                  ,
            .host_read_data             ( host_read_data )
        );

    register_block register_block (
        .clk                            ( clk                )              ,
        .reset_n                        ( reset_n            )              ,
        .waddr                          ( waddr              )              ,
        .raddr                          ( raddr              )              ,
        .wdata                          ( wdata              )              ,
        .pwrite                         ( pwrite_o           )              ,
        .rdata                          ( rdata              )              ,
        .wadderr                        ( wadderr            )              ,
        .radderr                        ( radderr            )              ,
        .tx_done                        ( tx_done            )              ,
        .rx_done                        ( rx_done            )              ,
        .rx_data                        ( rx_data            )              ,
        .parity_error                   ( parity_error       )              ,
        .tx_data                        ( tx_data            )              ,
        .data_bit_num                   ( data_bit_num       )              ,
        .stop_bit_num                   ( stop_bit_num       )              ,
        .parity_en                      ( parity_en          )              ,
        .parity_type                    ( parity_type        )              ,
        .start_tx                       ( start_tx           )              ,
        .start_tx_re_cfg                ( start_tx_re_cfg    )
        
        );

    uart_tx #(
        .BAUD_RATE                      ( baud_rate         )               ,
        .FREQUENCY_CLK                  ( frequency         )
    ) tx_dut (
        .clk                            ( clk                )              ,
        .reset_n                        ( reset_n            )              ,
        .tx_data                        ( tx_data            )              ,
        .data_bit_num                   ( data_bit_num       )              ,
        .stop_bit_num                   ( stop_bit_num       )              ,
        .parity_en                      ( parity_en          )              ,
        .parity_type                    ( parity_type        )              ,
        .start_tx                       ( start_tx           )              ,
        .tx_done                        ( tx_done            )              ,
        .tx                             ( tx                 )              ,
        .cts_n                          ( cts_n              )              ,
        .start_tx_re_cfg                ( start_tx_re_cfg    )
        );

    uart_rx #(
        .BAUD_RATE                      ( baud_rate         )               ,
        .FREQUENCY_CLK                  ( frequency         )
    ) rx_dut (
        .clk                            ( clk                )              ,
        .reset_n                        ( reset_n            )              ,
        .data_bit_num                   ( data_bit_num       )              ,
        .stop_bit_num                   ( stop_bit_num       )              ,
        .parity_en                      ( parity_en          )              ,
        .parity_type                    ( parity_type        )              ,
        .parity_error                   ( parity_error       )              ,
        .rx_data                        ( rx_data            )              ,
        .rx_done                        ( rx_done            )              ,
        .rx                             ( rx                 )              ,
        .rts_n                          ( rts_n              )              ,
        .host_read_data                 ( host_read_data     )
    );
endmodule

module apb_slave
    (   
    input                            clk             ,
    input                            reset_n         ,
    input                            pclk            ,
    input                            presetn         ,
    input                            psel            ,
    input                            penable         ,
    input                            pwrite          ,
    input       [3:0]                pstrb           ,
    input       [11:0]               paddr           ,
    input       [31:0]               pwdata          ,

    input                            wadderr         ,
    input                            radderr         ,
    output                           pready          ,
    output                           pslverr         ,
    output      [31:0]               prdata          ,

    // output to register block
    output      [11:0]               waddr           ,
    output      [31:0]               wdata           ,
    output                           pwrite_o        ,
    output      [11:0]               raddr           ,
    //input from register block
    input       [31:0]               rdata           ,
    output logic                     host_read_data
    );

    //enum logic [1:0] {IDLE, WRITE, READ} curr_state, next_state;

    logic       [31:0]               reg_wdata       ;
    logic       [11:0]               reg_waddr       ;
    logic       [11:0]               reg_raddr       ;
    logic       [31:0]               reg_rdata       ;
    logic                            reg_pready      ;

    logic                            reg_pwrite_o    ;
    

    always_comb begin
        reg_pready       = ( ~penable  & ~psel               )? 1'b0  : 1'b1   ;
        reg_waddr        = (  psel     &  penable   & pwrite )? paddr : 12'h0  ;
        reg_wdata        =    pstrb[0] ?  pwdata                      : 'hz    ;
        reg_raddr        = (  psel     &  penable   & ~pwrite)? paddr : 12'h0  ;
        reg_rdata        = (  psel     &  penable   & ~pwrite)? rdata : 'h0    ;
        host_read_data   = (  psel     &  penable   & ~pwrite)? 1'b1  : 1'b0   ;
        reg_pwrite_o     = (  psel     &  penable            )? pwrite: 1'b0   ;
    end

    assign prdata     =     reg_rdata             ;
    assign waddr      =     reg_waddr             ;
    assign wdata      =     reg_wdata             ;
    assign raddr      =     reg_raddr             ;
    assign pwrite_o   =     ~reg_pwrite_o         ; // ERROR
    assign pready     =     reg_pready            ;
    assign pslverr    =  ( wadderr & radderr )   ;
    
endmodule

module register_block (
    input                                   clk                 ,
    input                                   reset_n             ,
    //apb slave
    input       logic   [11:0]              waddr               , 
    input               [11:0]              raddr               ,
    input       logic   [31:0]              wdata               ,
    input       logic                       pwrite              ,

    output      logic   [31:0]              rdata               ,
    output      logic                       wadderr             ,
    output      logic                       radderr             ,

    // uart_core
    input       logic                       tx_done             ,
    input       logic                       rx_done             ,
    input       logic   [7:0]               rx_data             ,
    input       logic                       parity_error        ,
    input                                   start_tx_re_cfg     ,

    output      logic   [7:0]               tx_data             ,
    output      logic   [1:0]               data_bit_num        ,
    output      logic                       stop_bit_num        ,
    output      logic                       parity_en           ,
    output      logic                       parity_type         ,
    output      logic                       start_tx
    );
    logic               [31:0]              tx_data_reg         ;
    logic               [31:0]              rx_data_reg         ;
    logic               [31:0]              cfg_reg             ;
    logic               [31:0]              ctrl_reg            ;
    logic               [31:0]              stt_reg             ; 
    //apb side

    always_ff @(posedge clk, negedge reset_n) begin
            if (!reset_n) begin
                tx_data_reg <= 0;
                rx_data_reg <= 0;
                cfg_reg <= 0;
                ctrl_reg <= 0;  
                wadderr <= 0;
            end 
            else begin
                if(pwrite) begin
                    case (waddr) 
                        12'h000: begin
                            tx_data_reg <= wdata;   
                        end
                        12'h008: begin
                            cfg_reg <= wdata;  
                        end
                        12'h00c: begin
                            ctrl_reg <= wdata;  
                        end
                        default: begin
                            wadderr <= 1'b1;
                        end
                    endcase 
                end
                else begin
                    tx_data_reg <= tx_data_reg;
                end
                if(start_tx_re_cfg) begin
                        ctrl_reg <= 'h0;
                end 
                rx_data_reg <= rx_data;
            end
        end
    always_comb  begin
        if(~pwrite) begin
                case (raddr)
                    12'h000: rdata = tx_data_reg;
                    12'h004: rdata = rx_data_reg;
                    12'h008: rdata = cfg_reg;
                    12'h00c: rdata = ctrl_reg;
                    12'h010: rdata = stt_reg;
                    default: radderr = 1'b1;
                endcase
        end 
        else begin
            radderr = 0;
            rdata = 'h0;
        end
    end


    //uart side
    always_ff @(posedge clk, negedge reset_n) begin
        if(~reset_n)begin
            stt_reg[0] <= 1'b1;
            stt_reg[31:1] <= 'h0;
        end else begin
            stt_reg[0] <= tx_done;
            stt_reg[1] <= rx_done;
            stt_reg[2] <= parity_error;
        end
    end

    always_comb begin
            tx_data         = tx_data_reg [7:0]   ;
            data_bit_num    = cfg_reg     [1:0]   ;
            stop_bit_num    = cfg_reg     [2]     ;
            parity_en       = cfg_reg     [3]     ;
            parity_type     = cfg_reg     [4]     ;
            start_tx        = ctrl_reg    [0]     ;
    end
endmodule

module bclk_gen
    #(
        parameter   BAUD_RATE       = 115200        ,
        parameter   FREQUENCY_CLK   = 50000000          //f = 50MHz

    )
    (
        input                           clk         ,
        input                           reset_n     ,
        input                           start       ,
        output                          Bclk
    ); 
    localparam                      divisor             = FREQUENCY_CLK/(BAUD_RATE*16)          ;
    logic     [11:0]                count                                                       ;
    logic     [11:0]                count_next                                                  ;
    logic                           bclk                                                        ;      
    logic                           bclk_next                                                   ;
    always_comb begin  
        if(count == divisor-1) begin
            count_next =0;
            bclk_next = 1;
        end 
        else begin
            if(~start) begin
                count_next = count +1;
                bclk_next = 0;
            end 
            else begin
                count_next = 0; 
                bclk_next  = 0;
            end        
        end
    end
    always_ff @(posedge clk, negedge reset_n)begin
        if(~reset_n) begin
            bclk <= 0;
            count <= 0;
        end 
        else begin
            count <= count_next;
            bclk <= bclk_next;
        end
    end
    assign Bclk = bclk;
endmodule 

module uart_rx
    #(
        parameter   BAUD_RATE       = 115200        ,
        parameter   FREQUENCY_CLK   = 50000000          //f = 50MHz
    )(
    
    input                                   clk                     ,
    input                                   reset_n                 ,
    //apb side
    input               [1:0]               data_bit_num            ,
    input                                   stop_bit_num            ,
    input                                   parity_en               ,
    input                                   parity_type             ,

    output    logic                         parity_error            ,
    output    logic     [7:0]               rx_data                 ,
    output    logic                         rx_done                 ,
    input                                   host_read_data          ,
    //peripheral side
    input                                   rx                      ,
    output    logic                         rts_n
    );
    enum logic [2:0]  {IDLE, ST_START, ST_DATA, ST_PRT, STOP_BIT } state, next_state    ;
    logic               [3:0]               count_data                                  ;
    logic               [1:0]               count_stop                                  ;
    logic               [3:0]               count                                       ;
    logic               [3:0]               count_next                                  ;
    logic               [4:0]               baud                                        ;
    logic               [4:0]               baud_next                                   ;
    logic               [7:0]               rx_reg                                      ; 
    logic               [7:0]               rx_reg_next                                 ;
    logic                                   parity_bit                                  ;
    logic                                   count_en                                    ;
    logic                                   bit_done                                    ;
    logic               [1:0]               reg_stop_bit                                ;
    logic               [1:0]               reg_stop_bit_next                           ;
    logic               [1:0]               count_stop_bit                              ;
    logic               [1:0]               count_stop_bit_next                         ;
    logic                                   Bclk                                        ;
    logic                                   start_bclk                                  ;

    bclk_gen #(
        .BAUD_RATE                         ( BAUD_RATE     )                               ,
        .FREQUENCY_CLK                     ( FREQUENCY_CLK )
    ) bclk_gen(
        .clk                               ( clk           )                               ,
        .reset_n                           ( reset_n       )                               ,
        .Bclk                              ( Bclk          )                               ,
        .start                             ( start_bclk    )
    );
    always_comb begin
        case (data_bit_num)
            2'b00: count_data = 4'd5;
            2'b01: count_data = 4'd6;
            2'b10: count_data = 4'd7;
            2'b11: count_data = 4'd8;
            default : count_data = 4'd5;
        endcase
        
        case (stop_bit_num)
            1'b0: count_stop = 2'd1;
            1'b1: count_stop = 2'd2;
            default: count_stop = 2'd1;
        endcase
        end    

    always_comb begin
        count_next = count;
        rx_reg_next = rx_reg;
        count_stop_bit_next = count_stop_bit;
        reg_stop_bit_next = reg_stop_bit;
        next_state = state;
        parity_error = 1'b0;
        case (state) 
            IDLE: begin
                start_bclk = 1'b1;
                if (host_read_data) begin 
                    rx_done = 1'b0;
                    rts_n = 1'b0;
                end else begin 
                end
                if(rx == 0) begin
                    next_state = ST_START;
                end
                else begin
                    next_state = IDLE;
                end
            end
            ST_START: begin
                start_bclk = 1'b0;
                count_en = 1'b1;
                rx_reg_next = 'h0;
                if(bit_done) begin
                    count_en = 1'b0;
                    next_state = ST_DATA;   
                end  
                else begin
                    next_state = ST_START;
                end        
            end
            ST_DATA:  begin
            start_bclk = 1'b0;
            count_next = count;
            count_en = 1'b1;
            if(baud_next == 8) begin
                rx_reg_next = rx_reg;
                rx_reg_next[count] = rx;
            end
            if(bit_done) begin
            //  rx_reg_next = rx_reg << 1;
                count_en =1'b0;
                if (count == count_data-1) begin 
                    if(parity_en) begin
                        next_state = ST_PRT;
                    end else begin
                        next_state = STOP_BIT;
                    end 
                    rx_data = rx_reg;
                    count_next = 4'h0;
                end
                else begin 
                    next_state = ST_DATA;
                    count_next = count + 1;
                    rx_done =1'b0;
                end

            end else begin
                next_state = ST_DATA;
                rx_done = 1'b0;
            end
            end
                
            ST_PRT: begin
                start_bclk = 1'b0;
                parity_bit = rx;
                count_en = 1'b1;
                if (bit_done) begin
                    next_state = STOP_BIT;
                    count_en = 1'b0;
                end
                else begin 
                    next_state = ST_PRT; 
                end
                
            end
            STOP_BIT:  begin
                start_bclk = 1'b0;
                count_en = 1'b1;
                reg_stop_bit_next = reg_stop_bit;
                reg_stop_bit_next[0] = rx;
            if(bit_done) begin
                reg_stop_bit_next = reg_stop_bit << 1;
                count_en = 1'b0;
                if (count_stop_bit == count_stop) begin 
                    next_state = IDLE;
                    count_stop_bit_next = 'h0;
                    rx_done = 1'b1;
                    rts_n = 1'b1;
                end
                else begin 
                    next_state = STOP_BIT;
                    count_stop_bit_next = count_stop_bit +1; 
                end
            end else begin
                next_state = STOP_BIT;
            end 
            case ({parity_en, parity_type})
                2'b10: parity_error = ~((^rx_reg) ^ parity_bit) ;
                2'b11: parity_error =  (^rx_reg) ^ parity_bit   ;
                default : parity_error = 1'b0;
            endcase
            end
            default: begin
                parity_bit  =    1'b0;
                rx_done     =    1'b0;
                rx_data     =     'h0;
                rts_n       =    1'b0;  
                count_en     =    1'b0;
                start_bclk  =    1'b1;
                
            end
        endcase
    end

    always_ff @(posedge clk, negedge reset_n) begin
            if (~reset_n) begin 
                state <= IDLE;
                rx_reg <= 'h0;
                reg_stop_bit <= 'h0;
            end
            else begin
                state <= next_state;
                rx_reg <= rx_reg_next;
                reg_stop_bit <= reg_stop_bit_next;
            end
        end

        always_ff @(posedge clk, negedge reset_n) begin
            if(~reset_n) begin
                count <=0;
                count_stop_bit <= 0;
            end
            else begin
                count <= count_next;
                count_stop_bit <= count_stop_bit_next;
            end
        end

    always_comb begin
        if(count_en) begin
            if(Bclk) begin
            baud_next = baud +1;
            end else begin
                baud_next = baud;
            end
        end else begin
            baud_next = 0;
        end
    end


    always_ff @(posedge clk, negedge reset_n) begin
        if(~reset_n) begin
            baud <= 0;
            bit_done <= 0;
        end 
        else if(count_en) begin
                if(baud == 16 ) begin
                    bit_done <= 1'b1;
                    baud <=0;
                end else begin
                    baud <= baud_next;
                    bit_done = 1'b0;
            end 
        end else begin 
            bit_done = 1'b0;
        end
        end
endmodule

module uart_tx 
    #(
        parameter BAUD_RATE     = 115200,
        parameter FREQUENCY_CLK = 50000000
    )
    (
    input                         clk                   ,
    input                         reset_n               ,
    input   [7:0]                 tx_data               ,
    input   [1:0]                 data_bit_num          ,
    input                         stop_bit_num          ,
    
    input                         parity_en             ,
    input                         parity_type           ,
    input                         start_tx              ,
    input                         cts_n                 ,
    output logic                  tx_done               ,
    output                        tx                    ,
    output                        start_tx_re_cfg
    
    );

    localparam                       even =1'b1             ;
    localparam                       odd = 1'b0             ;


    logic                            Bclk                   ;
    logic                            start_bclk             ;
    logic       [3:0]                data_bit_target        ;
    logic                            parity_bit             ;
    logic       [4:0]                count                  ;
    logic       [4:0]                count_next             ;
    logic                            bit_done               ;
    logic                            count_en               ;
    logic                            tx_o                   ;
    logic                            TX_DONE                ;
    logic        [3:0]               count_bit              ;
    logic        [3:0]               count_bit_next         ;
    logic        [7:0]               reg_data_bit           ;
    logic        [7:0]               reg_data_bit_next      ;
    logic                            start_tx_reg           ;

    enum logic [2:0] {IDLE, START_BIT, DATA_BIT, PARITY_BIT, 
                    STOP_BIT_FIRST, STOP_BIT_SECOND  } curr_state, next_state;

    bclk_gen #(
        .BAUD_RATE                         ( BAUD_RATE     )                               ,
        .FREQUENCY_CLK                     ( FREQUENCY_CLK )
    ) bclk_gen(
        .clk                               ( clk           )                               ,
        .reset_n                           ( reset_n       )                               ,
        .Bclk                              ( Bclk          )                               ,
        .start                             ( start_bclk    )
    );
    always_comb begin : PROCESS_DATABIT_NUM_AND_PARITY_BIT
        data_bit_target = 3'h0;
        parity_bit = 1'b0;
        case(data_bit_num)
            2'b00:begin
                if(parity_en) begin
                    if(parity_type == even) parity_bit = ^tx_data[4:0];
                    else parity_bit = ~^tx_data[4:0];  
                end
                data_bit_target = 4'd5;
            end
            2'b01: begin
                if(parity_en) begin
                    if(parity_type == even) parity_bit = ^tx_data[5:0];
                    else parity_bit = ~^tx_data[5:0];
                end
                data_bit_target = 4'd6;
            end
            2'b10:begin
                if(parity_en) begin
                    if(parity_type == even) parity_bit = ^tx_data[6:0];
                    else parity_bit = ~^tx_data[6:0];
                end
                data_bit_target = 4'd7;
            end
            2'b11:begin
                if(parity_en) begin
                    if(parity_type == even) parity_bit = ^tx_data[7:0];
                    else parity_bit = ~^tx_data[7:0];
                end
                data_bit_target = 4'd8;
            end
            default: begin
                data_bit_target = 3'h0;
                parity_bit = 1'b0;
            end
        endcase  
    end
    always_comb begin
        if(count_en) begin
            if(Bclk) begin
                count_next = count +1;
            end else begin
                count_next = count;
            end
        end else begin
            count_next = 0;
        end
        
    end

    always_ff @( posedge clk, negedge reset_n ) begin : GENARTE_BAUTE
        if(~reset_n) begin
            count <= 0;
            bit_done <= 0;
        end else 
        if(count_en) begin
            if(curr_state == IDLE) begin 
                count <= 0;
            end 
            else begin 
            if(count == 16 ) begin
                bit_done <= 1'b1;
                count <=0;
            end 
            else begin
                count <= count_next;
                bit_done = 1'b0;
            end 
            end 
        end 
        else begin

        end
    end


    always_comb begin : PROCESS_NEXT_STATE
        reg_data_bit_next = reg_data_bit;
        count_bit_next = count_bit;
        
        case(curr_state)
            IDLE: begin
                tx_o =1'b1;
                start_bclk = 1'b1;
                if(start_tx) begin
                        TX_DONE = 1'b0;
                        if(~cts_n) begin
                            next_state = START_BIT;
                        end
                        else begin
                            next_state  = IDLE;
                        end
                end else begin
                    start_tx_reg = 1'b0;
                    next_state = IDLE;
                    TX_DONE = 1'b1;
                end
            end
            START_BIT: begin
                tx_o = 1'b0;
                count_en = 1'b1;
                start_tx_reg = 1'b1;
                start_bclk = 1'b0;
                if(bit_done) begin
                    next_state = DATA_BIT;
                    reg_data_bit_next = tx_data;
                end
                else begin
                    next_state = START_BIT;
                    reg_data_bit_next = 8'b0;
                end
            end
            DATA_BIT: begin
                tx_o = reg_data_bit[0];
                count_en = 1'b1;
                reg_data_bit_next = reg_data_bit;
                start_bclk = 1'b0;
                if(bit_done) begin
                    if(count_bit == data_bit_target-1) begin
                        if(parity_en) next_state = PARITY_BIT;
                        else  next_state = STOP_BIT_FIRST;
                    end 
                    else begin
                        count_bit_next = count_bit +1;
                        next_state = DATA_BIT;
                    end
                    reg_data_bit_next = reg_data_bit >>1;
                end 
                else begin
                    next_state = DATA_BIT;
                    count_en = 1'b1;
                    reg_data_bit_next = reg_data_bit;
                end
            end
            PARITY_BIT: begin
                tx_o = parity_bit;
                count_en = 1'b1;
                start_bclk = 1'b0;
                if(bit_done) begin
                        next_state = STOP_BIT_FIRST;  
                end 
                else begin
                    next_state = PARITY_BIT;
                end
            end
            STOP_BIT_FIRST: begin
                tx_o = 1'b1;
                count_en = 1'b1;
                start_bclk = 1'b0;
                if(bit_done) begin
                    if(stop_bit_num) begin
                        next_state = STOP_BIT_SECOND;
                    end else begin
                        next_state = IDLE;
                        TX_DONE = 1'b1;  
                    end
                end 
                else begin
                    next_state = STOP_BIT_FIRST;
                end
            end
            STOP_BIT_SECOND: begin
                tx_o = 1'b1; 
                count_en = 1'b1;
                start_bclk = 1'b0;
                if(bit_done) begin
                    next_state = IDLE;
                    TX_DONE = 1'b1;
                
                end 
                else begin
                    next_state = STOP_BIT_SECOND;
                end
            end
            default begin
                start_tx_reg     =   1'b0   ;
                next_state       =   IDLE   ;
                TX_DONE          =   1'b1   ;
                tx_o             =   1'b1   ;
                count_en         =   1'b0   ;
                start_bclk       =   1'b1   ;
            end
        endcase    
    end

    always_ff @(posedge clk, negedge reset_n ) begin : PROCESS_CURR_STATE
        if(~reset_n) begin
            curr_state <= IDLE;
            count_bit <= 0;

        end else begin
            curr_state <= next_state;
            
        end
        if(curr_state == IDLE) begin 
            count_bit <= 0;
            
        end
        else count_bit <= count_bit_next; 
    end

    always_ff @( posedge clk, negedge reset_n ) begin : PROCESS_DATA_OUT
        if(~reset_n) begin
            reg_data_bit <= tx_data;

        end  else begin
            reg_data_bit <= reg_data_bit_next;
        end   
    end

    always_ff @(posedge clk, negedge reset_n) begin
        if(~reset_n) tx_done <= 0;
        else tx_done <= TX_DONE;
    end

    assign tx = tx_o;
    assign start_tx_re_cfg =start_tx_reg;
endmodule

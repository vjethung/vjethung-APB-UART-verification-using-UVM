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
   // reg_pwrite_o     = pwrite;
end
assign prdata     =     reg_rdata             ;
assign waddr      =     reg_waddr             ;
assign wdata      =     reg_wdata             ;
assign raddr      =     reg_raddr             ;
assign pwrite_o   =     reg_pwrite_o          ;
assign pready     =     reg_pready            ;
assign pslverr    =  ( wadderr & radderr )   ;


endmodule
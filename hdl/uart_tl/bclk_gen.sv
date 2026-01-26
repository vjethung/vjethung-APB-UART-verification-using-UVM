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
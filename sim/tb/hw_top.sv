module hw_top;
    logic   clock;
    logic   reset_n;

    apb_if aif(clock, reset_n);
    uart_if uif(clock, reset_n);

    // uart dut(
    //     .clk(clock),
    //     .reset_n(reset_n),
    //     .pclk(clock),
    //     .preset_n(reset_n),
    //     .psel(aif.psel),
    //     .penable(aif.penable),
    //     .pwrite(aif.pwrite),
    //     .pstrb(aif.pstrb),
    //     .paddr(aif.paddr),
    //     .pwdata(aif.pwdata),
    //     .pready(aif.pready),
    //     .pslverr(aif.pslverr),
    //     .prdata(aif.prdata),
    //     .rx(uif.rx),
    //     .cts_n(uif.cts_n),
    //     .tx(uif.tx),
    //     .rts_n(uif.rts_n)
    // );

    uart_DUT_4 #() dut(
        .clk(clock),
        .reset_n(reset_n),
        .pclk(clock),
        .preset_n(reset_n),
        .psel(aif.psel),
        .penable(aif.penable),
        .pwrite(aif.pwrite),
        .pstrb(aif.pstrb),
        .paddr(aif.paddr),
        .pwdata(aif.pwdata),
        .pready(aif.pready),
        .pslverr(aif.pslverr),
        .prdata(aif.prdata),
        .rx(uif.rx),
        .cts_n(uif.cts_n),
        .tx(uif.tx),
        .rts_n(uif.rts_n)
    );


    // Tần số 50MHz -> Chu kỳ T = 20ns.
    initial begin
        clock = 0;
        forever #10 clock = ~clock;
    end

    initial begin
        reset_n = 0;        // Bắt đầu ở trạng thái Reset
        #100 reset_n = 1;   // Nhả reset sau 100ns để hệ thống bắt đầu chạy
    end
endmodule
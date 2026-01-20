onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate -group DUT /hw_top/dut/clk
add wave -noupdate -group DUT /hw_top/dut/reset_n
add wave -noupdate -group DUT /hw_top/dut/pclk
add wave -noupdate -group DUT /hw_top/dut/preset_n
add wave -noupdate -group DUT /hw_top/dut/psel
add wave -noupdate -group DUT /hw_top/dut/penable
add wave -noupdate -group DUT /hw_top/dut/pwrite
add wave -noupdate -group DUT /hw_top/dut/pstrb
add wave -noupdate -group DUT /hw_top/dut/paddr
add wave -noupdate -group DUT /hw_top/dut/pwdata
add wave -noupdate -group DUT /hw_top/dut/rx
add wave -noupdate -group DUT /hw_top/dut/cts_n
add wave -noupdate -group DUT /hw_top/dut/pready
add wave -noupdate -group DUT /hw_top/dut/pslverr
add wave -noupdate -group DUT /hw_top/dut/prdata
add wave -noupdate -group DUT /hw_top/dut/tx
add wave -noupdate -group DUT /hw_top/dut/rts_n
add wave -noupdate -group DUT /hw_top/dut/clk_tx
add wave -noupdate -group DUT /hw_top/dut/clk_rx
add wave -noupdate -group DUT /hw_top/dut/tx_data
add wave -noupdate -group DUT /hw_top/dut/rx_data
add wave -noupdate -group DUT /hw_top/dut/data_bit_num
add wave -noupdate -group DUT /hw_top/dut/stop_bit_num
add wave -noupdate -group DUT /hw_top/dut/parity_en
add wave -noupdate -group DUT /hw_top/dut/parity_type
add wave -noupdate -group DUT /hw_top/dut/start_tx
add wave -noupdate -group DUT /hw_top/dut/tx_done
add wave -noupdate -group DUT /hw_top/dut/rx_done
add wave -noupdate -group DUT /hw_top/dut/parity_error
add wave -noupdate -group apb_interface /hw_top/aif/pclk
add wave -noupdate -group apb_interface /hw_top/aif/presetn
add wave -noupdate -group apb_interface /hw_top/aif/paddr
add wave -noupdate -group apb_interface /hw_top/aif/psel
add wave -noupdate -group apb_interface /hw_top/aif/penable
add wave -noupdate -group apb_interface /hw_top/aif/pwrite
add wave -noupdate -group apb_interface /hw_top/aif/pstrb
add wave -noupdate -group apb_interface /hw_top/aif/pwdata
add wave -noupdate -group apb_interface /hw_top/aif/prdata
add wave -noupdate -group apb_interface /hw_top/aif/pready
add wave -noupdate -group apb_interface /hw_top/aif/pslverr
add wave -noupdate -group apb_interface /hw_top/aif/monitor_start
add wave -noupdate -group apb_interface /hw_top/aif/drive_start
add wave -noupdate -group uart_interface /hw_top/uif/clk
add wave -noupdate -group uart_interface /hw_top/uif/rst_n
add wave -noupdate -group uart_interface /hw_top/uif/cts_n
add wave -noupdate -group uart_interface /hw_top/uif/tx
add wave -noupdate -group uart_interface /hw_top/uif/rx
add wave -noupdate -group uart_interface /hw_top/uif/rts_n
add wave -noupdate -group uart_interface /hw_top/uif/bit_period_ns
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {28915713 ps} 0}
quietly wave cursor active 1
configure wave -namecolwidth 150
configure wave -valuecolwidth 100
configure wave -justifyvalue left
configure wave -signalnamewidth 1
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2
configure wave -gridoffset 0
configure wave -gridperiod 1
configure wave -griddelta 40
configure wave -timeline 0
configure wave -timelineunits ns
update
WaveRestoreZoom {0 ps} {127873200 ps}

onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /tb_uart_tx/dut/clk
add wave -noupdate /tb_uart_tx/dut/reset_n
add wave -noupdate /tb_uart_tx/dut/pclk
add wave -noupdate /tb_uart_tx/dut/preset_n
add wave -noupdate /tb_uart_tx/dut/psel
add wave -noupdate /tb_uart_tx/dut/penable
add wave -noupdate /tb_uart_tx/dut/pwrite
add wave -noupdate /tb_uart_tx/dut/pstrb
add wave -noupdate /tb_uart_tx/dut/paddr
add wave -noupdate /tb_uart_tx/dut/pwdata
add wave -noupdate /tb_uart_tx/dut/rx
add wave -noupdate /tb_uart_tx/dut/cts_n
add wave -noupdate /tb_uart_tx/dut/pready
add wave -noupdate /tb_uart_tx/dut/pslverr
add wave -noupdate /tb_uart_tx/dut/prdata
add wave -noupdate /tb_uart_tx/dut/tx
add wave -noupdate /tb_uart_tx/dut/clk_tx
add wave -noupdate /tb_uart_tx/dut/clk_rx
add wave -noupdate -radix binary /tb_uart_tx/dut/tx_data
add wave -noupdate /tb_uart_tx/dut/data_bit_num
add wave -noupdate /tb_uart_tx/dut/stop_bit_num
add wave -noupdate /tb_uart_tx/dut/parity_en
add wave -noupdate /tb_uart_tx/dut/parity_type
add wave -noupdate /tb_uart_tx/dut/start_tx
add wave -noupdate /tb_uart_tx/dut/tx_done
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {97469982 ps} 0}
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
WaveRestoreZoom {0 ps} {109735500 ps}

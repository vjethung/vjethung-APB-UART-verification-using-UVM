onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /tb_uart_rx/dut/clk
add wave -noupdate /tb_uart_rx/dut/reset_n
add wave -noupdate /tb_uart_rx/dut/pclk
add wave -noupdate /tb_uart_rx/dut/preset_n
add wave -noupdate /tb_uart_rx/dut/psel
add wave -noupdate /tb_uart_rx/dut/penable
add wave -noupdate /tb_uart_rx/dut/pwrite
add wave -noupdate /tb_uart_rx/dut/pstrb
add wave -noupdate /tb_uart_rx/dut/paddr
add wave -noupdate /tb_uart_rx/dut/pwdata
add wave -noupdate /tb_uart_rx/dut/pready
add wave -noupdate /tb_uart_rx/dut/pslverr
add wave -noupdate /tb_uart_rx/dut/prdata
add wave -noupdate -color {Blue Violet} /tb_uart_rx/dut/tx
add wave -noupdate -color {Blue Violet} /tb_uart_rx/dut/cts_n
add wave -noupdate -color {Blue Violet} /tb_uart_rx/dut/rx
add wave -noupdate -color {Blue Violet} /tb_uart_rx/dut/rts_n
add wave -noupdate /tb_uart_rx/dut/clk_tx
add wave -noupdate /tb_uart_rx/dut/clk_rx
add wave -noupdate /tb_uart_rx/dut/tx_data
add wave -noupdate -expand /tb_uart_rx/dut/rx_data
add wave -noupdate /tb_uart_rx/dut/data_bit_num
add wave -noupdate /tb_uart_rx/dut/stop_bit_num
add wave -noupdate /tb_uart_rx/dut/parity_en
add wave -noupdate /tb_uart_rx/dut/parity_type
add wave -noupdate /tb_uart_rx/dut/start_tx
add wave -noupdate /tb_uart_rx/dut/tx_done
add wave -noupdate /tb_uart_rx/dut/rx_done
add wave -noupdate /tb_uart_rx/dut/parity_error
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {96396671 ps} 0}
quietly wave cursor active 1
configure wave -namecolwidth 107
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
WaveRestoreZoom {95622958 ps} {97922704 ps}

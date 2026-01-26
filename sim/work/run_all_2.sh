#!/bin/bash

# 1. Khởi tạo môi trường
shopt -s expand_aliases
source ./run.sh

TEST_LIST=(
    "simple_test" 
    "test_send_N_frame" 
    "test_received_N_frame" 
    "test_N_parity_error" 
    "test_check_reset" 
    "test_rxdata_write_ignored"
    "test_cfg_wr_rd_check" 
    "test_txdata_no_side_effect" 
    "test_send_TX_sweep_all_cfg_32"
    "test_receive_RX_sweep_all_cfg_32"
    "test_tx_basic"
    "test_cts_asserted" 
    "test_cts_deasserted" 
    "test_tx_done_pulse" 
    "test_rx_rts_dynamic"
)

# --- CẤU HÌNH ĐƯỜNG DẪN ---
SUMMARY_DIR="summary"
TEST_LOG_DIR="$SUMMARY_DIR/test_logs" # Thư mục con chứa log từng test
SUMMARY_FILE="$SUMMARY_DIR/regression_summary.log"
CURRENT_LOG="./log/vsim.log" # File log gốc sinh ra sau mỗi test

# Tạo các thư mục cần thiết
mkdir -p "$TEST_LOG_DIR"

# Tạo tiêu đề báo cáo
printf "==========================================================================================================\n" > "$SUMMARY_FILE"
printf "%-30s | %-8s | %-6s | %-6s | %-10s | %-10s | %-12s | %-10s\n" \
       "Test Name" "Status" "Error" "Fatal" "APB Trans" "UART Trans" "Seed" "Sim Time" >> "$SUMMARY_FILE"
printf "----------------------------------------------------------------------------------------------------------\n" >> "$SUMMARY_FILE"

pass_count=0
echo "Starting Regression. Logs will be saved at: $TEST_LOG_DIR"

for TEST in "${TEST_LIST[@]}"; do
    echo -n "Running $TEST... "
    
    # Chạy mô phỏng
    # vlb thực hiện dọn dẹp work/log nên ta phải copy log đi NGAY SAU khi vsm kết thúc
    vlb > /dev/null 2>&1 && vlg > /dev/null 2>&1
    vsm "$TEST" UVM_HIGH > /dev/null 2>&1
    
    # --- CẬP NHẬT: LƯU LOG TỪNG TEST ---
    if [ -f "$CURRENT_LOG" ]; then
        cp "$CURRENT_LOG" "$TEST_LOG_DIR/${TEST}.log"
    fi

    # 2. TRÍCH XUẤT THÔNG TIN
    LOG="$CURRENT_LOG"
    SEED=$(grep "Sv_Seed =" "$LOG" | awk '{print $NF}')
    ERRS=$(grep "UVM_ERROR :" "$LOG" | tail -1 | awk '{print $NF}')
    FATS=$(grep "UVM_FATAL :" "$LOG" | tail -1 | awk '{print $NF}')
    
    APB_COL=$(grep "APB Monitor Collected" "$LOG" | tail -1 | awk '{print $(NF-1)}')
    UART_COL=$(grep "UART Monitor Collected" "$LOG" | tail -1 | awk '{print $(NF-1)}')
    TIME=$(grep "Time:" "$LOG" | tail -1 | awk '{print $2}')
    
    # Kiểm tra trạng thái PASS/FAIL
    STATUS="FAIL"
    if [ "$ERRS" == "0" ] && [ "$FATS" == "0" ]; then
        STATUS="PASS"
        ((pass_count++))
    fi

    # Ghi vào file summary
    printf "%-30s | %-8s | %-6s | %-6s | %-10s | %-10s | %-12s | %-10s\n" \
           "$TEST" "$STATUS" "${ERRS:-0}" "${FATS:-0}" "${APB_COL:-0}" "${UART_COL:-0}" "$SEED" "$TIME" >> "$SUMMARY_FILE"
    echo "$STATUS"
done

# 3. TỔNG KẾT CUỐI BÁO CÁO
TOTAL=${#TEST_LIST[@]}
RATE=$(echo "scale=2; $pass_count * 100 / $TOTAL" | bc)
printf "----------------------------------------------------------------------------------------------------------\n" >> "$SUMMARY_FILE"
printf "TOTAL TESTS: %d | PASSED: %d | FAILED: %d | PASS RATE: %s%%\n" "$TOTAL" "$pass_count" "$((TOTAL-pass_count))" "$RATE" >> "$SUMMARY_FILE"
printf "==========================================================================================================\n" >> "$SUMMARY_FILE"

cat "$SUMMARY_FILE"
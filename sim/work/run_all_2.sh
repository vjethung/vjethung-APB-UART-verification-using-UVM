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

# --- THAY ĐỔI ĐƯỜNG DẪN LƯU TRỮ ---
# Lưu file summary ra thư mục sim (cha của work) để không bị vlb xóa
# SUMMARY_FILE="../regression_summary.log"
SUMMARY_FILE="regression_summary.log"
LOG_DIR="./log" # log của từng test vẫn nằm trong work/log để vlb dọn dẹp

mkdir -p "$LOG_DIR"

# Tạo tiêu đề mới (Ghi đè file cũ bằng dấu >)
printf "==========================================================================================================\n" > "$SUMMARY_FILE"
printf "%-30s | %-8s | %-6s | %-6s | %-10s | %-10s | %-12s | %-10s\n" \
       "Test Name" "Status" "Error" "Fatal" "APB Trans" "UART Trans" "Seed" "Sim Time" >> "$SUMMARY_FILE"
printf "----------------------------------------------------------------------------------------------------------\n" >> "$SUMMARY_FILE"

pass_count=0
echo "Starting Regression. Summary will be saved at: $SUMMARY_FILE"

for TEST in "${TEST_LIST[@]}"; do
    echo -n "Running $TEST... "
    
    # Biên dịch sạch sẽ cho từng test
    vlb > /dev/null 2>&1 && vlg > /dev/null 2>&1
    vsm "$TEST" UVM_HIGH > /dev/null 2>&1
    
    # 2. TRÍCH XUẤT THÔNG TIN (Sửa lỗi awk để lấy đúng con số) [cite: 370-444]
    LOG="$LOG_DIR/vsim.log"
    SEED=$(grep "Sv_Seed =" "$LOG" | awk '{print $NF}')
    ERRS=$(grep "UVM_ERROR :" "$LOG" | tail -1 | awk '{print $NF}')
    FATS=$(grep "UVM_FATAL :" "$LOG" | tail -1 | awk '{print $NF}')
    
    # Lấy số lượng transaction (Sửa NF-2 thành NF-1 để lấy con số)
    APB_COL=$(grep "APB Monitor Collected" "$LOG" | tail -1 | awk '{print $(NF-1)}')
    UART_COL=$(grep "UART Monitor Collected" "$LOG" | tail -1 | awk '{print $(NF-1)}')
    
    # Lấy thời gian mô phỏng
    TIME=$(grep "Time:" "$LOG" | tail -1 | awk '{print $2}')
    
    # Kiểm tra trạng thái PASS/FAIL [cite: 442-444]
    STATUS="FAIL"
    if [ "$ERRS" == "0" ] && [ "$FATS" == "0" ]; then
        STATUS="PASS"
        ((pass_count++))
    else
        # Lưu lại log lỗi của test đó để kiểm tra sau
        cp "$LOG" "../vsim_${TEST}_error.log"
    fi

    # Ghi dữ liệu vào file (Dùng dấu >> để NỐI THÊM vào file, không làm mất test cũ)
    printf "%-30s | %-8s | %-6s | %-6s | %-10s | %-10s | %-12s | %-10s\n" \
           "$TEST" "$STATUS" "$ERRS" "$FATS" "${APB_COL:-0}" "${UART_COL:-0}" "$SEED" "$TIME" >> "$SUMMARY_FILE"
    echo "$STATUS"
done

# 3. TỔNG KẾT CUỐI BÁO CÁO
TOTAL=${#TEST_LIST[@]}
# Tính % bằng lệnh bc
RATE=$(echo "scale=2; $pass_count * 100 / $TOTAL" | bc)
printf "----------------------------------------------------------------------------------------------------------\n" >> "$SUMMARY_FILE"
printf "TOTAL TESTS: %d | PASSED: %d | FAILED: %d | PASS RATE: %s%%\n" "$TOTAL" "$pass_count" "$((TOTAL-pass_count))" "$RATE" >> "$SUMMARY_FILE"
printf "==========================================================================================================\n" >> "$SUMMARY_FILE"

# Hiển thị kết quả ra màn hình
cat "$SUMMARY_FILE"
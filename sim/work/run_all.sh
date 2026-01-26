#!/bin/bash

# Cho phép mở rộng alias trong script
shopt -s expand_aliases
source ./run.sh

TEST_LIST=(
    "simple_test"
    "test_send_1_frame"
    "test_received_1_frame"
    "test_parity_error"
    "test_check_reset"
    "test_rxdata_write_ignored"
    "test_cfg_wr_rd_check"
    "test_txdata_no_side_effect"
    "test_tx_basic"
    "test_cts_asserted"
    "test_cts_deasserted"
    "test_tx_done_pulse"
    "test_rx_rts_dynamic"
)

# Khởi tạo báo cáo
LOG_DIR="./log"
SUMMARY_FILE="$LOG_DIR/regression_summary.log"
mkdir -p $LOG_DIR
echo "REGRESSION REPORT - $(date)" > $SUMMARY_FILE
echo "------------------------------------------------" >> $SUMMARY_FILE

echo "Starting Regression for ${#TEST_LIST[@]} tests..."

for TEST in "${TEST_LIST[@]}"; do
    echo -n "Running $TEST... "
    
    # 1. Clean & Compile
    # Chỉ chạy vlb và vlg một lần nếu bạn muốn nhanh, 
    # nhưng theo yêu cầu mình sẽ chạy mỗi lần test để đảm bảo sạch sẽ.
    vlb > /dev/null 2>&1
    vlg > /dev/null 2>&1
    
    # Kiểm tra lỗi biên dịch trước khi chạy vsim
    if [ $? -ne 0 ]; then
        echo "COMPILATION ERROR"
        echo "[FAIL] $TEST - Compilation Error" >> $SUMMARY_FILE
        continue
    fi

    # 2. Run Simulation
    vsm $TEST UVM_HIGH > /dev/null 2>&1
    
    # 3. Phân tích kết quả từ log vsim
    # Chỉ đếm nếu con số sau "UVM_ERROR :" hoặc "UVM_FATAL :" khác 0
    # Chúng ta dùng grep -E để tìm các dòng có số từ 1-9 sau dấu hai chấm
    REAL_ERRORS=$(grep "UVM_ERROR :" $LOG_DIR/vsim.log | grep -v ":    0" | wc -l)
    REAL_FATALS=$(grep "UVM_FATAL :" $LOG_DIR/vsim.log | grep -v ":    0" | wc -l)
    
    if [ "$REAL_ERRORS" -eq "0" ] && [ "$REAL_FATALS" -eq "0" ]; then
        echo "PASSED"
        echo "[PASS] $TEST" >> $SUMMARY_FILE
    else
        echo "FAILED ($REAL_ERRORS errors, $REAL_FATALS fatals)"
        echo "[FAIL] $TEST - Errors: $REAL_ERRORS, Fatals: $REAL_FATALS" >> $SUMMARY_FILE
        cp $LOG_DIR/vsim.log "$LOG_DIR/vsim_${TEST}_error.log"
    fi
done

echo "------------------------------------------------" >> $SUMMARY_FILE
echo "Regression Finished. See $SUMMARY_FILE for details."
cat $SUMMARY_FILE
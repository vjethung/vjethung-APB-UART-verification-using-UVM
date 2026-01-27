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
TEST_LOG_DIR="$SUMMARY_DIR/test_logs" 
COV_DATA_DIR="$SUMMARY_DIR/coverage_data" # Thư mục chứa file .ucdb của từng test
SUMMARY_FILE="$SUMMARY_DIR/regression_summary.log"
FINAL_COV_FILE="$SUMMARY_DIR/regression_total.ucdb"
CURRENT_LOG="./log/vsim.log" 
CURRENT_WLF="vsim.wlf"

# Tạo các thư mục cần thiết
mkdir -p "$TEST_LOG_DIR"
mkdir -p "$COV_DATA_DIR"

# Tạo tiêu đề báo cáo (Thêm cột Cov %)
printf "==========================================================================================================================\n" > "$SUMMARY_FILE"
printf "%-32s | %-8s | %-6s | %-6s | %-10s | %-10s | %-8s | %-10s\n" \
       "Test Name" "Status" "Error" "Fatal" "APB Trans" "UART Trans" "Cov %" "Sim Time" >> "$SUMMARY_FILE"
printf "--------------------------------------------------------------------------------------------------------------------------\n" >> "$SUMMARY_FILE"

pass_count=0
echo "Starting Regression. Data will be saved at: $SUMMARY_DIR"

for TEST in "${TEST_LIST[@]}"; do
    echo -n "Running $TEST... "
    
    vlb > /dev/null 2>&1 && vlg > /dev/null 2>&1
    
    # Chạy mô phỏng và lưu coverage tạm thời vào coverage.ucdb
    vsim -64 -c ${TOP_TB} -wlf $CURRENT_WLF \
        -sv_seed random -coverage \
        -voptargs="+acc" -l $CURRENT_LOG \
        +UVM_VERBOSITY=UVM_HIGH +UVM_TESTNAME=$TEST \
        -sv_lib uvm_dpi \
        -do "coverage save -onexit -testname $TEST coverage.ucdb; log -r /*; add wave -r /*; run -all; quit" > /dev/null 2>&1
    
    # --- LƯU TRỮ DỮ LIỆU ---
    [ -f "$CURRENT_LOG" ] && cp "$CURRENT_LOG" "$TEST_LOG_DIR/${TEST}.log"
    [ -f "$CURRENT_WLF" ] && cp "$CURRENT_WLF" "$TEST_LOG_DIR/${TEST}.wlf"
    # Lưu file coverage riêng biệt cho từng test để merge sau này
    [ -f "coverage.ucdb" ] && cp "coverage.ucdb" "$COV_DATA_DIR/${TEST}.ucdb"

    # --- TRÍCH XUẤT THÔNG TIN ---
    LOG="$CURRENT_LOG"
    ERRS=$(grep "UVM_ERROR :" "$LOG" | tail -1 | awk '{print $NF}')
    FATS=$(grep "UVM_FATAL :" "$LOG" | tail -1 | awk '{print $NF}')
    APB_COL=$(grep "APB Monitor Collected" "$LOG" | tail -1 | awk '{print $(NF-1)}')
    UART_COL=$(grep "UART Monitor Collected" "$LOG" | tail -1 | awk '{print $(NF-1)}')
    TIME=$(grep "Time:" "$LOG" | tail -1 | awk '{print $2}')
    
    # Trích xuất nhanh tỷ lệ coverage của test hiện tại (Total Coverage)
    TEST_COV=$(vcover report -summary "coverage.ucdb" | grep "Total Coverage Summary" -A 3 | grep "TOTAL" | awk '{print $NF}')

    STATUS="FAIL"
    if [ "$ERRS" == "0" ] && [ "$FATS" == "0" ]; then
        STATUS="PASS"
        ((pass_count++))
    fi

    printf "%-32s | %-8s | %-6s | %-6s | %-10s | %-10s | %-8s | %-10s\n" \
           "$TEST" "$STATUS" "${ERRS:-0}" "${FATS:-0}" "${APB_COL:-0}" "${UART_COL:-0}" "${TEST_COV:-0%}" "${TIME:-0 ns}" >> "$SUMMARY_FILE"
    echo "$STATUS (${TEST_COV:-0%})"
done

# --- BƯỚC QUAN TRỌNG: MERGE VÀ REPORT ---
echo "Merging all coverage data..."
vcover merge "$FINAL_COV_FILE" $COV_DATA_DIR/*.ucdb
echo "Generating final HTML report..."
vcover report -html "$FINAL_COV_FILE" -htmldir "$SUMMARY_DIR/total_cov_report"

# 3. TỔNG KẾT
TOTAL=${#TEST_LIST[@]}
RATE=$(echo "scale=2; $pass_count * 100 / $TOTAL" | bc)
printf "-----------------------------------------------------------------------------------------------------------------------\n" >> "$SUMMARY_FILE"
printf "TOTAL TESTS: %d | PASSED: %d | FAILED: %d | PASS RATE: %s%%\n" "$TOTAL" "$pass_count" "$((TOTAL-pass_count))" "$RATE" >> "$SUMMARY_FILE"
printf "=======================================================================================================================\n" >> "$SUMMARY_FILE"

cat "$SUMMARY_FILE"
echo "Regression Finished. Check HTML Report at: $SUMMARY_DIR/total_cov_report/index.html"
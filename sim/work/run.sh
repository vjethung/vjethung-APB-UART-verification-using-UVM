# chmod +x run.sh
#!/bin/bash
# Reset terminal cho sạch sẽ
reset

#--------------------------------------------------------------------------------------
# 1. Cấu hình công cụ QuestaSim và UVM
# Đường dẫn cài đặt QuestaSim trên hệ thống của bạn [cite: 13]
export MTI_HOME=/home/viethung/tools/Questasim/questasim
export PATH=${MTI_HOME}/linux_x86_64:$PATH
export LM_LICENSE_FILE=${MTI_HOME}/LICENSE.dat

# Đường dẫn thư viện UVM 1.1d [cite: 13]
export UVM_HOME=${MTI_HOME}/verilog_src/uvm-1.1d

# Biên dịch UVM DPI (Chỉ thực hiện nếu chưa có file uvm_dpi.so)
if [ ! -f uvm_dpi.so ]; then
    echo "--- Compiling UVM DPI ---"
    ccflags_dyn="-fPIC"
    ldflags_dyn="-shared"
    c++ -Wno-deprecated ${ccflags_dyn} ${ldflags_dyn} -DQUESTA -I ${MTI_HOME}/include -o uvm_dpi.so ${UVM_HOME}/src/dpi/uvm_dpi.cc
fi

# Định nghĩa các module Top của hệ thống [cite: 16, 33]
TOP_TB="tb_top hw_top" 

#--------------------------------------------------------------------------------------
# 2. Các Lệnh Tắt (Alias) cho Biên dịch và Xem kết quả
# Xóa các alias cũ có thể gây xung đột với Function bên dưới
unalias vsm vsm_gui 2>/dev/null

# Prepare workspace
alias vlb='reset; rm -rf work; mkdir -p log; rm -rf log/*; vlib work'
alias vlgr='vlog -64 -f filelist_com.f -f filelist_rtl.f  +cover=bcefs -l ./log/vlogr.log'
alias vlgt='vlog -64 -f filelist_com.f -f filelist_vsim.f -f filelist_tb.f -l ./log/vlogt.log'
alias vlg='vlgr; vlgt'

# Lệnh xem lại waveform đã lưu bằng file wave.do
alias viw='vsim -view vsim.wlf -do "do wave.do" &'
alias viwcov='vsim -viewcov coverage.ucdb &'

#--------------------------------------------------------------------------------------
# 3. Các Hàm Chạy Mô Phỏng (Functions)
# Cú pháp: vsm <tên_test> <mức_verbosity>
# Ví dụ: vsm base_test UVM_HIGH

vsm() {
    # Chống xung đột alias trong session hiện tại
    unalias vsm 2>/dev/null
    
    local TEST=${1:-"base_test"}    # Mặc định: base_test [cite: 50]
    local VERB=${2:-"UVM_MEDIUM"}    # Mặc định: UVM_MEDIUM
    
    echo "--- Running Batch Simulation: $TEST | Seed: Random | Verbosity: $VERB ---"
    
    vsim -64 -c ${TOP_TB} -wlf vsim.wlf \
        -sv_seed random \
        -solvefaildebug -assertdebug -sva -coverage \
        -voptargs="+acc" -l ./log/vsim.log \
        +UVM_VERBOSITY=$VERB \
        +UVM_TESTNAME=$TEST \
        -sv_lib uvm_dpi \
        -do "coverage save -onexit -assert -code bcefs -directive -cvg coverage.ucdb; log -r /*; run -all; quit"
}

vsm_gui() {
    unalias vsm_gui 2>/dev/null
    
    local TEST=${1:-"base_test"}
    local VERB=${2:-"UVM_MEDIUM"}
    
    echo "--- Opening QuestaSim GUI: $TEST | Verbosity: $VERB ---"
    
    # Kiểm tra và nạp file wave.do nếu có
    local WAVE_CMD="view objects; add wave -r /hw_top/*;"
    if [ -f wave.do ]; then
        WAVE_CMD="view objects; do wave.do;"
        echo "   -> Found wave.do, loading signal formats."
    fi

    vsim -64 ${TOP_TB} -wlf vsim.wlf \
        -sv_seed random \
        -solvefaildebug -assertdebug -sva -coverage \
        -voptargs="+acc" -l ./log/vsim.log \
        +UVM_VERBOSITY=$VERB \
        +UVM_TESTNAME=$TEST \
        -sv_lib uvm_dpi \
        -do "$WAVE_CMD run 0;"
}

# Hàm tạo báo cáo Coverage dạng HTML để theo dõi tỷ lệ kiểm thử
vrep() {
    echo "--- Generating HTML Coverage Report ---"
    vcover report -html coverage.ucdb -htmldir ./log/cov_report
    echo "   -> Report: ./log/cov_report/index.html"
}

#--------------------------------------------------------------------------------------
# 4. Hướng dẫn sử dụng khi nạp Script
echo "--------------------------------------------------------------"
echo "  APB-UART UVM Simulation Environment is ready."
echo "  1. vlb             : Clean workspace and create 'work' library."
echo "  2. vlg             : Compile RTL and Testbench files."
echo "  3. vsm <test> <v>  : Run simulation (Batch mode, random seed)."
echo "  4. vsm_gui <t> <v> : Run simulation (GUI mode, loads wave.do)."
echo "  5. viw             : Review previous waveform using wave.do."
echo "  6. vrep            : Generate HTML Coverage Report."
echo "--------------------------------------------------------------"
#!/bin/bash
reset

#--------------------------------------------------------------------------------------
# QuestaSim Tool
export MTI_HOME=/tools/mentor/questasim-2023.4
export PATH=/home/dokhoi/Questasim/questasim/linux_x86_64/:$PATH

# NC Tool
export PATH=$PATH:/tools/cadence/XCELIUMX/CELIUM21.03/tools.lnx86/bin

# License
export LM_LICENSE_FILE=/home/viethung/tools/Questasim/questasim/LICENSE.dat

#--------------------------------------------------------------------------------------
# UVM HOME
UVMLIB=uvm-1.1d
export UVM_HOME=/home/viethung/tools/Questasim/questasim/uvm-1.1d

# Generate uvm lib
ccflags_dyn="-fPIC"
ldflags_dyn="-shared"
echo "c++ -Wno-deprecated ${ccflags_dyn} ${ldflags_dyn} -DQUESTA -I ${MTI_HOME}/include -o uvm_dpi.so ${UVM_HOME}/src/dpi/uvm_dpi.cc"
c++ -Wno-deprecated ${ccflags_dyn} ${ldflags_dyn} -DQUESTA -I ${MTI_HOME}/include -o uvm_dpi.so ${UVM_HOME}/src/dpi/uvm_dpi.cc

# export TEST_NAME="dti_uart_base_test" # Test name for running simulation with UVM

TOP_TB=tb_uart_tx # name top testbench

#--------------------------------------------------------------------------------------
# Prepare workspace
alias vlb='reset; rm -rf work; mkdir -p log; rm -rf log/*; vlib work'
alias vlgr='vlog -64 -f filelist_com.f -f filelist_rtl.f  +cover=bcefs -l ./log/vlogr.log'
alias vlgt='vlog -64 -f filelist_com.f -f filelist_vsim.f -f filelist_tb.f -l ./log/vlogt.log'

# Compile rtl and testbench
alias vlg='vlgr; vlgt'

# Run simulation with UVM lib
# alias vsm='vsim -64 -c ${TOP_TB} -wlf vsim.wlf -solvefaildebug -assertdebug -sva -coverage -voptargs=+acc -l ./log/vsim.log +UVM_VERBOSITY=UVM_MEDIUM +UVM_TESTNAME=${TEST_NAME} -sv_lib uvm_dpi -do "coverage save -onexit -assert -code bcefs -directive -cvg coverage.ucdb; add wave -r /${TOP_TB}/*; run -all; quit"'
# alias vsm_opt='vsim -64 -c ${TOP_TB} -wlf vsim.wlf -solvefaildebug -assertdebug -sva -coverage -voptargs=+acc -l ./log/vsim.log +UVM_VERBOSITY=UVM_MEDIUM +UVM_TESTNAME=${TEST_NAME} -sv_lib uvm_dpi -do "coverage save -onexit -assert -code bcefs -directive -cvg coverage.ucdb; add wave -r /${TOP_TB}/*; run -all; quit"'

# Run simulation without UVM lib
alias vsm='vsim -64 -c ${TOP_TB} -wlf vsim.wlf -solvefaildebug -assertdebug -sva -coverage -voptargs=+acc -l ./log/vsim.log -do "coverage save -onexit -assert -code bcefs -directive -cvg coverage.ucdb; add wave -r /${TOP_TB}/*; run -all; quit"'
alias vsm_opt='vsim -64 -c ${TOP_TB} -solvefaildebug -assertdebug -sva -coverage -voptargs=+acc -l ./log/vsim.log -do "coverage save -onexit -assert -code bcefs -directive -cvg coverage.ucdb; run -all; quit"'

#--------------------------------------------------------------------------------------
# View wave form
alias viw='vsim -view vsim.wlf -do wave.do &'

# View coverage
alias viwcov='vsim -viewcov coverage.ucdb &'

# run compile command: vlb;vlg        
# run simulation command: vsm
# view waveform: viw
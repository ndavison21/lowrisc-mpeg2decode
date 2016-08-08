#!/bin/bash -f
xv_path="/usr/groups/comparch-lowrisc/tools/xilinx/Vivado/2016.2"
ExecStep()
{
"$@"
RETVAL=$?
if [ $RETVAL -ne 0 ]
then
exit $RETVAL
fi
}
ExecStep $xv_path/bin/xelab -wto 09f3d68d4ba145288e6e89aeba023acf -m64 --debug typical --relax --mt 8 -L xil_defaultlib -L unisims_ver -L unimacro_ver -L secureip --snapshot yuv420to444_tb_behav xil_defaultlib.yuv420to444_tb xil_defaultlib.glbl -log elaborate.log

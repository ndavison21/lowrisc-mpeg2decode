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
ExecStep $xv_path/bin/xsim yuv420to444_tb_behav -key {Behavioral:sim_1:Functional:yuv420to444_tb} -tclbatch yuv420to444_tb.tcl -view /auto/homes/nd359/Documents/mpeg2/chroma_conversion/yuv420to444_tb_behav.wcfg -log simulate.log

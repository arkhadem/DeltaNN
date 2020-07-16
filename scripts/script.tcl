#/***********************************************************/
#/*   FILE        : script.tcl                                */
#/*   Description : Default Synopsys Design Compiler Script */
#/*   Usage       : dc_shell -tcl_mode -f script.scr          */
#/*   You'll need to minimally set design_name & read files */
#/***********************************************************/
set design_path "/n/calumet/v/arkhadem/NanGatePDK/DeltaNN7"
set output_path $design_path/outputs
set report_path $design_path/reports
set library_path $design_path/library
set source_path $design_path/HDL

#/***********************************************************/
#/* The rest of this file may be left alone for most small  */
#/* to moderate sized designs.  You may need to alter it    */
#/* when synthesizing your final project.                   */
#/***********************************************************/
set SYN_DIR ./
# set target_library "/afs/eecs.umich.edu/kits/ARM/IBM_soi12s0/sc12_hvt/db-ccs/sc12_base_v31_hvt_soi12s0_ffl_nominal_min_1p10v_125c_mns.db_ccs"
set target_library [list $library_path/NangateOpenCellLibrary45_typical_ccs.db /n/calumet/v/arkhadem/DeltaNN/memory/sram_32_2048_scn4m_subm_TT_5p0V_25C.db]

set link_library [concat  "*" $target_library]

#/***********************************************************/
#/* The following lines must be updated for every           */
#/* new design                                              */
#/***********************************************************/
set src_files [list $source_path/sys_defs.svh $source_path/AF_array.sv $source_path/APE_adder.sv $source_path/APE_buffer.sv $source_path/Pool_array.sv $source_path/DRAM_master.sv $source_path/DRAM_slave.sv $source_path/Input_buffer.sv $source_path/Input_SRAM_controller.sv $source_path/Output_SRAM_controller.sv $source_path/PU_controller.sv $source_path/PU_idx_buffer.sv $source_path/PU_in_line_controller.sv $source_path/PU_repetition_weight_buffer.sv $source_path/PU_unique_weight_buffer.sv $source_path/PU_WB_SRAM_controller.sv $source_path/Weight_SRAM_controller.sv $source_path/crossbar.sv $source_path/APE.sv $source_path/MPE_in2out.sv $source_path/MPE_multiplier.sv $source_path/MPE.sv $source_path/PU.sv $source_path/Delta_controller_bias_loader.sv $source_path/Delta_controller_input_loader.sv $source_path/Delta_controller_output_extractor.sv $source_path/Delta_controller_weight_manager.sv $source_path/Delta_controller.sv $source_path/DeltaAcc.sv]
set design_name DeltaAcc
read_file -f sverilog $src_files
set clock_name clock
set clock_name_mem clock_mem
set reset_name reset
set CLK_PERIOD 2.90
set CLK_MEM_PERIOD 10

#/***********************************************************/
#/*  Clk Periods/uncertainty/transition                     */

set CLK_TRANSITION 0.1
set CLK_UNCERTAINTY 0.1
set CLK_LATENCY 0.1

#/* Input/output Delay values */
set AVG_INPUT_DELAY 0.1
set AVG_OUTPUT_DELAY 0.1

#/* Critical Range (ns) */
set CRIT_RANGE 1.0

#/***********************************************************/
#/* Design Constrains: Not all used                         */
set MAX_TRANSITION 1.0
set FAST_TRANSITION 0.1
set MAX_FANOUT 32
set MID_FANOUT 8
set LOW_FANOUT 1
set HIGH_DRIVE 0
set HIGH_LOAD 1.0
set AVG_LOAD 0.1
set AVG_FANOUT_LOAD 10

###############################################################
# check the design for any possible error
###############################################################
analyze -library WORK -format sverilog $src_files
elaborate $design_name
current_design $source_path/DeltaAcc.sv:DeltaAcc
link
uniquify
check_design

###############################################################
# set timing and area constraints to synthesis the design
###############################################################
#set CLK_PERIOD [expr 1000 / $clk_freq_MHz]
# set find_clock [find port [list $clock_name]]
# if { $find_clock != [list] } {
# 	create_clock -period $CLK_PERIOD $clock_name
# 	set_dont_touch_network $clock_name
# 	set_fix_hold $clock_name

#     #set_clock_uncertainty $CLK_UNCERTAINTY $clock_name
#     #remove_driving_cell [find port $clock_name]
#     #set_input_delay $AVG_INPUT_DELAY -clock $clock_name [all_inputs]
#     #remove_input_delay -clock $clock_name [find port $clock_name]
#     #set_output_delay $AVG_OUTPUT_DELAY -clock $clock_name [all_outputs]
# } else {
# 	create_clock -period $CLK_PERIOD -name vclk
# 	set_dont_touch_network vclk
# 	#do not put buffer in clk path.
# 	set_fix_hold vclk
# 	#want to meet hold time.

#     #set_clock_uncertainty $CLK_UNCERTAINTY vclk
#     #remove_driving_cell [find port vclk]
#     #set_input_delay $AVG_INPUT_DELAY -clock vclk [all_inputs]
#     #remove_input_delay -clock vclk [find port vclk]
#     #set_output_delay $AVG_OUTPUT_DELAY -clock vclk [all_outputs]
# }

create_clock -period $CLK_PERIOD $clock_name
set_dont_touch_network $clock_name
set_fix_hold $clock_name

create_clock -period $CLK_MEM_PERIOD $clock_name_mem
set_dont_touch_network $clock_name_mem
set_fix_hold $clock_name_mem

set_false_path -from $clock_name -to $clock_name_mem
set_false_path -from $clock_name_mem -to $clock_name

set my_input_delay_ns 0
set my_output_delay_ns 0


#/***********************************************************/
#/* Set some flags for optimization */

set compile_top_all_paths "true"
set auto_wire_load_selection "false"


#/***********************************************************/
#/*BASIC_INPUT = cb18os120_tsmc_max/nd02d1/A1
#BASIC_OUTPUT = cb18os120_tsmc_max/nd02d1/ZN*/

set DRIVING_CELL dffacs1

#/* DONT_USE_LIST = {   } */

#/*************operation cons**************/
#/*OP_WCASE = WCCOM;
#OP_BCASE = BCCOM;*/
#set WIRE_LOAD "tsmcwire"
#set LOGICLIB lec25dscc25_TT
#/*****************************/

#/* Sourcing the file that sets the Search path and the libraries(target,link) */


set dc_shell_status [ set chk_file [format "%s%s"  [format "%s%s"  $SYN_DIR $design_name] ".chk"] ]

#/* if we didnt find errors at this point, run */
if {  $dc_shell_status != [list] } {
  #set_wire_load_model -name $WIRE_LOAD -lib $LOGICLIB $design_name
  #set_wire_load_mode top
  set_fix_multiple_port_nets -outputs -buffer_constants
  group_path -from [all_inputs] -name input_grp
  group_path -to [all_outputs] -name output_grp
  set_driving_cell  -lib_cell $DRIVING_CELL [all_inputs]
  #set_fanout_load $AVG_FANOUT_LOAD [all_outputs]
  #set_load $AVG_LOAD [all_outputs]
  set_dont_touch $reset_name
  set_resistance 0 $reset_name
  set_drive 0 $reset_name
  set_critical_range $CRIT_RANGE [current_design]
  set_max_delay $CLK_PERIOD [all_outputs]
  #set MAX_FANOUT $MAX_FANOUT
  #set MAX_TRANSITION $MAX_TRANSITION
  #ungroup -all -flatten
  compile -map_effort high
  check_design

  ###############################################################
  # create netlist file
  # in this part you can create ddc, sdc and etc files either
  ###############################################################
  set netlist_file [format "%s%s" $design_name ".vg"]
  write -f verilog -hierarchy -output $output_path/$netlist_file
  set filename [format "%s%s" $design_name ".ddc"]
  write -format ddc -hierarchy -output $output_path/$filename
  set filename [format "%s%s" $design_name "_synopsys_design_constraints.sdc"]
  write_sdc $output_path/$filename
  #set filename [format "%s%s" $design_name ".db"]
  #write -f db -hier -output $output_path/$filename

  report_timing -transition_time -max_paths 10 -input_pins -nets -attributes -nosplit > $report_path/timing.rpt
  report_area -nosplit -hier > $report_path/area.rpt
  report_power -nosplit -hier > $report_path/power.rpt
  report_reference -nosplit -hier > $report_path/reference.rpt
  report_resources -nosplit -hier > $report_path/resources.rpt
  report_constraint -all_violators > $report_path/violations.rpt

  remove_design -all
  read_file -format verilog $output_path/$netlist_file
  quit
} else {
   quit
}

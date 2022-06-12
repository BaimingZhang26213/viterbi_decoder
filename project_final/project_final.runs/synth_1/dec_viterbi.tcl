# 
# Synthesis run script generated by Vivado
# 

set TIME_start [clock seconds] 
proc create_report { reportName command } {
  set status "."
  append status $reportName ".fail"
  if { [file exists $status] } {
    eval file delete [glob $status]
  }
  send_msg_id runtcl-4 info "Executing : $command"
  set retval [eval catch { $command } msg]
  if { $retval != 0 } {
    set fp [open $status w]
    close $fp
    send_msg_id runtcl-5 warning "$msg"
  }
}
create_project -in_memory -part xc7z020clg484-1

set_param project.singleFileAddWarning.threshold 0
set_param project.compositeFile.enableAutoGeneration 0
set_param synth.vivado.isSynthRun true
set_property webtalk.parent_dir C:/Users/Administrator/Desktop/recent/final/project_final/project_final.cache/wt [current_project]
set_property parent.project_path C:/Users/Administrator/Desktop/recent/final/project_final/project_final.xpr [current_project]
set_property default_lib xil_defaultlib [current_project]
set_property target_language VHDL [current_project]
set_property board_part xilinx.com:zc702:part0:1.4 [current_project]
set_property ip_repo_paths c:/Users/Administrator/Desktop/users/lovecelia [current_project]
update_ip_catalog
set_property ip_output_repo c:/Users/Administrator/Desktop/recent/final/project_final/project_final.cache/ip [current_project]
set_property ip_cache_permissions {read write} [current_project]
read_vhdl -library dec_viterbi {
  C:/Users/Administrator/Desktop/recent/final/project_final/project_final.srcs/sources_1/imports/trunk/packages/pkg_param.vhd
  C:/Users/Administrator/Desktop/recent/final/project_final/project_final.srcs/sources_1/imports/trunk/packages/pkg_helper.vhd
  C:/Users/Administrator/Desktop/recent/final/project_final/project_final.srcs/sources_1/imports/trunk/packages/pkg_param_derived.vhd
  C:/Users/Administrator/Desktop/recent/final/project_final/project_final.srcs/sources_1/imports/trunk/packages/pkg_types.vhd
  C:/Users/Administrator/Desktop/recent/final/project_final/project_final.srcs/sources_1/imports/trunk/packages/pkg_components.vhd
  C:/Users/Administrator/Desktop/recent/final/project_final/project_final.srcs/sources_1/imports/trunk/packages/pkg_trellis.vhd
}
read_vhdl -library xil_defaultlib {
  C:/Users/Administrator/Desktop/recent/final/project_final/project_final.srcs/sources_1/imports/src/acs.vhd
  C:/Users/Administrator/Desktop/recent/final/project_final/project_final.srcs/sources_1/imports/src/axi4s_buffer.vhd
  C:/Users/Administrator/Desktop/recent/final/project_final/project_final.srcs/sources_1/imports/src/branch_distance.vhd
  C:/Users/Administrator/Desktop/recent/final/project_final/project_final.srcs/sources_1/imports/src/generic_sp_ram.vhd
  C:/Users/Administrator/Desktop/recent/final/project_final/project_final.srcs/sources_1/imports/src/ram_ctrl.vhd
  C:/Users/Administrator/Desktop/recent/final/project_final/project_final.srcs/sources_1/imports/src/recursion.vhd
  C:/Users/Administrator/Desktop/recent/final/project_final/project_final.srcs/sources_1/imports/src/reorder.vhd
  C:/Users/Administrator/Desktop/recent/final/project_final/project_final.srcs/sources_1/imports/src/traceback.vhd
  C:/Users/Administrator/Desktop/recent/final/project_final/project_final.srcs/sources_1/imports/src/dec_viterbi.vhd
}
# Mark all dcp files as not used in implementation to prevent them from being
# stitched into the results of this synthesis run. Any black boxes in the
# design are intentionally left as such for best results. Dcp files will be
# stitched into the design at a later time, either when this synthesis run is
# opened, or when it is stitched into a dependent implementation run.
foreach dcp [get_files -quiet -all -filter file_type=="Design\ Checkpoint"] {
  set_property used_in_implementation false $dcp
}
read_xdc C:/Users/Administrator/Desktop/recent/final/project_final/project_final.srcs/constrs_1/new/timing.xdc
set_property used_in_implementation false [get_files C:/Users/Administrator/Desktop/recent/final/project_final/project_final.srcs/constrs_1/new/timing.xdc]

set_param ips.enableIPCacheLiteLoad 1
close [open __synthesis_is_running__ w]

synth_design -top dec_viterbi -part xc7z020clg484-1


# disable binary constraint mode for synth run checkpoints
set_param constraints.enableBinaryConstraints false
write_checkpoint -force -noxdef dec_viterbi.dcp
create_report "synth_1_synth_report_utilization_0" "report_utilization -file dec_viterbi_utilization_synth.rpt -pb dec_viterbi_utilization_synth.pb"
file delete __synthesis_is_running__
close [open __synthesis_is_complete__ w]

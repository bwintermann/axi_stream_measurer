open_project axis_measurer/axis_measurer.xpr
ipx::package_project -root_dir ./ip_repo -vendor user.org -library user -taxonomy /UserIP -import_files

ipx::infer_bus_interface ap_clk xilinx.com:signal:clock_rtl:1.0 [ipx::current_core]

set_property ipi_drc {ignore_freq_hz false} [ipx::current_core]
set_property sdx_kernel true [ipx::current_core]
set_property sdx_kernel_type rtl [ipx::current_core]
set_property vitis_drc {ctrl_protocol ap_ctrl_none} [ipx::current_core]
set_property ipi_drc {ignore_freq_hz true} [ipx::current_core]

ipx::associate_bus_interfaces -busif s_axi_control -clock ap_clk [ipx::current_core]
ipx::associate_bus_interfaces -busif instream -clock ap_clk [ipx::current_core]
ipx::associate_bus_interfaces -busif outstream -clock ap_clk [ipx::current_core]

set_property core_revision 2 [ipx::current_core]
#ipx::add_bus_parameter FREQ_HZ [ipx::get_bus_interfaces clk -of_objects [ipx::current_core]]
ipx::create_xgui_files [ipx::current_core]
ipx::update_checksums [ipx::current_core]
ipx::check_integrity -kernel -xrt [ipx::current_core]
ipx::save_core [ipx::current_core]
package_xo  -xo_path ./xo/axis_measure_top.xo -kernel_name axi_measure_top -ip_directory ./ip_repo -ctrl_protocol ap_ctrl_none

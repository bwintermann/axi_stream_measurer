all: clean xo/axis_measurer_top.xo

START_ENABLED ?= 0
DATA_WIDTH ?= 4
RECORD_ONLY_NONZERO ?= 0
VIVADO_YEAR ?= 2022

KERNEL_NAME ?= axis_measure_top

SOURCES := rtl/axis_measure_top.v rtl/axis_measure_defs.vh rtl/am_tb.v

rtl/axis_measure_defs.vh: rtl/axis_measure_defs_template.vh
	cp rtl/axis_measure_defs_template.vh rtl/axis_measure_defs.vh
	sed -i "s/???START_ENABLED???/$(START_ENABLED)/g" rtl/axis_measure_defs.vh
	sed -i "s/???DATA_WIDTH???/$(DATA_WIDTH)/g" rtl/axis_measure_defs.vh
	sed -i "s/???RECORD_ONLY_NONZERO???/$(RECORD_ONLY_NONZERO)/g" rtl/axis_measure_defs.vh

axis_measurer/axis_measurer.xpr: $(SOURCES)
	vivado -mode batch -source create_project.tcl

xo/axis_measurer_top.xo: axis_measurer/axis_measurer.xpr package_xo.tcl 
	vivado -mode batch -source package_xo.tcl -tclargs $(KERNEL_NAME)

package: axis_measurer/axis_measurer.xpr package_xo.tcl
	@echo "Packaging manually!"
	vivado -mode batch -source package_xo.tcl -tclargs $(KERNEL_NAME)

setver:
	sed -i "s/Vivado Synthesis [0-9][0-9][0-9][0-9]/Vivado Synthesis $(VIVADO_YEAR)/g" create_project.tcl
	sed -i "s/Vivado Implementation [0-9][0-9][0-9][0-9]/Vivado Implementation $(VIVADO_YEAR)/g" create_project.tcl

open: axis_measurer/axis_measurer.xpr
	(vivado $^ &)


clean:
	rm -rf axis_measurer
	rm -rf ip_repo
	rm -rf xo
	rm -rf *.sim
	rm -rf *.cache
	rm -rf *.hw
	rm -rf *.srcs
	rm -rf *.ip_user_files
	rm -f axis_measurer.xpr
	rm -f *.log
	rm -f *.jou
	rm -rf .Xil
	rm -f rtl/axis_measure_defs.vh

.PHONY = clean package setver all open

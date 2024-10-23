# AXIS Measurer
A Vitis compatible measurement kernel in RTL. Simply insert into the existing AXI Stream via `stream_connect` on the `instream` and `outstream` interfaces in the Vitis linker configuration. Records

- Number of AXI-Stream assertions
- Number of clock cycles passed
- Number of clock cycles until the first AXIS handshake
- The data of the last frame that was passed through

To read the data use the supplied class in the `host` directory or simply read the registers yourself, with the offsets given in the table below. 

## Creating the XO file
```
make
```

To create the .xo file from scratch simply call `make`. This will remove any artifacts from previous runs, reinstantiate the template verilog file and call the Vivado Tcl scripts to create the project and package the module for Vitis as a free-running kernel.

By default the kernel does not record when initialized. To change this build via
```
make START_ENABLED=1
```

To set the width of the AXI Stream that this kernel watches, set the data width accordingly in bytes. Example for a 512 AXI Stream:
```
make DATA_WIDTH=64
```

To record assertions and the last frame only when the values inside it are non zero, set the appropiate flag:
```
make RECORD_ONLY_NONZERO=1
```

After having run the build, you can inspect the vivado project using ```make open```.

## Insertion into the design
Simply instantiate the kernel and connect it, then run `v++` as usual to link.
```
[connectivity]
...
nk=axis_measure_top:1:am
...

stream_connect=A.m_axis:am.instream
stream_connect=am.outstream:B.s_axis
...
```

## Controlling the kernel
Simply include `host/measurer.cpp` and setup your host code as usual. Then initialize the measurement kernel and record:
```C++
AXISMeasureKernel am(device, uuid, "axis_measure_top:{am}");
am.start_measurement();

<your computation>

am.stop_measurement();

auto assertions = am.get_assertions();
auto cycles = am.get_cycles();
auto latency = am.get_latency();

...

// If you want to start another run, reset everything
am.clear_and_stop_measurement();
am.start_measurement();

...
``` 

## Controlling the kernel manually
The kernel's registers are adressable via the `xrt::ip` class with the given offsets.
The following table gives those offsets.

| Offset       	| Register                          	|
|--------------	|-----------------------------------	|
| 0x00 - 0x10  	| Reserved                          	|
| 0x10 - 0x14  	| Control Register (32 bit)         	|
| 0x14 - 0x1c  	| AXI Stream Data Packets (2 x 32 bit) 	|
| 0x1c - 0x24  	| Clock cycles passed (2 x 32 bit)     	|
| 0x24 - 0x2c   | Latency until first assert from reset |
| 0x2c - ...    | Data of last frame                    |


Both assertions and clock cycles passed are split into 2 fields of 32 bit each, with the __lower__ half being first (0x14-0x18), and the more significant half being __higher__ (0x18-0x1c).

The data of the AXI Streams is always passed through. You only control the counting.

- To _start counting_ assertions write `0x1` to the control register
- To _stop counting_ assertions write `0x0` to the control register (initial value)
- To _reset_ all counter values, write `0x2` to the control register (this __stops__ recording until you start again) // TODO: Make this configurable

## Footprint
This is the footprint for a 32-bit AXI Stream going through the kernel
- _Throughput_: Unchanged
- _Latency_: 1 clock cycle
- _Post-Synthesis LUT Estimate_: 177
- _Post-Synthesis FF Estimate_: 307

## Issues
- If the Vivado version does not match your version, you will need to adjust the year number in the project creation Tcl script. Use `make setver VIVADO_YEAR=2022` for this

## TODOs
- Proper verification
- Change marco-search-replace with `sed` to passing values as arguments to the Tcl scripts

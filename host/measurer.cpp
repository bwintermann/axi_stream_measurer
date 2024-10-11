/** Helper utilities to make usage of the kernels easier **/

#include "experimental/xrt_kernel.h"
#include "experimental/xrt_ip.h"

// Register offsets for the data
#define AXIS_MEASURE_CONTROL_OFFSET     0x10
#define ASSERTIONS_OFFSET               0x14
#define CYCLES_OFFSET                   0x1C

// Constants for the control register
#define START 0x1
#define STOP 0x0
#define CLEAR 0x2


class AXISMeasureKernel {
    private:
        xrt::ip kernel;

    public:
        AXISMeasureKernel(xrt::ip ip) {
            kernel = ip;
        }

        void start_measurement() {
            kernel.write_register(AXIS_MEASURE_CONTROL_OFFSET, START);
        }
        
        void stop_measurement() {
            kernel.write_register(AXIS_MEASURE_CONTROL_OFFSET, STOP);
        }

        void clear_measurement() {
            kernel.write_register(AXIS_MEASURE_CONTROL_OFFSET, CLEAR);
        }
        
        void set_control_register(uint32_t value) {
            kernel.write_register(AXIS_MEASURE_CONTROL_OFFSET, value);
        }

        bool is_active() {
            return kernel.read_register(AXIS_MEASURE_CONTROL_OFFSET) == 0x1;
        }

        uint32_t get_assertions() {
            return kernel.read_register(ASSERTIONS_OFFSET);
        }

        uint32_t get_cycles() {
            return kernel.read_register(CYCLES_OFFSET);
        }

        unsigned int mbps(unsigned int mhz, unsigned int axis_data_width_bytes) {
            return ((axis_data_width_bytes * get_assertions()) / 1000000.0) / (get_cycles() / (mhz * 1000000.0)); 
        }
};
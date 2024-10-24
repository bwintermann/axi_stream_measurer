/** Helper utilities to make usage of the kernels easier **/

#include "experimental/xrt_kernel.h"
#include "experimental/xrt_ip.h"
#include <math.h>
#include <vector>
#include <thread>
#include <chrono>

// Register offsets for the data
#define AXIS_MEASURE_CONTROL_OFFSET     0x10
#define ASSERTIONS_OFFSET               0x14
#define CYCLES_OFFSET                   0x1C
#define LATENCY_OFFSET                  0x24
#define AXIS_DATA_WIDTH_OFFSET          0x2C
#define LAST_FRAME_OFFSET               0x30

// Constants for the control register
#define START 0x1
#define STOP 0x0
#define CLEAR 0x2


class AXISMeasureKernel {
    private:
        xrt::ip kernel;

    public:
        AXISMeasureKernel() {};

        AXISMeasureKernel(xrt::ip ip) {
            kernel = ip;
        }

        AXISMeasureKernel(xrt::device &device, xrt::uuid &uuid, std::string name) {
            kernel = xrt::ip(device, uuid, name);
        }

        void start_measurement() {
            kernel.write_register(AXIS_MEASURE_CONTROL_OFFSET, START);
        }
        
        void stop_measurement() {
            kernel.write_register(AXIS_MEASURE_CONTROL_OFFSET, STOP);
        }

        void clear_and_stop_measurement() {
            kernel.write_register(AXIS_MEASURE_CONTROL_OFFSET, CLEAR);
        }
        
        void set_control_register(uint32_t value) {
            kernel.write_register(AXIS_MEASURE_CONTROL_OFFSET, value);
        }

        bool is_active() {
            return kernel.read_register(AXIS_MEASURE_CONTROL_OFFSET) == 0x1;
        }

        uint32_t get_axis_width_bytes() {
            return kernel.read_register(AXIS_DATA_WIDTH_OFFSET);
        }

        uint32_t read(uint32_t offset) {
            return kernel.read_register(offset);
        }

        void write(uint32_t offset, uint32_t value) {
            kernel.write_register(offset, value);
        }

        uint64_t get_assertions() {
            uint64_t data = 0;
            data |= kernel.read_register(ASSERTIONS_OFFSET + 4);
            data <<= 32;
            data |= kernel.read_register(ASSERTIONS_OFFSET);
            return data;
        }

        uint64_t get_cycles() {
            uint64_t data = 0;
            data |= kernel.read_register(CYCLES_OFFSET + 4);
            data <<= 32;
            data |= kernel.read_register(CYCLES_OFFSET);
            return data;
        }

        uint64_t get_latency() {
            uint64_t data = 0;
            data |= kernel.read_register(LATENCY_OFFSET + 4);
            data <<= 32;
            data |= kernel.read_register(LATENCY_OFFSET);
            return data;
        }

        // IMPORTANT: This keeps little endian ordering!
        void get_last_frame(unsigned int axis_data_width_bytes, uint32_t* out) {
            unsigned int words = static_cast<unsigned int>(ceil(axis_data_width_bytes / 4.0));
            for (unsigned int i = 0; i < words; i++) {
                out[i] = kernel.read_register(LAST_FRAME_OFFSET + i * 4);
            }
        }

        auto mbps(unsigned int mhz, unsigned int axis_data_width_bytes) {
            return ((axis_data_width_bytes * get_assertions()) / 1000000.0) / (get_cycles() / (mhz * 1000000.0)); 
        }

        // Return the asserts per cycles in time interval for the given number of intervals
        std::vector<float> asserts_in_interval(unsigned int interval_ns, unsigned int intervals) {
            std::vector<float> data;
            for (unsigned int i = 0; i < intervals; i++) {
                std::this_thread::sleep_for(std::chrono::nanoseconds(interval_ns));
                data.push_back(static_cast<float>(get_assertions()) / static_cast<float>(get_cycles()));
            } 
            return data;
        }
};
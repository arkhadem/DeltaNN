`ifndef __SYS_DEFS_V__
`define __SYS_DEFS_V__

`define BIN_LEN 8
`define OUT_BIN_LEN 16
`define INPUT_CHANNEL 4
`define OUTPUT_CHANNEL 4
`define KERNEL_WIDTH 16
`define KERNEL_HEIGHT 16
`define INPUT_WIDTH 40
`define INPUT_HEIGHT 40
`define STRIDE_LEN 3
`define OUTPUT_WIDTH 8 // ((`INPUT_WIDTH - `KERNEL_WIDTH) / `STRIDE) + 1			// 5
`define OUTPUT_HEIGHT 8 // ((`INPUT_HEIGHT - `KERNEL_HEIGHT) / `STRIDE) + 1		// 5


`define INPUT_SRAM_LEN 8	// in terms of BIN_LEN
`define OUTPUT_SRAM_LEN 8	// in terms of OUT_BIN_LEN
`define WEIGHT_SRAM_LEN 32

`define MAX_WEIGHT_NUM_LEN 8
`define MAX_IDX_DELTA_LEN 8
`define MAX_WEIGHT_DELTA_LEN 4
`define MAX_WEIGHT_LEN_BYTE 32
`define MAX_INPUT_CHANNEL 1024
`define MAX_OUTPUT_CHANNEL 1024
`define MAX_FEATURE_SIZE 256

`define INDEX_LEN 1+`OUTPUT_CHANNEL_LOG+`KERNEL_HEIGHT_LOG+`KERNEL_WIDTH_LOG		// one for bubble
`define INDEX_SRAM_NUM `OUTPUT_CHANNEL*`KERNEL_HEIGHT*`KERNEL_WIDTH
`define INDEX_SRAM_NUM_LOG $clog2(`INDEX_SRAM_NUM)
`define INDEX_SRAM_LEN `INDEX_SRAM_NUM*`INDEX_LEN

`define PU_NUM 4

`define POOL_NONE 3'b0
`define POOL_MAX 3'b1

`define AF_NONE 3'b0
`define AF_RELU 3'b1 


// DeltaNN parameters
`define DELTA_LEN 2         //roof(log2(max(shifts)))
`define DELTA_SIM_LEN 3     //roof(log2(max(weights equal to eachother)))
`define DELTA_NUM 32        //number of unique weights
`define INDEX_NUM 32        //It should be around `OUTPUT_CHANNEL * `KERNEL_HEIGHT * `KERNEL_WIDTH. With new index num compression
`define INDEX_NUM_LOG $clog2(`INDEX_NUM)
`define DELTA_NUM_LOG $clog2(`DELTA_NUM)


`endif

`ifndef __FREE_LIST_V__
`define __FREE_LIST_V__

`define BIN_LEN 4
`define DELTA_LEN 2         //roof(log2(max(shifts)))
`define DELTA_SIM_LEN 3     //roof(log2(max(weights equal to eachother)))
`define DELTA_NUM 64        //number of unique weights
`define INDEX_NUM 64        //It should be around `OUTPUT_CHANNEL * `KERNEL_HEIGHT * `KERNEL_WIDTH. With new index num compression
`define OUT_BIN_LEN 8
`define INPUT_CHANNEL 3
`define OUTPUT_CHANNEL 4
`define KERNEL_WIDTH 2
`define KERNEL_HEIGHT 2
`define INPUT_WIDTH 4
`define INPUT_HEIGHT 4


`define INDEX_WIDTH `OUTPUT_CHANNEL_LOG+`KERNEL_HEIGHT_LOG+`KERNEL_WIDTH_LOG+1
`define OUTPUT_WIDTH `INPUT_WIDTH-`KERNEL_WIDTH+1
`define OUTPUT_HEIGHT `INPUT_HEIGHT-`KERNEL_HEIGHT+1
`define INDEX_NUM_LOG $clog2(`INDEX_NUM)
`define DELTA_NUM_LOG $clog2(`DELTA_NUM)
`define INPUT_CHANNEL_LOG $clog2(`INPUT_CHANNEL)
`define OUTPUT_CHANNEL_LOG $clog2(`OUTPUT_CHANNEL)
`define OUTPUT_WIDTH_LOG $clog2(`OUTPUT_WIDTH)
`define OUTPUT_HEIGHT_LOG $clog2(`OUTPUT_HEIGHT)
`define KERNEL_WIDTH_LOG $clog2(`KERNEL_WIDTH)
`define KERNEL_HEIGHT_LOG $clog2(`KERNEL_HEIGHT)
`define INPUT_WIDTH_LOG $clog2(`INPUT_WIDTH)
`define INPUT_HEIGHT_LOG $clog2(`INPUT_HEIGHT)



`endif

`timescale 1ns/1ps

module sdcard_top
#(
   parameter ADDR   = 32    //Address bus bit width
  ,parameter DATA   = 32    //Data bus bit width
  ,parameter CMD    = 1     //Cmd bus bit width
  ,parameter WIDTH  = 4096  //Cache line bit width
  ,parameter DEPTH  = 8     //Number of lines
  ,parameter FREQ   = 10000000
)
(
   input              clock
  ,input              reset
  //CPU
  ,output             async_addr_ack
  ,input              async_addr_req
  ,input  [ADDR -1:0] async_addr
  ,input              async_cmd_req
  ,output             async_cmd_ack
  ,input              async_cmd
  ,input              async_data_out_req
  ,output             async_data_out_ack
  ,input  [DATA -1:0] async_data_out
  ,output             async_data_in_req
  ,input              async_data_in_ack
  ,output [DATA -1:0] async_data_in
  //SDCARD
  ,output             cs
  ,output             mosi
  ,input              miso
  ,output             sclk
);

wire              cpu_valid_in;
wire              cpu_ready_in;
wire [ADDR  -1:0] cpu_addr_in;
wire [2*DATA-1:0] cpu_data_in;
wire [CMD   -1:0] cpu_cmd_in;
wire              cpu_valid_out;
wire              cpu_ready_out;
wire [2*DATA-1:0] cpu_data_out;
wire              sd_valid_out;
wire              sd_ready_out;
wire [ADDR  -1:0] sd_addr_out;
wire [WIDTH -1:0] sd_data_out;
wire [CMD   -1:0] sd_cmd_out;
wire              sd_valid_in;
wire              sd_ready_in;
wire [WIDTH -1:0] sd_data_in;

sdcard_glue_cpu 
# (
   .ADDR  (ADDR )
  ,.DATA  (DATA )
  ,.CMD   (CMD  )
  ,.WIDTH (WIDTH)
  ,.DEPTH (DEPTH)
) sdcard_glue_cpu (
   .clock               (clock              )
  ,.reset               (reset              )
  ,.cpu_valid_in        (cpu_valid_in       )
  ,.cpu_ready_in        (cpu_ready_in       )
  ,.cpu_addr_in         (cpu_addr_in        )
  ,.cpu_data_in         (cpu_data_in        )
  ,.cpu_cmd_in          (cpu_cmd_in         )
  ,.cpu_valid_out       (cpu_valid_out      )
  ,.cpu_ready_out       (cpu_ready_out      )
  ,.cpu_data_out        (cpu_data_out       )
  ,.async_addr_ack      (async_addr_ack     )
  ,.async_addr_req      (async_addr_req     )
  ,.async_addr          (async_addr         )
  ,.async_cmd_req       (async_cmd_req      )
  ,.async_cmd_ack       (async_cmd_ack      )
  ,.async_cmd           (async_cmd          )
  ,.async_data_out_req  (async_data_out_req )
  ,.async_data_out_ack  (async_data_out_ack )
  ,.async_data_out      (async_data_out     )
  ,.async_data_in_req   (async_data_in_req  )
  ,.async_data_in_ack   (async_data_in_ack  )
  ,.async_data_in       (async_data_in      )
);

cache
#(
   .ADDR  (ADDR  )
  ,.DATA  (2*DATA)
  ,.CMD   (CMD   )
  ,.WIDTH (WIDTH )
  ,.DEPTH (DEPTH )
) cache (
   .clock           (clock          )
  ,.reset           (reset          )
  ,.cpu_valid_in    (cpu_valid_in   )
  ,.cpu_ready_in    (cpu_ready_in   )
  ,.cpu_addr_in     (cpu_addr_in    )
  ,.cpu_data_in     (cpu_data_in    )
  ,.cpu_cmd_in      (cpu_cmd_in     )
  ,.cpu_valid_out   (cpu_valid_out  )
  ,.cpu_ready_out   (cpu_ready_out  )
  ,.cpu_data_out    (cpu_data_out   )
  ,.sd_valid_out    (sd_valid_out   )
  ,.sd_ready_out    (sd_ready_out   )
  ,.sd_addr_out     (sd_addr_out    )
  ,.sd_data_out     (sd_data_out    )
  ,.sd_cmd_out      (sd_cmd_out     )
  ,.sd_valid_in     (sd_valid_in    )
  ,.sd_ready_in     (sd_ready_in    )
  ,.sd_data_in      (sd_data_in     )
);

wire            dout_valid, din_ready, ready;
wire            rd, wr;
wire [     7:0] din, dout;
wire [ADDR-1:0] ain;

sdcard_glue_cache
# (
   .ADDR  (ADDR )
  ,.DATA  (8    )
  ,.CMD   (CMD  )
  ,.WIDTH (WIDTH)
  ,.DEPTH (DEPTH)
) sdcard_glue_cache (
   .clock         (clock        )
  ,.reset         (reset        )
  ,.sd_valid_out  (sd_valid_out )
  ,.sd_ready_out  (sd_ready_out )
  ,.sd_addr_out   (sd_addr_out  )
  ,.sd_data_out   (sd_data_out  )
  ,.sd_cmd_out    (sd_cmd_out   )
  ,.sd_valid_in   (sd_valid_in  )
  ,.sd_ready_in   (sd_ready_in  )
  ,.sd_data_in    (sd_data_in   )
  ,.rd            (rd           )
  ,.dout          (dout         )
  ,.dout_valid    (dout_valid   )
  ,.wr            (wr           )
  ,.din           (din          )
  ,.din_ready     (din_ready    )
  ,.ready         (ready        )
  ,.ain           (ain          )
);

sd_controller
#(
   .FREQ      (FREQ )
  ,.RAMP      (80   )
  ,.BLOCK_SIZE(513  )
) sd (
   .clock       (clock      )
  ,.reset       (reset      )
  ,.cs          (cs         )
  ,.mosi        (mosi       )
  ,.miso        (miso       )
  ,.sclk        (sclk       )
  ,.rd          (rd         )
  ,.dout        (dout       )
  ,.dout_valid  (dout_valid )
  ,.wr          (wr         )
  ,.din         (din        )
  ,.din_ready   (din_ready  )
  ,.ready       (ready      )
  ,.ain         (ain        )
);

endmodule

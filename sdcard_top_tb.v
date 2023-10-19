`timescale 1ns/1ps

module sdcard_top_tb();

localparam ADDR   = 32;
localparam DATA   = 32;
localparam CMD    = 1;
localparam WIDTH  = 128;
localparam DEPTH  = 8;

reg clock;
initial clock = 0;
always clock = #1 ~clock;

task delay;
input [31:0] d;
begin
    repeat (d) @(posedge clock);
end
endtask

wire              sd_valid_out;
reg               sd_ready_out;
wire [ADDR -1:0]  sd_addr_out;
wire [WIDTH-1:0]  sd_data_out;
wire [CMD  -1:0]  sd_cmd_out;
reg               sd_valid_in;
wire              sd_ready_in;
reg  [WIDTH-1:0]  sd_data_in;

reg           req_id_valid;
wire          req_id_ready;
reg   [ 3:0]  req_id;
reg           req_addr_valid;
wire          req_addr_ready;
reg   [ADDR-1:0]  req_addr;
reg           req_cmd_valid;
wire          req_cmd_ready;
reg   [ 0:0]  req_cmd;
reg                 req_data_valid;
wire                req_data_ready;
reg   [2*DATA-1:0]  req_data;

wire                resp_id_valid;
reg                 resp_id_ready;
wire  [       3:0]  resp_id;
wire                resp_data_valid;
reg                 resp_data_ready;
wire  [2*DATA-1:0]  resp_data;

wire              async_addr_ack;
wire              async_addr_req;
wire  [ADDR-1:0]  async_addr;
wire              async_cmd_req;
wire              async_cmd_ack;
wire              async_cmd;
wire              async_data_in_req;
wire              async_data_in_ack;
wire  [DATA-1:0]  async_data_in;
wire              async_data_out_req;
wire              async_data_out_ack;
wire  [DATA-1:0]  async_data_out;

wire mosi;
reg miso;
wire sclk, cs;

reg [4095:0] tmp_data;

reg reset;
task reset_task;
begin
  reset = 0;
  req_id_valid = 0;
  req_id = 0;
  req_addr_valid = 0;
  req_addr = 0;
  req_cmd_valid = 0;
  req_cmd = 0;
  req_data_valid = 0;
  req_data = 0;
  resp_id_ready = 0;
  resp_data_ready = 0;
  sd_ready_out = 0;
  sd_valid_in = 0;
  sd_data_in = 0;
  miso = 0;
  delay(10);
  reset = 1;
  delay(10);
  reset = 0;
end
endtask

task send_mem_req;
input [ADDR-1:0]    addr;
input [ 0:0]        cmd;
input [2*DATA-1:0]  data;
begin
  req_id_valid = 1;
  req_id = $random;
  req_addr_valid = 1;
  req_addr = addr;
  req_cmd_valid = 1;
  req_cmd = cmd;
  req_data_valid = 1;
  req_data = data;
  delay(1);
  while (!req_id_ready) delay(1);
  req_id_valid = 0;
  req_addr_valid = 0;
  req_cmd_valid = 0;
  req_data_valid = 0;
end
endtask

task recv_mem_resp;
begin
  resp_id_ready = 1;
  resp_data_ready = 1;
  delay(1);
  while (!resp_data_valid) delay(1);
  resp_id_ready = 0;
  resp_data_ready = 0;
end
endtask

integer i;
reg [24:0] tag;
reg [3:0] offset;
reg [2:0] index;
task fill_cache_read;
begin
  tag = 0;
  offset = 0;
  index = 0;
  for (i=0;i<DEPTH;i=i+1) begin
    send_mem_req({tag,index,offset},0,$random);
    delay(1);
    index = index + 1;
    delay(1);
    recv_mem_resp();
  end
end
endtask

task update_cache_read;
begin
  tag = 1;
  offset = 0;
  index = DEPTH;
  for (i=0;i<DEPTH;i=i+1) begin
    send_mem_req({tag,index,offset},0,$random);
    delay(1);
    index = index + 1;
    delay(1);
    recv_mem_resp();
  end
end
endtask

task update_cache_write;
begin
  tag = 1;
  offset = 0;
  index = DEPTH;
  for (i=0;i<DEPTH;i=i+1) begin
    send_mem_req({tag,index,offset},1,{$random,$random});
    delay(1);
    index = index + 1;
    delay(1);
  end
end
endtask

task writeback_cache_write;
begin
  tag = 2;
  offset = 0;
  index = DEPTH;
  for (i=0;i<DEPTH;i=i+1) begin
    send_mem_req({tag,index,offset},1,{$random,$random});
    delay(1);
    index = index + 1;
    delay(1);
  end
end
endtask

initial begin
  reset_task();
  delay(2000);
  send_mem_req(0,0,0);
  recv_mem_resp();
  delay(100);
  fill_cache_read();
  delay(100);
  update_cache_read();
  delay(100);
  update_cache_write();
  delay(100);
  writeback_cache_write();
  delay(100);
  $finish;
end

always @(posedge clock)
if (reset)                            sd_ready_out <= 0;
else if (sd_valid_out & sd_ready_out) sd_ready_out <= 0;
else if (sd_valid_out)                sd_ready_out <= 1;
else                                  sd_ready_out <= sd_ready_out;

always @(posedge clock)
if (reset) begin
  sd_valid_in <= 0;
  sd_data_in  <= 0;
end
else if (sd_valid_in & sd_ready_in) begin
  sd_valid_in <= 0;
  sd_data_in  <= 0;
end
else if (sd_valid_out & sd_ready_out & !sd_cmd_out) begin
  sd_valid_in <= 1;
  sd_data_in  <= {$random,$random,$random,$random};
end
else begin
  sd_valid_in <= sd_valid_in;
  sd_data_in  <= sd_data_in;
end

reg cmd;
always @(posedge clock)
if (reset)                                                  cmd <= 0;
else if (sdcard_top.sd_valid_out & sdcard_top.sd_ready_out) cmd <= sdcard_top.sd_cmd_out;
else                                                        cmd <= cmd;

always @(negedge sclk)
if (reset)      miso <= 0;
else if (!cmd)  miso <= $random;
else if ( cmd)  miso <= 0;
else            miso <= miso;

sdcard_top
#(
   .ADDR  (ADDR  )
  ,.DATA  (DATA  )
  ,.CMD   (CMD   )
  ,.WIDTH (WIDTH )
  ,.DEPTH (DEPTH )
  ,.FREQ  (1000  )
) sdcard_top (
   .clock               (clock              )
  ,.reset               (reset              )
  ,.async_addr_ack      (async_addr_ack     )
  ,.async_addr_req      (async_addr_req     )
  ,.async_addr          (async_addr         )
  ,.async_cmd_req       (async_cmd_req      )
  ,.async_cmd_ack       (async_cmd_ack      )
  ,.async_cmd           (async_cmd          )
  ,.async_data_in_req   (async_data_in_req  )
  ,.async_data_in_ack   (async_data_in_ack  )
  ,.async_data_in       (async_data_in      )
  ,.async_data_out_req  (async_data_out_req )
  ,.async_data_out_ack  (async_data_out_ack )
  ,.async_data_out      (async_data_out     )
  ,.cs                  (cs                 )
  ,.mosi                (mosi               )
  ,.miso                (miso               )
  ,.sclk                (sclk               )
);

\ariscvMAIN_MEM__ asyncMAIN_MEM (
   .\clock                    (clock              )
  ,.\reset                    (reset              )
  ,.\MC_MM_REQ.ID_ready       (req_id_ready       )
  ,.\MC_MM_REQ.ID_valid       (req_id_valid       )
  ,.\MC_MM_REQ.ID             (req_id             )
  ,.\MC_MM_REQ.ADDR_ready     (req_addr_ready     )
  ,.\MC_MM_REQ.ADDR_valid     (req_addr_valid     )
  ,.\MC_MM_REQ.ADDR           (req_addr           )
  ,.\MC_MM_REQ.CMD_ready      (req_cmd_ready      )
  ,.\MC_MM_REQ.CMD_valid      (req_cmd_valid      )
  ,.\MC_MM_REQ.CMD            (req_cmd            )
  ,.\MC_MM_REQ.DATA_ready     (req_data_ready     )
  ,.\MC_MM_REQ.DATA_valid     (req_data_valid     )
  ,.\MC_MM_REQ.DATA           (req_data           )
  ,.\MC_MM_RESP.ID_valid      (resp_id_valid      )
  ,.\MC_MM_RESP.ID_ready      (resp_id_ready      )
  ,.\MC_MM_RESP.ID            (resp_id            )
  ,.\MC_MM_RESP.DATA_valid    (resp_data_valid    )
  ,.\MC_MM_RESP.DATA_ready    (resp_data_ready    )
  ,.\MC_MM_RESP.DATA          (resp_data          )
  ,.\ASYNC_ADDR_ready         (async_addr_ack     )
  ,.\ASYNC_ADDR_valid         (async_addr_req     )
  ,.\ASYNC_ADDR               (async_addr         )
  ,.\ASYNC_CMD_valid          (async_cmd_req      )
  ,.\ASYNC_CMD_ready          (async_cmd_ack      )
  ,.\ASYNC_CMD                (async_cmd          )
  ,.\ASYNC_DATA_IN_valid      (async_data_in_req  )
  ,.\ASYNC_DATA_IN_ready      (async_data_in_ack  )
  ,.\ASYNC_DATA_IN            (async_data_in      )
  ,.\ASYNC_DATA_OUT_valid     (async_data_out_req )
  ,.\ASYNC_DATA_OUT_ready     (async_data_out_ack )
  ,.\ASYNC_DATA_OUT           (async_data_out     )
);


endmodule

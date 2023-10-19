`timescale 1ns/1ps

module cache_tb();

localparam ADDR   = 32;
localparam DATA   = 32;
localparam CMD    = 1;
localparam WIDTH  = 128;
localparam DEPTH  = 8;

reg cpu_valid_in;
wire cpu_ready_in;
reg [ADDR-1:0] cpu_addr_in;
reg [DATA-1:0] cpu_data_in;
reg [CMD -1:0] cpu_cmd_in;
wire cpu_valid_out;
reg cpu_ready_out;
wire [DATA-1:0] cpu_data_out;

wire sd_valid_out;
reg sd_ready_out;
wire [ADDR -1:0] sd_addr_out;
wire [WIDTH-1:0] sd_data_out;
wire [CMD  -1:0] sd_cmd_out;
reg sd_valid_in;
wire sd_ready_in;
reg [WIDTH-1:0] sd_data_in;

reg clock;
initial clock = 0;
always clock = #1 ~clock;

task delay;
input [31:0] d;
begin
  repeat (d) @(posedge clock);
end
endtask

reg reset;
task reset_task;
begin
  reset = 0;
  cpu_valid_in = 0;
  cpu_addr_in = 0;
  cpu_data_in = 0;
  cpu_cmd_in = 0;
  cpu_ready_out = 0;
  sd_ready_out = 0;
  sd_valid_in = 0;
  sd_data_in = 0;
  repeat(100)@(posedge clock);
  reset = 1;
  repeat(100)@(posedge clock);
  reset = 0;
  repeat(100)@(posedge clock);
end
endtask

reg [ADDR-1:0] prev_addr;
task send_read_req;
begin
  cpu_valid_in = 1;
  cpu_addr_in = $random;
  cpu_data_in = $random;
  cpu_cmd_in = 0;
  delay(1);
  cpu_valid_in = 0;
  delay(1);
  prev_addr = cpu_addr_in;
end
endtask

task send_read_req_same;
begin
  cpu_valid_in = 1;
  cpu_addr_in = prev_addr;
  cpu_data_in = $random;
  cpu_cmd_in = 0;
  delay(1);
  cpu_valid_in = 0;
  delay(1);
end
endtask

task send_write_req;
begin
  cpu_valid_in = 1;
  cpu_addr_in = $random;
  cpu_data_in = $random;
  cpu_cmd_in = 1;
  delay(1);
  cpu_valid_in = 0;
  delay(1);
  prev_addr = cpu_addr_in;
end
endtask

task send_write_req_same;
begin
  cpu_valid_in = 1;
  cpu_addr_in = prev_addr;
  cpu_data_in = $random;
  cpu_cmd_in = 1;
  delay(1);
  cpu_valid_in = 0;
  delay(1);
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
    cpu_valid_in = 1;
    cpu_addr_in = {tag,index,offset};
    cpu_data_in = $random;
    cpu_cmd_in = 0;
    delay(1);
    cpu_valid_in = 0;
    index = index + 1;
    delay(1);
    while (!cpu_ready_in) @(posedge clock);
  end
end
endtask

task fill_cache_write;
input [24:0] t;
begin
  tag = t;
  offset = 0;
  index = 0;
  for (i=0;i<DEPTH;i=i+1) begin
    cpu_valid_in = 1;
    cpu_addr_in = {tag,index,offset};
    cpu_data_in = $random;
    cpu_cmd_in = 1;
    delay(1);
    cpu_valid_in = 0;
    index = index + 1;
    delay(1);
    while (!cpu_ready_in) @(posedge clock);
  end
end
endtask

initial begin
  reset_task();
  delay(100);
  send_read_req();
  delay(100);
  send_read_req_same();
  delay(100);
  send_write_req();
  delay(100);
  send_write_req_same();
  delay(100);
  send_read_req_same();
  delay(100);
  fill_cache_read();
  delay(100);
  fill_cache_write(1);
  delay(100);
  fill_cache_write(1);
  delay(100);
  fill_cache_write(0);
  delay(100);
  $finish;
end

always @(posedge clock)
if (reset)                              cpu_ready_out <= 0;
else if (cpu_valid_out & cpu_ready_out) cpu_ready_out <= 0;
else if (cpu_valid_out)                 cpu_ready_out <= 1;
else                                    cpu_ready_out <= cpu_ready_out;

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

cache 
#(
   .ADDR  (ADDR )
  ,.DATA  (DATA )
  ,.CMD   (CMD  )
  ,.WIDTH (WIDTH)
  ,.DEPTH (DEPTH)
) cache (
   .clock         (clock)
  ,.reset         (reset)
  //CPU
  ,.cpu_valid_in  (cpu_valid_in  )
  ,.cpu_ready_in  (cpu_ready_in  )
  ,.cpu_addr_in   (cpu_addr_in   )
  ,.cpu_data_in   (cpu_data_in   )
  ,.cpu_cmd_in    (cpu_cmd_in    )
  ,.cpu_valid_out (cpu_valid_out )
  ,.cpu_ready_out (cpu_ready_out )
  ,.cpu_data_out  (cpu_data_out  )
  //SD CARD
  ,.sd_valid_out  (sd_valid_out  )
  ,.sd_ready_out  (sd_ready_out  )
  ,.sd_addr_out   (sd_addr_out   )
  ,.sd_data_out   (sd_data_out   )
  ,.sd_cmd_out    (sd_cmd_out    )
  ,.sd_valid_in   (sd_valid_in   )
  ,.sd_ready_in   (sd_ready_in   )
  ,.sd_data_in    (sd_data_in    )
);

endmodule

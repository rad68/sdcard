`timescale 1ns/1ps

module cache
#(
   parameter ADDR   = 32    //Address bus bit width
  ,parameter DATA   = 32    //Data bus bit width
  ,parameter CMD    = 1     //Cmd bus bit width
  ,parameter WIDTH  = 4096  //Cache line bit width
  ,parameter DEPTH  = 8     //Number of lines
)
(
   input                  clock
  ,input                  reset
  //ASYNC
  ,input                  cpu_valid_in
  ,output                 cpu_ready_in
  ,input      [ADDR -1:0] cpu_addr_in
  ,input      [DATA -1:0] cpu_data_in
  ,input      [CMD  -1:0] cpu_cmd_in
  ,output                 cpu_valid_out
  ,input                  cpu_ready_out
  ,output reg [DATA -1:0] cpu_data_out
  //SD
  ,output                 sd_valid_out
  ,input                  sd_ready_out
  ,output reg [ADDR -1:0] sd_addr_out
  ,output reg [WIDTH-1:0] sd_data_out
  ,output reg [CMD  -1:0] sd_cmd_out
  ,input                  sd_valid_in
  ,output                 sd_ready_in
  ,input      [WIDTH-1:0] sd_data_in
);

reg cmd;

(* mark_debug = "true" *) wire wb_flag;
(* mark_debug = "true" *) wire hit, miss;

wire cpu_hs_in;
assign cpu_hs_in = cpu_valid_in & cpu_ready_in;
wire cpu_hs_out;
assign cpu_hs_out = cpu_valid_out & cpu_ready_out;
wire sd_hs_in;
assign sd_hs_in = sd_valid_in & sd_ready_in;
wire sd_hs_out;
assign sd_hs_out = sd_valid_out & sd_ready_out;

reg [2:0] state;
wire [2:0] next_state;
localparam  GET_CPU_REQ   = 0,
            WRITEBACK     = 1,
            GET_SD_DATA   = 2,
            WRITE_SD_DATA = 3,
            SEND_SD_REQ   = 4;

wire GET_CPU_REQ_state, WRITEBACK_state, GET_SD_DATA_state, WRITE_SD_DATA_state, SEND_SD_REQ_state;
assign GET_CPU_REQ_state    = ~state[2] & ~state[1] & ~state[0];
assign WRITEBACK_state      = ~state[2] & ~state[1] &  state[0];
assign GET_SD_DATA_state    = ~state[2] &  state[1] & ~state[0];
assign WRITE_SD_DATA_state  = ~state[2] &  state[1] &  state[0];
assign SEND_SD_REQ_state    =  state[2] & ~state[1] & ~state[0];

wire GET_CPU_REQ_next_state, WRITEBACK_next_state, GET_SD_DATA_next_state, WRITE_SD_DATA_next_state, SEND_SD_REQ_next_state;
assign GET_CPU_REQ_next_state    = ~next_state[2] & ~next_state[1] & ~next_state[0];
assign WRITEBACK_next_state      = ~next_state[2] & ~next_state[1] &  next_state[0];
assign GET_SD_DATA_next_state    = ~next_state[2] &  next_state[1] & ~next_state[0];
assign WRITE_SD_DATA_next_state  = ~next_state[2] &  next_state[1] &  next_state[0];
assign SEND_SD_REQ_next_state    =  next_state[2] & ~next_state[1] & ~next_state[0];

assign next_state = GET_CPU_REQ_state   & cpu_hs_in & miss &  wb_flag     ? WRITEBACK     :
                    GET_CPU_REQ_state   & cpu_hs_in & miss & ~wb_flag     ? SEND_SD_REQ   :
                    GET_CPU_REQ_state   & cpu_hs_in & hit  & ~cpu_cmd_in  ? WRITE_SD_DATA :
                    GET_CPU_REQ_state   & cpu_hs_in & hit  &  cpu_cmd_in  ? GET_CPU_REQ   :
                    //WRITEBACK
                    WRITEBACK_state     & sd_hs_out                       ? SEND_SD_REQ   :
                    //DATA FROM SD
                    SEND_SD_REQ_state   & sd_hs_out                       ? GET_SD_DATA   :
                    //READ
                    GET_SD_DATA_state   & sd_hs_in  & ~cmd                ? WRITE_SD_DATA :
                    WRITE_SD_DATA_state & cpu_hs_out                      ? GET_CPU_REQ   :
                    //WRITE
                    GET_SD_DATA_state   & sd_hs_in  &  cmd                ? GET_CPU_REQ   : state;

always @(posedge clock)
if (reset)  state <= GET_CPU_REQ;
else        state <= next_state;

localparam OFFSET = $clog2(WIDTH/8);
localparam INDEX  = $clog2(DEPTH);
localparam TAG    = ADDR-OFFSET-INDEX;

reg [WIDTH-1:0] data_mem [0:DEPTH-1];
reg [TAG  -1:0] tag_mem  [0:DEPTH-1];
reg [      1:0] flag_mem [0:DEPTH-1];

integer k;
initial begin
  for (k=0;k<DEPTH;k=k+1) begin
    data_mem[k] <= 0;
    tag_mem[k]  <= 0;
    flag_mem[k] <= 0;
  end
end

wire [3+OFFSET-1:0] cpu_offset;
wire [INDEX   -1:0] cpu_index;
wire [TAG     -1:0] cpu_tag;
assign cpu_offset = cpu_addr_in[OFFSET-1:0];
assign cpu_index  = cpu_addr_in[OFFSET+INDEX-1:OFFSET];
assign cpu_tag    = cpu_addr_in[OFFSET+INDEX+TAG-1:OFFSET+INDEX];

wire [3+OFFSET-1:0] sd_offset;
wire [INDEX   -1:0] sd_index;
wire [TAG     -1:0] sd_tag;
assign sd_offset = sd_addr_out[OFFSET-1:0];
assign sd_index  = sd_addr_out[OFFSET+INDEX-1:OFFSET];
assign sd_tag    = sd_addr_out[OFFSET+INDEX+TAG-1:OFFSET+INDEX];

wire cmp_tag_cpu;
assign cmp_tag_cpu = tag_mem[cpu_index] == cpu_tag;

wire val_cpu, val_sd;
assign val_cpu = flag_mem[cpu_index][0];
assign val_sd = flag_mem[sd_index][0];

wire cpu_hit, sdc_hit;
assign cpu_hit = cmp_tag_cpu & val_cpu;
assign sdc_hit = sd_hs_in;
assign hit = cpu_hit | sdc_hit;
assign miss = ~cmp_tag_cpu | ~val_cpu;

assign wb_flag = flag_mem[cpu_index][1];

assign cpu_ready_in = GET_CPU_REQ_state;
assign sd_valid_out = SEND_SD_REQ_state | WRITEBACK_state;

always @(posedge clock)
if (reset)                              cmd <= 0;
else if (GET_CPU_REQ_state & cpu_hs_in) cmd <= cpu_cmd_in;
else                                    cmd <= cmd;

reg [ADDR-1:0] tmp_addr;
reg [DATA-1:0] tmp_data;
reg [CMD -1:0] tmp_cmd;
always @(posedge clock)
if (reset) begin
  tmp_addr <= 0;
  tmp_data    <= 0;
  tmp_cmd     <= 0;
end
else if (WRITEBACK_next_state) begin
  tmp_addr <= cpu_addr_in;
  tmp_data <= cpu_data_in;
  tmp_cmd  <= cpu_cmd_in;
end
else begin
  tmp_addr <= tmp_addr;
  tmp_data <= tmp_data;
  tmp_cmd  <= tmp_cmd;
end

always @(posedge clock)
if (reset) begin
  sd_addr_out <= 0;
  sd_data_out <= 0;
  sd_cmd_out  <= 0;
end
else if (WRITEBACK_next_state) begin
  sd_addr_out <= {tag_mem[cpu_index],cpu_index,{OFFSET{1'b0}}};
  sd_data_out <= data_mem[cpu_index];
  sd_cmd_out  <= 1;
end
else if (WRITEBACK_state & SEND_SD_REQ_next_state) begin
  sd_addr_out <= tmp_addr;
  sd_data_out <= tmp_data;
  sd_cmd_out  <= 0;
end
else if (GET_CPU_REQ_state & SEND_SD_REQ_next_state) begin
  sd_addr_out <= cpu_addr_in;
  sd_data_out <= cpu_data_in;
  sd_cmd_out  <= 0;
end
else begin
  sd_addr_out <= sd_addr_out;
  sd_data_out <= sd_data_out;
  sd_cmd_out  <= sd_cmd_out;
end

assign cpu_valid_out = WRITE_SD_DATA_state;

always @(posedge clock)
if (reset)                                        cpu_data_out <= 0;
else if (GET_SD_DATA_state & sdc_hit)             cpu_data_out <= sd_data_in >> (sd_offset << 3);
else if (GET_CPU_REQ_state & cpu_hs_in & cpu_hit) cpu_data_out <= data_mem[cpu_index] >> (cpu_offset << 3);
else                                              cpu_data_out <= cpu_data_out;

assign sd_ready_in  = GET_SD_DATA_state;

reg [WIDTH-1:0] mask;
always @(posedge clock)
if (reset)  mask <= {DATA{1'b1}};
else        mask <= mask;

always @(posedge clock)
if (GET_SD_DATA_state & sd_hs_in) begin
  data_mem[sd_index]    <= cmd ? sd_data_in & ~(mask << (sd_offset << 3)) | (sd_data_out << (sd_offset << 3)) : sd_data_in;
  tag_mem[sd_index]     <= sd_tag;
  flag_mem[sd_index][0] <= 1;
  flag_mem[sd_index][1] <= 0;
end
else if (GET_CPU_REQ_state & cpu_hs_in & hit & cpu_cmd_in) begin
  data_mem[cpu_index]    <= data_mem[cpu_index] & ~(mask << (cpu_offset << 3)) | (cpu_data_in << (cpu_offset << 3));
  tag_mem[cpu_index]     <= tag_mem[cpu_index];
  flag_mem[cpu_index][0] <= flag_mem[cpu_index][0];
  flag_mem[cpu_index][1] <= 1;
end

endmodule

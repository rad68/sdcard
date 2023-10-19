`timescale 1ns/1ps

module sdcard_glue_cpu
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
  //CPU
  ,output                 async_addr_ack
  ,input                  async_addr_req
  ,input      [ADDR -1:0] async_addr
  ,input                  async_cmd_req
  ,output                 async_cmd_ack
  ,input                  async_cmd
  ,input                  async_data_out_req
  ,output                 async_data_out_ack
  ,input      [DATA -1:0] async_data_out
  ,output                 async_data_in_req
  ,input                  async_data_in_ack
  ,output     [DATA -1:0] async_data_in
  //CACHE
  ,output                   cpu_valid_in
  ,input                    cpu_ready_in
  ,output reg [ADDR   -1:0] cpu_addr_in
  ,output reg [2*DATA -1:0] cpu_data_in
  ,output reg [CMD    -1:0] cpu_cmd_in
  ,input                    cpu_valid_out
  ,output                   cpu_ready_out
  ,input      [2*DATA -1:0] cpu_data_out
);

localparam  GET_CPU_ADDR    = 0,
            GET_CPU_CMD     = 1,
            GET_CPU_DATA_0  = 2,
            GET_CPU_DATA_1  = 3,
            WRITE_CPU_DATA  = 4,
            GET_SD_DATA     = 5,
            WRITE_SD_DATA_0 = 6,
            WRITE_SD_DATA_1 = 7;

reg [2:0] state;
wire [2:0] next_state;

wire GET_CPU_ADDR_state, GET_CPU_CMD_state, GET_CPU_DATA_0_state,
     GET_CPU_DATA_1_state, WRITE_CPU_DATA_state, GET_SD_DATA_state,
     WRITE_SD_DATA_0_state, WRITE_SD_DATA_1_state;

assign GET_CPU_ADDR_state     = ~state[2] & ~state[1] & ~state[0];
assign GET_CPU_CMD_state      = ~state[2] & ~state[1] &  state[0];
assign GET_CPU_DATA_0_state   = ~state[2] &  state[1] & ~state[0];
assign GET_CPU_DATA_1_state   = ~state[2] &  state[1] &  state[0];
assign WRITE_CPU_DATA_state   =  state[2] & ~state[1] & ~state[0];
assign GET_SD_DATA_state      =  state[2] & ~state[1] &  state[0];
assign WRITE_SD_DATA_0_state  =  state[2] &  state[1] & ~state[0];
assign WRITE_SD_DATA_1_state  =  state[2] &  state[1] &  state[0];

always @(posedge clock)
if (reset)  state <= GET_CPU_ADDR;
else        state <= next_state;

assign next_state = GET_CPU_ADDR_state    & async_addr_ack      & async_addr_req             ? GET_CPU_CMD      :
                    GET_CPU_CMD_state     & async_cmd_ack       & async_cmd_req & async_cmd  ? GET_CPU_DATA_0   :
                    //WRITE
                    GET_CPU_DATA_0_state  & async_data_out_req  & async_data_out_ack         ? GET_CPU_DATA_1   :
                    GET_CPU_DATA_1_state  & async_data_out_req  & async_data_out_ack         ? WRITE_CPU_DATA   :
                    WRITE_CPU_DATA_state  & cpu_valid_in        & cpu_ready_in & cpu_cmd_in  ? GET_CPU_ADDR     :
                    //READ
                    GET_CPU_CMD_state     & async_cmd_ack       & async_cmd_req & ~async_cmd ? WRITE_CPU_DATA   :
                    WRITE_CPU_DATA_state  & cpu_valid_in        & cpu_ready_in  & ~cpu_cmd_in? GET_SD_DATA      :
                    GET_SD_DATA_state     & cpu_valid_out       & cpu_ready_out              ? WRITE_SD_DATA_0  :
                    WRITE_SD_DATA_0_state & async_data_in_req   & async_data_in_ack          ? WRITE_SD_DATA_1  : 
                    WRITE_SD_DATA_1_state & async_data_in_req   & async_data_in_ack          ? GET_CPU_ADDR     : state;

assign async_addr_ack = GET_CPU_ADDR_state;
assign async_cmd_ack = GET_CPU_CMD_state;
assign async_data_out_ack = GET_CPU_DATA_0_state | GET_CPU_DATA_1_state;

always @(posedge clock)
if (reset)                                                  cpu_cmd_in <= 0;
else if (GET_CPU_CMD_state & async_cmd_req & async_cmd_ack) cpu_cmd_in <= async_cmd;
else                                                        cpu_cmd_in <= cpu_cmd_in;

assign cpu_valid_in = WRITE_CPU_DATA_state;
assign cpu_ready_out = GET_SD_DATA_state;

always @(posedge clock)
if (reset)                                                                cpu_data_in <= 0;
else if (GET_CPU_DATA_0_state & async_data_out_ack & async_data_out_req)  cpu_data_in <= {cpu_data_in[63:32],async_data_out};
else if (GET_CPU_DATA_1_state & async_data_out_ack & async_data_out_req)  cpu_data_in <= {async_data_out,cpu_data_in[31:0] };
else                                                                      cpu_data_in <= cpu_data_in;

always @(posedge clock)
if (reset)                                                      cpu_addr_in <= 0;
else if (GET_CPU_ADDR_state & async_addr_ack & async_addr_req)  cpu_addr_in <= async_addr;
else                                                            cpu_addr_in <= cpu_addr_in;

reg [2*DATA-1:0] data;
always @(posedge clock)
if (reset)                                                              data <= 0;
else if (GET_SD_DATA_state & cpu_valid_out & cpu_ready_out)             data <= cpu_data_out;
else if (WRITE_SD_DATA_0_state & async_data_in_req & async_data_in_ack) data <= data >> DATA;
else                                                                    data <= data;

assign async_data_in_req = WRITE_SD_DATA_0_state | WRITE_SD_DATA_1_state;
assign async_data_in = data[DATA-1:0];

endmodule

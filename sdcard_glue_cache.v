`timescale 1ns/1ps

module sdcard_glue_cache
#(
   parameter ADDR   = 32    //Address bus bit width
  ,parameter DATA   = 8     //Data bus bit width
  ,parameter CMD    = 1     //Cmd bus bit width
  ,parameter WIDTH  = 4096  //Cache line bit width
  ,parameter DEPTH  = 8     //Number of lines
)
(
   input                  clock
  ,input                  reset
  //CACHE
  ,input                  sd_valid_out
  ,output                 sd_ready_out
  ,input      [ADDR -1:0] sd_addr_out
  ,input      [WIDTH-1:0] sd_data_out
  ,input      [CMD  -1:0] sd_cmd_out
  ,output                 sd_valid_in
  ,input                  sd_ready_in
  ,output     [WIDTH-1:0] sd_data_in
  //SD
  ,output                 rd
  ,input      [DATA -1:0] dout
  ,input                  dout_valid
  ,output                 wr
  ,output     [DATA -1:0] din
  ,input                  din_ready
  ,input                  ready
  ,output reg [ADDR -1:0] ain
);

localparam FRAME = 512;
reg [$clog2(FRAME):0] byte_cnt;

wire sd_hs_in;
assign sd_hs_in = sd_valid_in & sd_ready_in;
wire sd_hs_out;
assign sd_hs_out = sd_valid_out & sd_ready_out;

reg [2:0] state;
wire [2:0] next_state;

localparam  GET_REQ       = 0,
            SEND_WR_REQ   = 1,
            SEND_WR_DATA  = 2,
            SEND_RD_REQ   = 3,
            GET_RD_DATA   = 4,
            SEND_RD_DATA  = 5;

wire GET_REQ_state, SEND_WR_REQ_state, SEND_WR_DATA_state, SEND_RD_REQ_state, GET_RD_DATA_state;
wire SEND_RD_DATA_state;
assign GET_REQ_state      = ~state[2] & ~state[1] & ~state[0];
assign SEND_WR_REQ_state  = ~state[2] & ~state[1] &  state[0];
assign SEND_WR_DATA_state = ~state[2] &  state[1] & ~state[0];
assign SEND_RD_REQ_state  = ~state[2] &  state[1] &  state[0];
assign GET_RD_DATA_state  =  state[2] & ~state[1] & ~state[0];
assign SEND_RD_DATA_state =  state[2] & ~state[1] &  state[0];

always @(posedge clock)
if (reset)  state <= GET_REQ;
else        state <= next_state;

assign next_state = GET_REQ_state       & sd_hs_out & ~sd_cmd_out ? SEND_RD_REQ   :
                    GET_REQ_state       & sd_hs_out &  sd_cmd_out ? SEND_WR_REQ   :
                    //READ              
                    SEND_RD_REQ_state   & ready     & rd          ? GET_RD_DATA   :
                    GET_RD_DATA_state   & byte_cnt  < FRAME       ? GET_RD_DATA   :
                    GET_RD_DATA_state   & byte_cnt == FRAME       ? SEND_RD_DATA  :
                    SEND_RD_DATA_state  & sd_hs_in                ? GET_REQ       :
                    //WRITE             
                    SEND_WR_REQ_state   & ready     & wr          ? SEND_WR_DATA  :
                    SEND_WR_DATA_state  & byte_cnt  < FRAME       ? SEND_WR_DATA  :
                    SEND_WR_DATA_state  & byte_cnt == FRAME       ? GET_REQ       : state;

assign sd_valid_in  = SEND_RD_DATA_state;
assign sd_ready_out = GET_REQ_state;

assign rd = SEND_RD_REQ_state;
assign wr = SEND_WR_REQ_state;

always @(posedge clock)
if (reset)                                byte_cnt <= 0;
else if (byte_cnt == FRAME)               byte_cnt <= 0;
else if (SEND_WR_DATA_state & din_ready)  byte_cnt <= byte_cnt + 1;
else if (GET_RD_DATA_state & dout_valid)  byte_cnt <= byte_cnt + 1;
else                                      byte_cnt <= byte_cnt;

always @(posedge clock)
if (reset)                          ain <= 0;
else if (GET_REQ_state & sd_hs_out) ain <= sd_addr_out >> 9;
else                                ain <= ain;

reg [4095:0] data;
always @(posedge clock)
if (reset)                                        data <= 0;
else if (SEND_WR_DATA_state & din_ready)          data <= data >> 8;
else if (GET_RD_DATA_state  & dout_valid)         data <= {dout, data[4095:8]};
else if (GET_REQ_state & sd_cmd_out & sd_hs_out)  data <= sd_data_out;
else                                              data <= data;

assign din = data[7:0];
assign sd_data_in = data[WIDTH-1:0];

endmodule

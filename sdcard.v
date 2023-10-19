`timescale 1ns / 1ps

`define CMD0  56'hFF_40_00_00_00_00_95
`define CMD8  56'hFF_48_00_00_01_AA_87
`define CMD17 24'hFF_51
`define CMD24 24'hFF_58
`define CMD41 56'hFF_69_40_00_00_00_01
`define CMD55 56'hFF_77_00_00_00_00_01
`define CMD58 56'hFF_7A_00_00_00_00_01

`define CTRL_TOKEN_0 8'hFE
`define CTRL_TOKEN_1 8'hFC
`define CTRL_TOKEN_2 8'hFD

module sd_controller
#(
   FREQ = 10000000
  ,RAMP = 80
  ,BLOCK_SIZE = 513
)(
   input              clock
  ,input              reset

  ,output reg         cs
  ,output             mosi
  ,input              miso
  ,output reg         sclk

  ,input              rd
  ,output     [ 7:0]  dout
  ,output reg         dout_valid

  ,input              wr
  ,input      [ 7:0]  din
  ,output             din_ready

  ,output             ready
  ,input      [31:0]  ain
);

localparam  MIL_SEC = FREQ/1000;

reg [31:0] pwr_cnt;
reg [ 2:0] bit_cnt;
reg [ 9:0] block_cnt;
reg [ 7:0] send_byte_cnt, recv_byte_cnt;
reg [ 7:0] ramp_cnt;
reg recv, poll, read, write;

localparam  PWR_UP        = 0,
            RAMP_UP       = 1,
            SEND_CMD0     = 2,
            SEND_CMD8     = 3,
            SEND_CMD17    = 4,
            SEND_CMD24    = 5,
            SEND_CMD41    = 6,
            SEND_CMD55    = 7,
            SEND_CMD58    = 8,
            RECV_WR_BYTE  = 9,
            SEND_WR_BYTE  = 10,
            RECV_RD_BYTE  = 11,
            SEND_RD_BYTE  = 12,
            IDLE          = 13,
            WAIT_RD       = 14,
            WAIT_WR       = 15;

reg [5:0] state, goto_state;
wire [5:0] next_state;

wire  PWR_UP_state, SEND_CMD0_state, SEND_CMD8_state, SEND_CMD17_state,
      SEND_CMD24_state, SEND_CMD41_state, SEND_CMD55_state, SEND_CMD58_state,
      RECV_WR_BYTE_state, SEND_WR_BYTE_state, RECV_RD_BYTE_state, SEND_RD_BYTE_state,
      RAMP_UP_state, IDLE_state, WAIT_RD_state, WAIT_WR_state;

assign PWR_UP_state       = state == PWR_UP;
assign RAMP_UP_state      = state == RAMP_UP;
assign IDLE_state         = state == IDLE;
assign WAIT_RD_state      = state == WAIT_RD;
assign WAIT_WR_state      = state == WAIT_WR;
assign SEND_CMD0_state    = state == SEND_CMD0;
assign SEND_CMD8_state    = state == SEND_CMD8;
assign SEND_CMD17_state   = state == SEND_CMD17;
assign SEND_CMD24_state   = state == SEND_CMD24;
assign SEND_CMD41_state   = state == SEND_CMD41;
assign SEND_CMD55_state   = state == SEND_CMD55;
assign SEND_CMD58_state   = state == SEND_CMD58;
assign RECV_WR_BYTE_state = state == RECV_WR_BYTE;
assign SEND_WR_BYTE_state = state == SEND_WR_BYTE;
assign RECV_RD_BYTE_state = state == RECV_RD_BYTE;
assign SEND_RD_BYTE_state = state == SEND_RD_BYTE;

assign next_state = PWR_UP_state & pwr_cnt == MIL_SEC                 ? RAMP_UP       :
                    RAMP_UP_state & ramp_cnt == 0                     ? SEND_CMD0     : 
                    SEND_CMD0_state                                   ? SEND_WR_BYTE  :
                    SEND_CMD8_state                                   ? SEND_WR_BYTE  :
                    SEND_CMD55_state                                  ? SEND_WR_BYTE  :
                    SEND_CMD41_state                                  ? SEND_WR_BYTE  :
                    SEND_CMD58_state                                  ? SEND_WR_BYTE  :
                                                                      
                    IDLE_state & rd                                   ? SEND_CMD17    :
                    IDLE_state & wr                                   ? SEND_CMD24    :
                    SEND_CMD17_state                                  ? SEND_WR_BYTE  :
                    SEND_CMD24_state                                  ? SEND_WR_BYTE  :
                                                                      
                    WAIT_RD_state &  read                             ? RECV_RD_BYTE  :
                    WAIT_WR_state                                     ? goto_state    :

                    RECV_WR_BYTE_state                                ? SEND_WR_BYTE  :
                    SEND_WR_BYTE_state & !write & send_byte_cnt == 0  ? RECV_RD_BYTE  :
                    SEND_WR_BYTE_state &  write & send_byte_cnt == 0  ? RECV_WR_BYTE  :

                    SEND_RD_BYTE_state &  read                        ? RECV_RD_BYTE  :
                    SEND_RD_BYTE_state & !read                        ? WAIT_RD       :
                    RECV_RD_BYTE_state & recv_byte_cnt == 0           ? goto_state    :

                    state;

always @(posedge clock)
if (reset)  state <= PWR_UP;
else        state <= next_state;

reg [55:0] cmd;
reg out_sel;
reg [7:0] data;
reg [31:0] addr;

always @(posedge clock)
if (reset)  begin
  cmd           <= 0;
  bit_cnt       <= 0;
  send_byte_cnt <= 0; 
  recv_byte_cnt <= 0;
  block_cnt     <= 0;
  ramp_cnt      <= 0;
  goto_state    <= PWR_UP;
  pwr_cnt       <= 0;
  out_sel       <= 0;

  recv          <= 0;
  poll          <= 0;
  read          <= 0;
  write         <= 0;
  data          <= 0;
  addr          <= 0;

  sclk          <= 0;
  cs            <= 1;

  dout_valid    <= 0;
end
else if (PWR_UP_state) begin
  pwr_cnt <= pwr_cnt + 1;
  if (pwr_cnt == MIL_SEC) begin
    ramp_cnt      <= RAMP;
    data          <= 8'hFF;
    out_sel       <= 1;
  end
end

else if (RAMP_UP_state) begin
  if (sclk == 1)
    ramp_cnt <= ramp_cnt - 1;
  if (ramp_cnt > 0)
    sclk <= ~sclk;
end

else if (SEND_CMD0_state) begin
  cmd           <= `CMD0;
  out_sel       <= 0;
  bit_cnt       <= 0;
  send_byte_cnt <= 7; 
  recv_byte_cnt <= 1;
  goto_state    <= SEND_CMD8;
  recv          <= 0;

  cs            <= 0;
  sclk          <= 0;
end

else if (SEND_CMD8_state) begin
  cmd           <= `CMD8;
  out_sel       <= 0;
  bit_cnt       <= 0;
  send_byte_cnt <= 7; 
  recv_byte_cnt <= 5;
  goto_state    <= SEND_CMD55;
  recv          <= 0;

  sclk          <= 0;
end


else if (IDLE_state) begin
  block_cnt <= 0;
  sclk      <= 0;
  if (rd | wr) addr <= ain;
  read  <= 0;
  write <= 0;
end

else if (WAIT_RD_state) begin
  goto_state <= SEND_RD_BYTE;
  recv_byte_cnt <= 1;

  if (sclk & !miso)
    read <= 1;

  if (!read)
    sclk <= ~sclk;
end

else if (SEND_CMD17_state) begin
  cmd           <= {`CMD17, addr, 8'hFF};
  out_sel       <= 0;
  bit_cnt       <= 0;
  send_byte_cnt <= 7; 
  recv_byte_cnt <= 1;
  goto_state    <= WAIT_RD;
  recv          <= 0;

  sclk          <= 0;
end

else if (SEND_RD_BYTE_state) begin
  bit_cnt       <= 0;
  sclk          <= 0;

  if (block_cnt == BLOCK_SIZE) begin
    goto_state    <= IDLE;
    recv_byte_cnt <= 2;
  end
  else begin
    goto_state    <= SEND_RD_BYTE;
    recv_byte_cnt <= 1;
    dout_valid    <= 1;
  end
end

else if (WAIT_WR_state) begin
  if (sclk & miso) begin
    sclk <= 0;
    goto_state <= IDLE;
  end
  else
    sclk <= ~sclk;
end

else if (SEND_CMD24_state) begin
  cmd           <= {`CMD24, addr, 8'hFF};
  out_sel       <= 0;
  bit_cnt       <= 0;
  send_byte_cnt <= 7;
  recv_byte_cnt <= 1;
  goto_state    <= RECV_WR_BYTE;
  recv          <= 0;

  sclk          <= 0;
end

else if (RECV_WR_BYTE_state) begin
  bit_cnt <= 0;
  if (write) begin
    out_sel <= 1;
    data <= din;
    send_byte_cnt <= 1;
    recv_byte_cnt <= 0;
  end
  else begin
    if (block_cnt == BLOCK_SIZE) begin
      out_sel         <= 0;
      cmd             <= 56'h80_00_00_00_00_00_00;
      recv_byte_cnt   <= 1;
      send_byte_cnt   <= 0;
      recv            <= 0;
      goto_state      <= WAIT_WR;
    end
    else begin
      out_sel       <= 1;
      recv          <= 0;
      write         <= 1;
      send_byte_cnt <= 1;
      recv_byte_cnt <= 0;
      data <= `CTRL_TOKEN_0;
    end
  end
end

else if (SEND_CMD41_state) begin
  cmd           <= `CMD41;
  out_sel       <= 0;
  bit_cnt       <= 0;
  send_byte_cnt <= 7; 
  recv_byte_cnt <= 1;
  goto_state    <= SEND_CMD55;
  recv          <= 0;
  poll          <= 1;

  sclk          <= 0;
end

else if (SEND_CMD55_state)
begin
  out_sel       <= 0;
  bit_cnt       <= 0;
  recv          <= 0;

  if (poll & data == 8'h00) begin
    cmd           <= 0;
    goto_state    <= SEND_CMD58;
    send_byte_cnt <= 0; 
    recv_byte_cnt <= 0;
    poll          <= 0;
  end
  else begin
    cmd           <= `CMD55;
    goto_state    <= SEND_CMD41;
    send_byte_cnt <= 7; 
    recv_byte_cnt <= 1;
  end

  sclk          <= 0;
end

else if (SEND_CMD58_state) begin
  cmd           <= `CMD58;
  out_sel       <= 0;
  bit_cnt       <= 0;
  send_byte_cnt <= 7; 
  recv_byte_cnt <= 5;
  goto_state    <= IDLE;
  recv          <= 0;

  sclk          <= 0;
end

else if (SEND_WR_BYTE_state) begin
  if (sclk & !out_sel)
    cmd <= {cmd[54:0],1'b1};
  else if (sclk & out_sel)
    data <= {data[6:0],1'b1};

  if (sclk)
    bit_cnt <= bit_cnt + 1;

  if (sclk == 1 & bit_cnt == 7) begin
    send_byte_cnt <= send_byte_cnt - 1;
    if (write)
      block_cnt <= block_cnt + 1;
      if (block_cnt == BLOCK_SIZE-1)
        write <= 0;
  end

  if (send_byte_cnt != 0)
    sclk <= ~sclk;

end

else if (RECV_RD_BYTE_state) begin
  dout_valid <= 0;
  if ((!miso | recv) & sclk) begin
    data <= {data[6:0], miso};
    recv <= 1;
    bit_cnt <= bit_cnt + 1;
    if (sclk == 1 & bit_cnt == 7) begin
      recv_byte_cnt <= recv_byte_cnt - 1;
      if (read)
        block_cnt   <= block_cnt + 1;
    end
  end
  if (recv_byte_cnt != 0)
    sclk <= ~sclk;
end

else begin
  cmd           <= cmd;
  bit_cnt       <= bit_cnt;
  send_byte_cnt <= send_byte_cnt;
  recv_byte_cnt <= recv_byte_cnt;
  goto_state    <= goto_state;
end

assign mosi = out_sel ? data[7] : cmd[55];

assign dout = data;

assign ready = IDLE_state;

assign din_ready = RECV_WR_BYTE_state & write;

endmodule

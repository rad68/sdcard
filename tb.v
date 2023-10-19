`timescale 1ns / 1ps

module tb();

reg clock;
initial clock = 0;
always clock = #1 ~clock;

wire mosi;
reg miso;
wire sclk, cs;

wire [7:0] dout;
wire        dout_valid, din_ready, ready;
reg rd, wr;
reg [7:0] din;
reg [31:0] address;
wire [4:0] status;

reg reset;

integer i,k;

initial begin
  reset = 0;
  repeat(100)@(posedge clock);
  reset = 1;
  miso = 0;
  rd = 0;
  wr = 0;
  din = 0;
  address = 0;
  repeat(100)@(posedge clock);
  reset = 0;
  //READING
  while (!ready) @(posedge clock);
  repeat(10)@(posedge clock);
  rd = 1;
  address = $random;
  repeat(1)@(posedge clock);
  rd = 0;
  repeat(100)@(posedge clock);
  for (i=0; i<16; i=i+1) begin
    for (k=0; k < 8; k=k+1) begin
      @(negedge sclk);
      miso = $random;
    end
  end
  //WRITING
  while (!ready) @(posedge clock);
  wr = 1;
  din = $random;
  address = $random;
  @(posedge clock);
  wr = 0;
  for (i=0; i<16; i=i+1) begin
    while (!din_ready) @(posedge clock);
    din = $random;
  end
  repeat(200)@(posedge clock);
  miso = 1;
  while (!ready) @(posedge clock);
  miso = 0;
  repeat(100)@(posedge clock);

  $finish;
end

sd_controller 
#(
    .FREQ(100)
   ,.RAMP(10)
   ,.BLOCK_SIZE(15)
)sd(
   .cs                  (cs)
  ,.mosi                (mosi)
  ,.miso                (miso)
  ,.sclk                (sclk)
  ,.rd                  (rd)
  ,.dout                (dout)
  ,.dout_valid          (dout_valid)
  ,.wr                  (wr)
  ,.din                 (din)
  ,.din_ready           (din_ready)
  ,.reset               (reset)
  ,.ready               (ready)
  ,.ain                 (address)
  ,.clock               (clock)
);

endmodule

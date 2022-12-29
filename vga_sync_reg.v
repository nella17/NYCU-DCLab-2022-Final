`timescale 1ns / 1ps

module vga_sync_reg(
  input clk, 
  input reset,
  output reg oHS, 
  output reg oVS, 
  output reg visible, 
  output reg p_tick,
  output reg [9:0] pixel_x, 
  output reg [9:0] pixel_y
);
  parameter DELAY = 4;

  wire oHS_;
  wire oVS_;
  wire visible_;
  wire p_tick_;
  wire [9:0] pixel_x_;
  wire [9:0] pixel_y_;

  reg [DELAY-1:0] oHS_reg;
  reg [DELAY-1:0] oVS_reg;
  reg [DELAY-1:0] visible_reg;
  reg [DELAY-1:0] p_tick_reg;

  vga_sync vga_sync_0(
    .clk(clk), 
    .reset(reset),
    .oHS(oHS_), 
    .oVS(oVS_), 
    .visible(visible_), 
    .p_tick(p_tick_),
    .pixel_x(pixel_x_),
    .pixel_y(pixel_y_)
  );

  always @(posedge clk) begin
    { oHS, oHS_reg } <= { oHS_reg, oHS_ };
    { oVS, oVS_reg } <= { oVS_reg, oVS_ };

    { visible, visible_reg } <= { visible_reg, visible_ };
    { p_tick, p_tick_reg } <= { p_tick_reg, p_tick_ };

    pixel_x <= pixel_x_;
    pixel_y <= pixel_y_;
  end

endmodule

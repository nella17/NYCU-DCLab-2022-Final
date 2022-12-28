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

  wire oHS_;
  wire oVS_;
  wire visible_;
  wire p_tick_;
  wire [9:0] pixel_x_;
  wire [9:0] pixel_y_;

  reg oHS_reg [3:0];
  reg oVS_reg [3:0];
  reg visible_reg [3:0];
  reg p_tick_reg [3:0];

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
    oHS        <= oHS_reg[3];
    oHS_reg[3] <= oHS_reg[2];
    oHS_reg[2] <= oHS_reg[1];
    oHS_reg[1] <= oHS_reg[0];
    oHS_reg[0] <= oHS_;

    oVS        <= oVS_reg[3];
    oVS_reg[3] <= oVS_reg[2];
    oVS_reg[2] <= oVS_reg[1];
    oVS_reg[1] <= oVS_reg[0];
    oVS_reg[0] <= oVS_;
    
    visible        <= visible_reg[3];
    visible_reg[3] <= visible_reg[2];
    visible_reg[2] <= visible_reg[1];
    visible_reg[1] <= visible_reg[0];
    visible_reg[0] <= visible_;

    p_tick        <= p_tick_reg[3];
    p_tick_reg[3] <= p_tick_reg[2];
    p_tick_reg[2] <= p_tick_reg[1];
    p_tick_reg[1] <= p_tick_reg[0];
    p_tick_reg[0] <= p_tick_;

    pixel_x <= pixel_x_;

    pixel_y <= pixel_y_;
  end

endmodule

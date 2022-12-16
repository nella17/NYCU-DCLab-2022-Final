`timescale 1ns / 1ps
`define N2T(i, bits, in, of, out, off) \
    for(i = 0; i < bits; i = i+1) \
        out[8*(off+i) +: 8] <= in[(i+of)*4 +: 4] + ((in[(i+of)*4 +: 4] < 10) ? "0" : "A"-10);

module final_project import enum_type::*;
(
  input  clk,
  input  reset_n,
  input  [3:0] usr_btn,
  output [3:0] usr_led,

  // VGA specific I/O ports
  output VGA_HSYNC,
  output VGA_VSYNC,
  output reg [3:0] VGA_RED,
  output reg [3:0] VGA_GREEN,
  output reg [3:0] VGA_BLUE,

  input  uart_rx,
  output uart_tx,

  output LCD_RS,
  output LCD_RW,
  output LCD_E,
  output [3:0] LCD_D
);

  // General VGA control signals
  wire clk_50MHz;       // 50MHz clock for VGA control
  wire visible;         // when visible is 0, the VGA controller is sending
                        // synchronization signals to the display device.
  wire p_tick;          // when p_tick is 1, we must update the RGB value
                        // based for the new coordinate (pixel_x, pixel_y)
  wire [9:0] pixel_x;   // x coordinate of the next pixel (between 0 ~ 639) 
  wire [9:0] pixel_y;   // y coordinate of the next pixel (between 0 ~ 479)

  reg [3:0] tetris_x;
  reg [4:0] tetris_y;
  reg inside_tetris;
  state_type tetris_ctrl, tetris_state;
  wire [4*4-1:0] tetris_score;
  wire [2:0] tetris_type;
  wire [2:0] tetris_hold;
  wire [2:0] tetris_next [0:3];

  /*clk_divider#(2) clk_divider0(
    .clk(clk),
    .reset(~reset_n),
    .clk_out(clk_50MHz)
  );*/

  clk_wiz_0 clk_wiz_0_0(
    .clk_50MHz(clk_50MHz),
    .clk_in1(clk)
  );

  control control(
    .clk(clk_50MHz),
    .reset_n(reset_n),
    .usr_btn(usr_btn),
    .uart_rx(uart_rx),
    .uart_tx(uart_tx),
    .state(tetris_state),
    .control(tetris_ctrl)
  );

  tetris tetris0(
    .clk(clk_50MHz),
    .reset_n(reset_n),
    .x(tetris_x), 
    .y(tetris_y), 
    .ctrl(tetris_ctrl),
    .state(tetris_state),
    .score(tetris_score),
    .kind(tetris_type),
    .hold(tetris_hold),
    .next(tetris_next)
  );

  vga_sync_reg vs0(
    .clk(clk_50MHz), .reset(~reset_n), .oHS(VGA_HSYNC), .oVS(VGA_VSYNC),
    .visible(visible), .p_tick(p_tick),
    .pixel_x(pixel_x), .pixel_y(pixel_y)
  );

  assign usr_led = usr_btn;

  always @(posedge clk_50MHz) begin
    tetris_x <= (pixel_x - 220) / 20;
    tetris_y <= (pixel_y - 40) / 20;
    inside_tetris <= (220 <= pixel_x) & (pixel_x < 420) & (40 <= pixel_y) & (pixel_y < 440);
  end

  always @(posedge clk_50MHz) begin
    if (p_tick) begin
      if (visible & inside_tetris) begin
        case (tetris_type)
          3'b000: {VGA_RED, VGA_GREEN, VGA_BLUE} <= 12'h000;
          3'b001: {VGA_RED, VGA_GREEN, VGA_BLUE} <= 12'h09D;
          3'b010: {VGA_RED, VGA_GREEN, VGA_BLUE} <= 12'h04F;
          3'b011: {VGA_RED, VGA_GREEN, VGA_BLUE} <= 12'hD90;
          3'b100: {VGA_RED, VGA_GREEN, VGA_BLUE} <= 12'hFF0;
          3'b101: {VGA_RED, VGA_GREEN, VGA_BLUE} <= 12'h0F3;
          3'b110: {VGA_RED, VGA_GREEN, VGA_BLUE} <= 12'h80C;
          3'b111: {VGA_RED, VGA_GREEN, VGA_BLUE} <= 12'hF00;
        endcase
      end
      else {VGA_RED, VGA_GREEN, VGA_BLUE} <= 12'h111;
    end
  end

  reg [127:0] row_A = 0;
  reg [127:0] row_B = 0;

  LCD_module lcd0( 
    .clk(clk),
    .reset(~reset_n),
    .row_A(row_A),
    .row_B(row_B),
    .LCD_E(LCD_E),
    .LCD_RS(LCD_RS),
    .LCD_RW(LCD_RW),
    .LCD_D(LCD_D)
  );

  reg [7:0] i;
  wire [7:0] ns = tetris_state;
  wire [7:0] nc = tetris_ctrl;
  always_ff @(posedge clk) begin
    if (~reset_n)
      { row_A, row_B } <= 0;
    else begin
      `N2T(i, 2, ns, 0, row_A, 0)
      `N2T(i, 2, nc,  0, row_B, 0)
    end
  end

endmodule

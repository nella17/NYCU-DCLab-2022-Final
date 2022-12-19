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

  wire [3:0] tetris_x;
  wire [4:0] tetris_y;
  reg inside_tetris;
  state_type tetris_ctrl, tetris_state;
  wire [9:0] tetris_bar_mask = 10'b1110111111;
  wire [4*4-1:0] tetris_score;
  wire [2:0] tetris_kind;
  wire [2:0] tetris_hold;
  wire [2:0] tetris_next [0:3];

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
    .bar_mask(tetris_bar_mask),
    .state(tetris_state),
    .score(tetris_score),
    .kind(tetris_kind),
    .hold(tetris_hold),
    .next(tetris_next)
  );

  display display0(
    .clk(clk_50MHz),
    .reset_n(reset_n),
    .kind(tetris_kind),
    .tetris_score(tetris_score),
    .tetris_x(tetris_x), 
    .tetris_y(tetris_y),
    .VGA_HSYNC(VGA_HSYNC),
    .VGA_VSYNC(VGA_VSYNC),
    .VGA_RED(VGA_RED),
    .VGA_GREEN(VGA_GREEN),
    .VGA_BLUE(VGA_BLUE)
  );

  assign usr_led = usr_btn;

  localparam row_init = "????????????????";

  reg [127:0] row_A = row_init;
  reg [127:0] row_B = row_init;

  LCD_module lcd0( 
    .clk(clk_50MHz),
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
  reg [7:0] nc;
  always_ff @(posedge clk_50MHz)
      if (~reset_n)
          nc <= 0;
      else if (tetris_ctrl != NONE)
          nc <= tetris_ctrl;
  always_ff @(posedge clk_50MHz) begin
    if (~reset_n)
      { row_A, row_B } <= { row_init, row_init };
    else begin
      `N2T(i, 2, ns, 0, row_A, 0)
      `N2T(i, 2, nc, 0, row_B, 0)
      row_A[37:30] <= ns + 8'h22;
      row_B[37:30] <= nc + 8'h22;
      `N2T(i, 4, tetris_score, 0, row_B, 8)
    end
  end

endmodule

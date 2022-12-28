`timescale 1ns / 1ps
`define N2T(i, bits, in, of, out, off) \
    for(i = 0; i < bits; i = i+1) \
        out[8*(off+i) +: 8] <= in[(i+of)*4 +: 4] + ((in[(i+of)*4 +: 4] < 10) ? "0" : "A"-10);

module final_project import enum_type::*;
(
  input  clk,
  input  reset_n,
  input  [3:0] usr_btn,
  input  [3:0] usr_sw,
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
  wire clk_25MHz;       // 25MHz clock for VGA control

  wire [4:0] tetris_x, tetris_y;
  state_type tetris_ctrl, tetris_state;
  wire [9:0] tetris_bar_mask;
  wire [4*4-1:0] tetris_score;
  wire [3:0] tetris_kind, tetris_hold, tetris_next[0:3];
  wire hold_locked, start, over;
  logic [$clog2(COUNT_SEC)+2:0] count_down;
  logic [4:0] pending_counter;
  wire [2*4-1:0] combo;
  wire t_spin;

  wire [31:0] rng;

  clk_wiz_0 clk_wiz_0_0(
    .clk_25MHz(clk_25MHz),
    .clk_in1(clk)
  );

  prng prng0(
    .clk(clk_25MHz),
    .reset_n(reset_n),
    .rng(rng)
  );

  control control0(
    .clk(clk_25MHz),
    .reset_n(reset_n),
    .rng(rng),
    .usr_btn(usr_btn),
    .usr_sw(usr_sw),
    .uart_rx(uart_rx),
    .uart_tx(uart_tx),
    .state(tetris_state),
    .score(tetris_score),
    .control(tetris_ctrl),
    .bar_mask(tetris_bar_mask),
    .start(start),
    .over(over),
    .count_down(count_down)
  );

  tetris tetris0(
    .clk(clk_25MHz),
    .reset_n(reset_n),
    .rng(rng),
    .x(tetris_x),
    .y(tetris_y),
    .ctrl(tetris_ctrl),
    .bar_mask(tetris_bar_mask),
    .state(tetris_state),
    .score(tetris_score),
    .kind(tetris_kind),
    .hold(tetris_hold),
    .next(tetris_next),
    .hold_locked(hold_locked),
    .pending_counter(pending_counter),
    .combo(combo),
    .t_spin(t_spin)
  );

  display display0(
    .clk(clk_25MHz),
    .reset_n(reset_n),
    .start(start),
    .over(over),
    .tetris_score(tetris_score),
    .kind(tetris_kind),
    .hold(tetris_hold),
    .next(tetris_next),
    .hold_locked(hold_locked),
    .count_down(count_down),
    .tetris_x(tetris_x),
    .tetris_y(tetris_y),
    .VGA_HSYNC(VGA_HSYNC),
    .VGA_VSYNC(VGA_VSYNC),
    .VGA_RED(VGA_RED),
    .VGA_GREEN(VGA_GREEN),
    .VGA_BLUE(VGA_BLUE)
  );

  assign usr_led = usr_btn ^ usr_sw;

  localparam row_init = "????????????????";

  reg [127:0] row_A = row_init;
  reg [127:0] row_B = row_init;

  LCD_module lcd0(
    .clk(clk_25MHz),
    .reset(~reset_n),
    .row_A(row_A),
    .row_B(row_B),
    .LCD_E(LCD_E),
    .LCD_RS(LCD_RS),
    .LCD_RW(LCD_RW),
    .LCD_D(LCD_D)
  );

  wire [7:0] ns = tetris_state;
  reg [7:0] nc = 0;
  always_ff @(posedge clk_25MHz)
      if (~reset_n)
          nc <= 0;
      else if (tetris_ctrl != NONE)
          nc <= tetris_ctrl;

  reg [7:0] i;
  always_ff @(posedge clk_25MHz) begin
    if (~reset_n)
      { row_A, row_B } <= { row_init, row_init };
    else begin
      `N2T(i, 2, ns, 0, row_A, 0)
      `N2T(i, 2, nc, 0, row_B, 0)
      `N2T(i, 4, tetris_score, 0, row_B, 8)
      `N2T(i, 2, {3'b000, pending_counter}, 0, row_A, 8)
      `N2T(i, 2, combo, 0, row_B, 14)
      `N2T(i, 1, {3'b000, t_spin}, 0, row_A, 14)
    end
  end

endmodule

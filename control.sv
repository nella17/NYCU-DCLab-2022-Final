`timescale 1ns / 1ps

module control import enum_type::*;
(
  input  clk,
  input  reset_n,
  input  [31:0] rng,
  input  [3:0] usr_btn,
  input  [3:0] usr_sw,
  input  uart_rx,
  output uart_tx,
  input  state_type state,
  output state_type control,
  output logic [9:0] bar_mask,
  output logic start,
  output logic over
);
  genvar gi;

  localparam QSIZE = 16;
  localparam SEC_TICK  = 50_000_000;
  localparam COUNT_SEC = 60;
  localparam DOWN_TICK = SEC_TICK;
  localparam BAR_TICK  = SEC_TICK * 5 * 4;

  // uart

  wire transmit, received;
  wire [7:0] rx_byte;
  wire [7:0] tx_byte;
  wire is_receiving, is_transmitting, recv_error;

  uart #(
    .CLOCK_DIVIDE(326)
  ) uart (
    .clk(clk),
    .rst(~reset_n),
    .rx(uart_rx),
    .tx(uart_tx),
    .transmit(transmit),
    .tx_byte(tx_byte),
    .received(received),
    .rx_byte(rx_byte),
    .is_receiving(is_receiving),
    .is_transmitting(is_transmitting),
    .recv_error(recv_error)
  );

  assign transmit = 0;
  assign tx_byte = 0;

  // btn

  wire [3:0] debounced_btn;

  generate
    for (gi = 0; gi <= 3; gi = gi + 1)
      debouncer debouncer_btn(
        .clk(clk),
        .in(usr_btn[gi]),
        .out(debounced_btn[gi])
      );
  endgenerate

  // sw

  reg  [3:0] prev_sw;
  always_ff @(posedge clk)
    prev_sw <= usr_sw;
  wire [3:0] press_sw = usr_sw ^ prev_sw;

  // control

  reg [$clog2(SEC_TICK)+2:0] sec_cnt = 0;
  reg [$clog2(COUNT_SEC)+2:0] count_down = COUNT_SEC;
  reg [$clog2(DOWN_TICK)+2:0] down_cnt = 0;
  reg [$clog2(BAR_TICK)+2:0] bar_cnt = 0;
  state_type next = NONE;

  always_ff @(posedge clk)
    if (~reset_n)
      start <= 0;
    else if (next == INIT)
      start <= ~over;
  assign over = start && (count_down == 0 && state == END);
  logic during = start && ~over;

  always_ff @(posedge clk)
    if (~reset_n || ~during)
      sec_cnt <= 0;
    else if (sec_cnt == SEC_TICK-1)
      sec_cnt <= 0;
    else
      sec_cnt <= sec_cnt + 1;

  always_ff @(posedge clk)
    if (~reset_n || ~start)
      count_down <= COUNT_SEC;
    else if (sec_cnt == SEC_TICK-1)
      count_down <= count_down - 1;

  always_ff @(posedge clk)
    if (~reset_n || ~during)
      down_cnt <= 0;
    else if (next == DOWN)
      if (down_cnt < DOWN_TICK)
        down_cnt <= 0;
      else
        down_cnt <= down_cnt - DOWN_TICK;
    else
      down_cnt <= down_cnt + 1;

  always_ff @(posedge clk)
    if (~reset_n || ~during)
      bar_cnt <= 0;
    else if (next == BAR)
      if (bar_cnt < BAR_TICK)
        bar_cnt <= 0;
      else
        bar_cnt <= bar_cnt - BAR_TICK;
    else
      bar_cnt <= bar_cnt + rng[20+:3];

  always_comb
    if (~during) begin
      if (received || |debounced_btn || |press_sw)
        next = INIT;
      else
        next = NONE;
    end else begin
      if (received)
        case (rx_byte)
          "A", "a":
            next = LEFT;
          "D", "d":
            next = RIGHT;
          "S", "s":
            next = DOWN;
          "W", "w", " ":
            next = DROP;
          "C", "c":
            next = HOLD;
          "X", "x":
            next = ROTATE;
          "Z", "z":
            next = ROTATE_REV;
          "B", "b":
            next = BAR;
          default:
            next = NONE;
        endcase
      else if (debounced_btn[0])
        next = RIGHT;
      else if (debounced_btn[1])
        next = DOWN;
      else if (debounced_btn[2])
        next = ROTATE;
      else if (debounced_btn[3])
        next = LEFT;
      else if (press_sw[0])
        next = DROP;
      else if (press_sw[1])
        next = HOLD;
      else if (press_sw[2])
        next = ROTATE_REV;
      else if (press_sw[3])
        next = BAR;
      else if (down_cnt >= DOWN_TICK)
        next = DOWN;
      else if (bar_cnt >= BAR_TICK)
        next = BAR;
      else
        next = NONE;
    end

  reg [$clog2(QSIZE):0] cnt = 0, i;
  state_type queue [0:QSIZE];

  assign control = queue[0];

  always_ff @(posedge clk) begin
    if (~reset_n) begin
      cnt <= 0;
      for (i = 0; i <= QSIZE; i++)
        queue[i] <= NONE;
    end else if (state == WAIT) begin
      cnt <= cnt == 0 ? 0 : cnt - (next == NONE);
      for (i = 0; i <= QSIZE; i++)
        queue[i] <= i == cnt ? next : i == QSIZE ? NONE : queue[i+1];
    end else begin
      cnt <= cnt + (next != NONE);
      queue[cnt] <= next;
    end
  end

  always_ff @(posedge clk)
    if (~reset_n)
      bar_mask <= 0;
    else
      bar_mask <= 1 << (rng[16+:4]);

endmodule

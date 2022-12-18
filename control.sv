`timescale 1ns / 1ps

module control import enum_type::*;
(
  input  clk,
  input  reset_n,
  input  [3:0] usr_btn,
  input  [3:0] usr_sw,
  input  uart_rx,
  output uart_tx,
  input  state_type state,
  output state_type control
);
  genvar gi;

  localparam QSIZE = 16;
  localparam DOWN_TICK = 50_000_000;

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

  reg  [3:0] prev_usr_sw;
  always_ff @(posedge clk)
    prev_usr_sw <= usr_sw;

  wire [3:0] debounced_sw;

  generate
    for (gi = 0; gi <= 3; gi = gi + 1)
      debouncer debouncer_sw(
        .clk(clk),
        .in(~prev_usr_sw[gi] & usr_sw[gi]),
        .out(debounced_sw[gi])
      );
  endgenerate

  // control

  reg [$clog2(DOWN_TICK)+2:0] down_cnt = 0;
  state_type next = NONE;

  always_ff @(posedge clk)
    if (~reset_n)
      down_cnt <= 0;
    else if (next == DOWN)
      if (down_cnt < DOWN_TICK)
        down_cnt <= 0;
      else
        down_cnt <= down_cnt - DOWN_TICK;
    else
      down_cnt <= down_cnt + 1;

  always_comb
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
        next = LEFT;
      else if (debounced_btn[3])
        next = HOLD;
      else if (debounced_sw[0])
        next = DROP;
      else if (debounced_sw[1])
        next = ROTATE;
      else if (debounced_sw[2])
        next = ROTATE_REV;
      else if (debounced_sw[3])
        next = BAR;
      else if (down_cnt >= DOWN_TICK)
        next = DOWN;
      else
        next = NONE;

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
        queue[i] <= i == cnt - 1 ? next : i == QSIZE ? NONE : queue[i+1];
    end else begin
      cnt <= cnt + (next != NONE);
      queue[cnt] <= next;
    end
  end

endmodule

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
  input  [4*4-1:0] score,
  input  score_inc,
  output state_type control,
  output logic [9:0] bar_mask,
  output logic start,
  output logic over,
  output logic [$clog2(COUNT_SEC)+2:0] count_down
);
  genvar gi;

  // uart

  wire transmit, received;
  wire [7:0] rx_byte;
  wire [7:0] tx_byte;
  wire is_receiving, is_transmitting, recv_error;

  uart #(
    .CLOCK_DIVIDE(163)
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

  logic [$clog2(SEC_TICK)+2:0] sec_cnt;
  logic [$clog2(MSEC_TICK)+2:0] msec_cnt;
  logic [$clog2(DOWN_TICK)+2:0] down_cnt, down_tick, down_cut;
  logic [$clog2(BAR_TICK)+2:0] bar_cnt;
  logic [$clog2(OVER_TICK)+2:0] over_cnt;
  state_type next = NONE;

  logic sec_clk = sec_cnt == SEC_TICK-1;
  logic msec_clk = msec_cnt == MSEC_TICK-1;

  always_ff @(posedge clk)
    if (~reset_n)
      start <= 0;
    else if (next == INIT || next == END)
      start <= ~over;
  assign over = start && (count_down == 0 || state == END);
  logic during = start && ~over;

  always_ff @(posedge clk)
    if (~reset_n || ~during)
      sec_cnt <= 0;
    else if (sec_clk)
      sec_cnt <= 0;
    else
      sec_cnt <= sec_cnt + 1;

  always_ff @(posedge clk)
    if (~reset_n || ~during)
      msec_cnt <= 0;
    else if (msec_clk)
      msec_cnt <= 0;
    else
      msec_cnt <= msec_cnt + 1;

  always_ff @(posedge clk)
    if (~reset_n || ~start)
      count_down <= COUNT_SEC;
    else
      count_down <= count_down - sec_clk+ score_inc;

  localparam SCORE_BIT = 4;

  logic [SCORE_BIT:0] score_pow;
  always_ff @(posedge clk)
    if (~reset_n || ~during)
        score_pow <= 1;
    else
        score_pow <= score_pow + ((score >> score_pow) & 1);

  always_ff @(posedge clk)
    if (~reset_n || ~during || score_inc)
      down_cut <= 1;
    else if (msec_clk)
      down_cut <= down_cut + (1 << score_pow);

  always_ff @(posedge clk)
    if (~reset_n || ~during)
      down_tick <= DOWN_TICK;
    else if (msec_clk && down_tick >= MSEC_TICK)
      down_tick <= down_tick - down_cut;

  always_ff @(posedge clk)
    if (~reset_n || ~during)
      down_cnt <= 0;
    else if (next == DOWN)
      if (down_cnt < down_tick)
        down_cnt <= 0;
      else
        down_cnt <= down_cnt - down_tick;
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

  always_ff @(posedge clk)
    if (~reset_n || ~over)
      over_cnt <= 0;
    else
      over_cnt <= over_cnt + (over_cnt != OVER_TICK);

  reg [7:0] p_rx_byte, pp_rx_byte;
  always_ff @(posedge clk)
    p_rx_byte  <= ~reset_n ? 0 : received ? rx_byte   : p_rx_byte;
  always_ff @(posedge clk)
    pp_rx_byte <= ~reset_n ? 0 : received ? p_rx_byte : pp_rx_byte;

  always_comb begin
    next = NONE;
    if (reset_n) begin
      if (~during) begin
        if (received || |debounced_btn || |press_sw)
          next = over ? END : INIT;
        if (over && over_cnt < OVER_TICK)
          next = NONE;
      end else begin
        if (down_cnt >= down_tick)
          next = DOWN;
        if (bar_cnt >= BAR_TICK)
          next = BAR;
        if (debounced_btn[0])
          next = RIGHT;
        if (debounced_btn[1])
          next = DOWN;
        if (debounced_btn[2])
          next = ROTATE;
        if (debounced_btn[3])
          next = LEFT;
        if (press_sw[0])
          next = DROP;
        if (press_sw[1])
          next = HOLD;
        if (press_sw[2])
          next = ROTATE_REV;
        if (press_sw[3])
          next = BAR;
        if (received) begin
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
          endcase
          if (pp_rx_byte == 8'h1B && p_rx_byte == 8'h5B)
            case (rx_byte)
              8'h41:
                next = ROTATE;
              8'h42:
                next = DOWN;
              8'h43:
                next = RIGHT;
              8'h44:
                next = LEFT;
            endcase
        end
      end
    end
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
      if (cnt == 0) begin
        queue[0] <= next;
      end else begin
        cnt <= cnt - (next == NONE);
        for (i = 0; i <= QSIZE; i++)
          queue[i] <= i == cnt ? next : i == QSIZE ? NONE : queue[i+1];
      end
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

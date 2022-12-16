`timescale 1ns / 1ps

typedef enum {
  NOEVENT = 0,
  LEFT, RIGHT, DOWN, DROP,
  HOLD, ROTATE, ROTATE_REV, BAR
} control_type;

module control(
  input  clk,
  input  reset_n,
  input  [3:0] usr_btn,
  input  uart_rx,
  output uart_tx,
  input  ready,
  output control_type control
);

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
    genvar gi;
    for (gi = 0; gi <= 3; gi = gi + 1)
      debouncer debouncer_i(
        .clk(clk),
        .btn(usr_btn[gi]),
        .debounced_btn(debounced_btn[gi])
      ); 
  endgenerate

  // control
  localparam SIZE = 10;
  reg [$clog2(SIZE):0] cnt, i;
  control_type queue [0:SIZE];

  assign control = queue[0];

  always_ff @(posedge clk) begin
    if (~reset_n) begin
      cnt <= 0;
      for (i = 0; i <= SIZE; i++)
        queue[i] <= NOEVENT;
    end else if (ready) begin
      cnt <= cnt == 0 ? 0 : cnt - 1;
      for (i = 0; i <= SIZE; i++)
        queue[i] <= i == SIZE ? NOEVENT : queue[i+1];
    end else begin
      if (received) begin
        case (rx_byte)
          "A", "a": begin
            cnt <= cnt + 1; queue[cnt] <= LEFT;
          end
          "D", "d": begin
            cnt <= cnt + 1; queue[cnt] <= RIGHT;
          end
          "W", "w": begin
            cnt <= cnt + 1; queue[cnt] <= DOWN;
          end
          "S", "s": begin
            cnt <= cnt + 1; queue[cnt] <= DROP;
          end
          "C", "c": begin
            cnt <= cnt + 1; queue[cnt] <= HOLD;
          end
          "X", "x": begin
            cnt <= cnt + 1; queue[cnt] <= ROTATE;
          end
          "Z", "z": begin
            cnt <= cnt + 1; queue[cnt] <= ROTATE_REV;
          end
        endcase
      end if (debounced_btn[0]) begin
        cnt <= cnt + 1; queue[cnt] <= RIGHT;
      end if (debounced_btn[1]) begin
        cnt <= cnt + 1; queue[cnt] <= HOLD;
      end if (debounced_btn[2]) begin
        cnt <= cnt + 1; queue[cnt] <= ROTATE;
      end if (debounced_btn[3]) begin
        cnt <= cnt + 1; queue[cnt] <= LEFT;
      end
    end
  end

endmodule

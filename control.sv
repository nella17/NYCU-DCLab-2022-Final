`timescale 1ns / 1ps
`include "control.svh"

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
    genvar i;
    for (genvar i = 0; i <= 3; i = i + 1)
      debouncer debouncer_i(
        .clk(clk),
        .btn(usr_btn[i]),
        .debounced_btn(debounced_btn[i])
      ); 
  endgenerate

  // control
  localparam SIZE = 10;
  reg [$clog2(SIZE):0] cnt;
  control_type [0:SIZE] queue;

  assign control = queue[0];

  always_ff @(posedge clk) begin
    if (~reset_n) begin
      cnt <= 0;
      queue <= 0;
    end else if (ready) begin
      cnt <= cnt == 0 ? 0 : cnt - 1;
      queue <= { queue[1:SIZE], NONE };
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

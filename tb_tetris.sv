`timescale 1ns / 1ps

module tb_tetris;

  reg clk;
  reg reset_n;
  reg [3:0] x;
  reg [4:0] y;
  reg [2:0] ctrl;
  wire [4*4-1:0] score;
  wire [2:0] kind;
  wire [2:0] hold;
  wire [2:0] next [0:3];
  wire ready;
  
  tetris tetris_0(
    .clk(clk),
    .reset_n(reset_n),
    .x(x),
    .y(y),
    .ctrl(ctrl),
    .score(score),
    .kind(kind),
    .hold(hold),
    .next(next),
    .ready(ready)
  );
  
  always begin
    clk = 1'b1;
    #1 clk = 1'b0;
    #1;
  end
   
  initial begin
    ctrl <= 0;
    reset_n <= 0;
    #2.1 reset_n <= 1;
  end
  
  // remember to change always_ff to always_comb in tetris.sv
  always @(negedge clk) begin
    $display("==========");
    for (y = 0; y < 20; y = y + 1) begin
      for (x = 0; x < 10; x = x + 1) begin
        #0.001; 
        $write("%d", kind);
      end
      $display;
    end
  end
  
endmodule

`timescale 1ns / 1ps

module tb_tetris;

  reg [3:0] x;
  reg [4:0] y;
  reg [2:0] ctrl;
  reg clk;
  reg reset_n;
  wire [4*4-1:0] score;
  wire [2:0] type;
  wire [2:0] hold;
  wire [2:0] next_0;
  wire [2:0] next_1;
  wire [2:0] next_2;
  wire [2:0] next_3;
  
  tetris tetris_0(
    .x(x),
    .y(y),
    .ctrl(ctrl),
    .clk(clk),
    .reset_n(reset_n),
    .score(score),
    .type(type),
    .hold(hold),
    .next_0(next_0),
    .next_1(next_1),
    .next_2(next_2),
    .next_3(next_3)
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
  
  always @(negedge clk) begin
    $display("==========");
    for (y = 0; y < 20; y = y + 1) begin
      for (x = 0; x < 10; x = x + 1) begin
        #0.001; 
        $write("%d", type);
      end
      $display;
    end
  end
  
endmodule

`timescale 1ns / 1ps

module prng (
  input clk,
  input reset_n,
  output [31:0] rng
);
  parameter SEED = 32'hFACEB00C;
  reg [31:0] seed = SEED;
  always_ff @(posedge clk)
    if (~reset_n)
      seed <= SEED;
    else
      seed <= seed + 1;
  wire [31:0] a = seed * 15485863;
  assign rng = a * a * a;
endmodule

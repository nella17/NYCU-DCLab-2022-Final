`timescale 1ns / 1ps
`define ROL32(x, c) (((x) << (c)) | ((x) >> (32 - (c))))

module prng (
  input clk,
  input reset_n,
  output logic [31:0] rng
);
  parameter bit [31:0] SEED [0:1] = { 32'hFACEB00C, 32'hDEADBEEF };
  logic [31:0] s [0:1];
  logic [31:0] xs = s[0] ^ s[1];
  always_ff @(posedge clk)
    if (~reset_n) begin
      s[0] <= SEED[0];
      s[1] <= SEED[1];
    end else begin
      s[0] <= `ROL32(xs, 19);
      s[1] <= `ROL32(s[0], 12) ^ xs ^ (xs << 8);
    end
  always_ff @(posedge clk)
    rng <= ~reset_n ? 0 : s[0] + s[1];
endmodule

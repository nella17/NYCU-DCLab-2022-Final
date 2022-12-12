`timescale 1ns / 1ps

module final_project(
  input  clk,
  input  reset_n,
  input  [3:0] usr_btn,
  output [3:0] usr_led,
  
  // VGA specific I/O ports
  output VGA_HSYNC,
  output VGA_VSYNC,
  output reg [3:0] VGA_RED,
  output reg [3:0] VGA_GREEN,
  output reg [3:0] VGA_BLUE,

  input  uart_rx,
  output uart_tx
);

wire [3:0] debounced_btn;

// General VGA control signals
wire vga_clk;         // 50MHz clock for VGA control
wire visible;         // when visible is 0, the VGA controller is sending
                      // synchronization signals to the display device.
wire p_tick;          // when p_tick is 1, we must update the RGB value
                      // based for the new coordinate (pixel_x, pixel_y)
wire [9:0] pixel_x;   // x coordinate of the next pixel (between 0 ~ 639) 
wire [9:0] pixel_y;   // y coordinate of the next pixel (between 0 ~ 479)

wire [2:0] kind;
wire [3:0] tetris_x;
wire [4:0] tetris_y;
wire [1:0] ctrl;
wire inside_tetris;

generate 
   genvar i;
   for (i = 0; i <= 3; i = i + 1) begin
        debouncer (
            .clk(clk),
            .btn(usr_btn[i]),
            .debounced_btn(debounced_btn[i])
        ); 
   end
endgenerate

clk_divider#(2) clk_divider0(
  .clk(clk),
  .reset(~reset_n),
  .clk_out(vga_clk)
);

vga_sync vs0(
  .clk(vga_clk), .reset(~reset_n), .oHS(VGA_HSYNC), .oVS(VGA_VSYNC),
  .visible(visible), .p_tick(p_tick),
  .pixel_x(pixel_x), .pixel_y(pixel_y)
);

tetris tetris0(
  .x(tetris_x), .y(tetris_y), .ctrl_valid(|debounced_btn), .ctrl(ctrl),
  .clk(clk), .reset_n(reset_n), .kind(kind)
);

assign usr_led = usr_btn;

always @(*) begin
  if (visible & inside_tetris) begin
    case (kind)
      3'b000: {VGA_RED, VGA_GREEN, VGA_BLUE} = 12'h000;
      3'b001: {VGA_RED, VGA_GREEN, VGA_BLUE} = 12'h09D;
      3'b010: {VGA_RED, VGA_GREEN, VGA_BLUE} = 12'h04F;
      3'b011: {VGA_RED, VGA_GREEN, VGA_BLUE} = 12'hD90;
      3'b100: {VGA_RED, VGA_GREEN, VGA_BLUE} = 12'hFF0;
      3'b101: {VGA_RED, VGA_GREEN, VGA_BLUE} = 12'h0F3;
      3'b110: {VGA_RED, VGA_GREEN, VGA_BLUE} = 12'h80C;
      3'b111: {VGA_RED, VGA_GREEN, VGA_BLUE} = 12'hF00;
    endcase
  end
  else {VGA_RED, VGA_GREEN, VGA_BLUE} = 12'h000;
end

assign tetris_x = (pixel_x - 220) / 20;
assign tetris_y = (pixel_y - 40) / 20;
assign ctrl = debounced_btn[0] ? 2'b00 : debounced_btn[1] ? 2'b01 : debounced_btn[2] ? 2'b10 : 2'b11;
assign inside_tetris = (220 <= pixel_x) & (pixel_x < 420) & (40 <= pixel_y) & (pixel_y < 440);

endmodule

`timescale 1ns / 1ps

module lab10(
  input  clk,
  input  reset_n,
  input  [3:0] usr_btn,
  output [3:0] usr_led,
  
  // VGA specific I/O ports
  output VGA_HSYNC,
  output VGA_VSYNC,
  output  [3:0] VGA_RED,
  output  [3:0] VGA_GREEN,
  output  [3:0] VGA_BLUE

  //,input  uart_rx,
  //output uart_tx
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
wire [4:0] block_x;
wire [4:0] block_y;
reg  [15:0] tetris_score = 888;
wire  [3:0] score_dec [0:3];
reg  [0:20*10*3-1] tetris_board = {3'b000, 3'b000, 3'b001, 3'b010, 3'b011, 3'b100, 3'b101, 3'b110, 3'b111, 3'b001, 
                                3'b000, 3'b000, 3'b001, 3'b010, 3'b011, 3'b100, 3'b101, 3'b110, 3'b111, 3'b001, 
                                3'b001, 3'b001, 3'b001, 3'b010, 3'b011, 3'b100, 3'b101, 3'b110, 3'b111, 3'b001, 
                                3'b001, 3'b001, 3'b001, 3'b010, 3'b011, 3'b100, 3'b101, 3'b110, 3'b111, 3'b001, 
                                3'b001, 3'b001, 3'b001, 3'b010, 3'b011, 3'b100, 3'b101, 3'b110, 3'b111, 3'b001, 
                                3'b001, 3'b001, 3'b001, 3'b010, 3'b011, 3'b100, 3'b101, 3'b110, 3'b111, 3'b001, 
                                3'b001, 3'b001, 3'b001, 3'b010, 3'b011, 3'b100, 3'b101, 3'b110, 3'b111, 3'b001, 
                                3'b001, 3'b001, 3'b001, 3'b010, 3'b011, 3'b100, 3'b101, 3'b110, 3'b111, 3'b001, 
                                3'b001, 3'b001, 3'b001, 3'b010, 3'b011, 3'b100, 3'b101, 3'b110, 3'b111, 3'b001, 
                                3'b001, 3'b001, 3'b001, 3'b010, 3'b011, 3'b100, 3'b101, 3'b110, 3'b111, 3'b001, 
                                3'b001, 3'b001, 3'b001, 3'b010, 3'b011, 3'b100, 3'b101, 3'b110, 3'b111, 3'b001, 
                                3'b001, 3'b001, 3'b001, 3'b010, 3'b011, 3'b100, 3'b101, 3'b110, 3'b111, 3'b001, 
                                3'b001, 3'b001, 3'b001, 3'b010, 3'b011, 3'b100, 3'b101, 3'b110, 3'b111, 3'b001, 
                                3'b001, 3'b001, 3'b001, 3'b010, 3'b011, 3'b100, 3'b101, 3'b110, 3'b111, 3'b001, 
                                3'b001, 3'b001, 3'b001, 3'b010, 3'b011, 3'b100, 3'b101, 3'b110, 3'b111, 3'b001, 
                                3'b001, 3'b001, 3'b001, 3'b010, 3'b011, 3'b100, 3'b101, 3'b110, 3'b111, 3'b001, 
                                3'b001, 3'b001, 3'b001, 3'b010, 3'b011, 3'b100, 3'b101, 3'b110, 3'b111, 3'b001, 
                                3'b001, 3'b001, 3'b001, 3'b010, 3'b011, 3'b100, 3'b101, 3'b110, 3'b111, 3'b001, 
                                3'b001, 3'b001, 3'b001, 3'b010, 3'b011, 3'b100, 3'b101, 3'b110, 3'b111, 3'b001, 
                                3'b001, 3'b001, 3'b001, 3'b010, 3'b011, 3'b100, 3'b101, 3'b110, 3'b111, 3'b001};
wire [1:0] ctrl;
wire inside_tetris;
wire inside_scoreboard[0:3];

//NEW ADD VARIABLEs
// declare SRAM control signals
wire [16:0] sram_addr;
wire [11:0] data_in;
wire [11:0] data_out;
wire        sram_we, sram_en;
wire [16:0] bg_addr;
wire [11:0] bg_in;
wire [11:0] bg_out;
assign data_in = 12'h000;
assign sram_we = usr_btn[3];         // MAY HAVE TROUBLE !!!!!!!
assign sram_en = 1;          // Here, we always enable the SRAM block.

reg  [11:0] rgb_reg;  // RGB value for the current pixel
reg  [11:0] rgb_next; // RGB value for the next pixel
reg  [11:0] rgb_temp;

reg  [17:0] bg_addr_reg;
reg  [17:0] pixel_addr;
assign bg_addr = bg_addr_reg;
assign sram_addr = pixel_addr;

// Declare the video buffer size
localparam BG_W = 320; // video buffer width (background weight)
localparam BG_H = 240; // video buffer height (background height)

// Set parameters for the block
localparam BLOCK_W = 10; // Width of the block.
localparam BLOCK_H = 10; // Height of the block.
reg [17:0]  block_addr[0:7];   // Address array for up to 7 block images. 
localparam NUM_W = 5;
localparam NUM_H = 9;
reg [17:0]  num_addr[0:9];  // Address array for up to 10 number images. 0 ~ 9
localparam GREEN = 1;

initial begin
      block_addr[0] = 18'd0;         /* Addr for block image #1 */
      block_addr[1] = BLOCK_W*BLOCK_H * 1;
      block_addr[2] = BLOCK_W*BLOCK_H * 2;
      block_addr[3] = BLOCK_W*BLOCK_H * 3;
      block_addr[4] = BLOCK_W*BLOCK_H * 4;
      block_addr[5] = BLOCK_W*BLOCK_H * 5;
      block_addr[6] = BLOCK_W*BLOCK_H * 6;
      block_addr[7] = BLOCK_W*BLOCK_H * 7 + NUM_W*NUM_H*10;
      
      num_addr[0] = BLOCK_W*BLOCK_H * 7 + 18'd0;         /* Addr for num image #1 */
      num_addr[1] = BLOCK_W*BLOCK_H * 7 + NUM_W*NUM_H*1;
      num_addr[2] = BLOCK_W*BLOCK_H * 7 + NUM_W*NUM_H*2;
      num_addr[3] = BLOCK_W*BLOCK_H * 7 + NUM_W*NUM_H*3;
      num_addr[4] = BLOCK_W*BLOCK_H * 7 + NUM_W*NUM_H*4;
      num_addr[5] = BLOCK_W*BLOCK_H * 7 + NUM_W*NUM_H*5;
      num_addr[6] = BLOCK_W*BLOCK_H * 7 + NUM_W*NUM_H*6;
      num_addr[7] = BLOCK_W*BLOCK_H * 7 + NUM_W*NUM_H*7;
      num_addr[8] = BLOCK_W*BLOCK_H * 7 + NUM_W*NUM_H*8;
      num_addr[9] = BLOCK_W*BLOCK_H * 7 + NUM_W*NUM_H*9;
end
/*
generate 
   genvar i;
   for (i = 0; i <= 3; i = i + 1) begin
        debouncer (
            .clk(clk),
            .btn(usr_btn[i]),
            .debounced_btn(debounced_btn[i])
        ); 
   end
endgenerate*/

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

sram #(.DATA_WIDTH(12), .ADDR_WIDTH(18), .RAM_SIZE(BG_W*BG_H), .FILE("images.mem"))
  ram0 (.clk(clk), .we(sram_we), .en(sram_en),
          .addr(bg_addr), .data_i(bg_in), .data_o(bg_out));
sram #(.DATA_WIDTH(12), .ADDR_WIDTH(18), .RAM_SIZE(BLOCK_W*BLOCK_H * 7 + NUM_W*NUM_H*10 + GREEN), .FILE("block_num.mem"))
  ram1 (.clk(clk), .we(sram_we), .en(sram_en),
          .addr(sram_addr), .data_i(data_in), .data_o(data_out));
/*
tetris tetris0(
  .x(tetris_x), .y(tetris_y), .ctrl_valid(|debounced_btn), .ctrl(ctrl),
  .clk(clk), .reset_n(reset_n), .kind(kind)
);*/

assign usr_led = usr_btn;
assign {VGA_RED, VGA_GREEN, VGA_BLUE} = rgb_reg;


always @(posedge clk) begin
  if (inside_tetris) begin
    case (kind)
      3'b000: pixel_addr <= block_addr[7];
      3'b001: pixel_addr <= block_addr[0] + (block_y >> 1)*BLOCK_W + (block_x >> 1);
      3'b010: pixel_addr <= block_addr[1] + (block_y >> 1)*BLOCK_W + (block_x >> 1);
      3'b011: pixel_addr <= block_addr[2] + (block_y >> 1)*BLOCK_W + (block_x >> 1);
      3'b100: pixel_addr <= block_addr[3] + (block_y >> 1)*BLOCK_W + (block_x >> 1);
      3'b101: pixel_addr <= block_addr[4] + (block_y >> 1)*BLOCK_W + (block_x >> 1);
      3'b110: pixel_addr <= block_addr[5] + (block_y >> 1)*BLOCK_W + (block_x >> 1);
      3'b111: pixel_addr <= block_addr[6] + (block_y >> 1)*BLOCK_W + (block_x >> 1);
    endcase
  end
  else if (inside_scoreboard[0]) begin
    pixel_addr <= num_addr[score_dec[0]] + ((pixel_x - 64*2)>>1) + ((pixel_y - 225*2)>>1) * NUM_W;
  end
  else if (inside_scoreboard[1]) begin
    pixel_addr <= num_addr[score_dec[1]] + ((pixel_x - 71*2)>>1) + ((pixel_y - 225*2)>>1) * NUM_W;
  end
  else if (inside_scoreboard[2]) begin
    pixel_addr <= num_addr[score_dec[2]] + ((pixel_x - 78*2)>>1) + ((pixel_y - 225*2)>>1) * NUM_W;
  end
  else if (inside_scoreboard[3]) begin
    pixel_addr <= num_addr[score_dec[3]] + ((pixel_x - 85*2)>>1) + ((pixel_y - 225*2)>>1) * NUM_W;
  end
  else pixel_addr <= block_addr[7];
end

assign kind = tetris_board[(tetris_y*10+tetris_x)*3 +: 3];
assign tetris_x = (pixel_x - 220) / 20;
assign tetris_y = (pixel_y - 40) / 20;
assign block_x = (pixel_x - 220) % 20;
assign block_y = (pixel_y - 40) % 20;
//assign ctrl = debounced_btn[0] ? 2'b00 : debounced_btn[1] ? 2'b01 : debounced_btn[2] ? 2'b10 : 2'b11;
assign inside_tetris = (220 <= pixel_x) & (pixel_x < 420) & (40 <= pixel_y) & (pixel_y < 440);
assign inside_scoreboard[0] = (64*2 <= pixel_x) & (pixel_x < 69*2) & (225*2 <= pixel_y) & (pixel_y < 234*2);
assign inside_scoreboard[1] = (71*2 <= pixel_x) & (pixel_x < 76*2) & (225*2 <= pixel_y) & (pixel_y < 234*2);
assign inside_scoreboard[2] = (78*2 <= pixel_x) & (pixel_x < 83*2) & (225*2 <= pixel_y) & (pixel_y < 234*2);
assign inside_scoreboard[3] = (85*2 <= pixel_x) & (pixel_x < 90*2) & (225*2 <= pixel_y) & (pixel_y < 234*2);
assign score_dec[3] = tetris_score % 10;
assign score_dec[2] = (tetris_score / 10) % 10;
assign score_dec[1] = (tetris_score / 100) % 10;
assign score_dec[0] = (tetris_score / 1000) % 10;

// ------------------------------------------------------------------------
// Send the video data in the sram to the VGA controller
always @(posedge clk) begin
  if (p_tick) rgb_reg <= rgb_next;
end

always @(*) begin
  if (~visible)
    rgb_next = 12'h000; // Synchronization period, must set RGB values to zero.
  else if (data_out != 12'hfff)
    rgb_next = data_out;
  else
    rgb_next = bg_out;
end

// ------------------------------------------------------------------------
// Video frame buffer address generation unit (AGU) with scaling control
// Note that the width x height of the fish image is 64x32, when scaled-up
// on the screen, it becomes 128x64. 'pos' specifies the right edge of the
// fish image.
always @ (posedge clk) begin
  if (~reset_n)
    bg_addr_reg <= 0;
  else 
    bg_addr_reg <= (pixel_y >> 1) * BG_W + (pixel_x >> 1);
end

endmodule
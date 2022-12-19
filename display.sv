`timescale 1ns / 1ps

module display(
  input  clk,
  input  reset_n,

  input  start,
  input  over,
  input  [3:0] kind,
  input  [3:0] hold,
  input  [3:0] next [0:3],
  input  hold_locked,
  input  [4*4-1:0] tetris_score,
  output reg [4:0] tetris_x, tetris_y,

  // VGA specific I/O ports
  output VGA_HSYNC,
  output VGA_VSYNC,
  output [3:0] VGA_RED,
  output [3:0] VGA_GREEN,
  output [3:0] VGA_BLUE
);

  wire visible;         // when visible is 0, the VGA controller is sending
                        // synchronization signals to the display device.
  wire p_tick;          // when p_tick is 1, we must update the RGB value
                        // based for the new coordinate (pixel_x, pixel_y)
  wire [9:0] pixel_x2, pixel_y2; // [0,640), [0,480)
  wire [8:0] pixel_x, pixel_y; // [0,320), [0,240)

  reg [4:0] block_x, block_y;

  //NEW ADD VARIABLEs
  // declare SRAM control signals
  wire [16:0] sram_addr;
  wire [11:0] data_in;
  wire [11:0] data_out;
  wire        sram_we, sram_en;
  wire [16:0] bg_addr;
  wire [11:0] bg_out;
  assign data_in = 12'h000;
  assign sram_we = 0;         // MAY HAVE TROUBLE !!!!!!!
  assign sram_en = 1;          // Here, we always enable the SRAM block.

  wire inside_scoreboard[0:3];
  wire  [3:0] score_dec [0:3];

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

  vga_sync_reg vs0(
    .clk(clk), .reset(~reset_n), .oHS(VGA_HSYNC), .oVS(VGA_VSYNC),
    .visible(visible), .p_tick(p_tick),
    .pixel_x(pixel_x2), .pixel_y(pixel_y2)
  );
  assign pixel_x = pixel_x2 >> 1;
  assign pixel_y = pixel_y2 >> 1;

  sram #(.DATA_WIDTH(12), .ADDR_WIDTH(17), .RAM_SIZE(BG_W*BG_H), .FILE("images.mem"))
    ram0 (.clk(clk), .we(sram_we), .en(sram_en),
            .addr(bg_addr), .data_i(data_in), .data_o(bg_out));
  sram #(.DATA_WIDTH(12), .ADDR_WIDTH(17), .RAM_SIZE(BLOCK_W*BLOCK_H * 7 + NUM_W*NUM_H*10 + GREEN), .FILE("block_num.mem"))
    ram1 (.clk(clk), .we(sram_we), .en(sram_en),
            .addr(sram_addr), .data_i(data_in), .data_o(data_out));

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
      pixel_addr <= num_addr[score_dec[0]] + (pixel_x - 64) + (pixel_y - 225) * NUM_W;
    end
    else if (inside_scoreboard[1]) begin
      pixel_addr <= num_addr[score_dec[1]] + (pixel_x - 71) + (pixel_y - 225) * NUM_W;
    end
    else if (inside_scoreboard[2]) begin
      pixel_addr <= num_addr[score_dec[2]] + (pixel_x - 78) + (pixel_y - 225) * NUM_W;
    end
    else if (inside_scoreboard[3]) begin
      pixel_addr <= num_addr[score_dec[3]] + (pixel_x - 85) + (pixel_y - 225) * NUM_W;
    end
    else pixel_addr <= block_addr[7];
  end

  always @(posedge clk) begin
    tetris_x <= ~inside_tetris ? 0 : (pixel_x2 - 220) / 20;
    tetris_y <= ~inside_tetris ? 0 : (pixel_y2 -  40) / 20;
    block_x  <= ~inside_tetris ? 0 : (pixel_x2 - 220) % 20;
    block_y  <= ~inside_tetris ? 0 : (pixel_y2 -  40) % 20;
  end

  assign inside_tetris = (220 <= pixel_x2) & (pixel_x2 < 420) & (40 <= pixel_y2) & (pixel_y2 < 440);
  assign inside_scoreboard[0] = (64 <= pixel_x) & (pixel_x < 69) & (225 <= pixel_y) & (pixel_y < 234);
  assign inside_scoreboard[1] = (71 <= pixel_x) & (pixel_x < 76) & (225 <= pixel_y) & (pixel_y < 234);
  assign inside_scoreboard[2] = (78 <= pixel_x) & (pixel_x < 83) & (225 <= pixel_y) & (pixel_y < 234);
  assign inside_scoreboard[3] = (85 <= pixel_x) & (pixel_x < 90) & (225 <= pixel_y) & (pixel_y < 234);
  assign score_dec[3] = tetris_score[ 0+:4];
  assign score_dec[2] = tetris_score[ 4+:4];
  assign score_dec[1] = tetris_score[ 8+:4];
  assign score_dec[0] = tetris_score[12+:4];

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
      bg_addr_reg <= pixel_y * BG_W + pixel_x;
  end

endmodule

`timescale 1ns / 1ps

module tetris(
  input [3:0] x,  // [0, 10)
  input [4:0] y,  // [0, 20)
  input [2:0] ctrl,
  
  input clk,
  input reset_n,
  
  output [4*4-1:0] score,  // 0xABCD BCD
  output reg [2:0] type,
  output reg [2:0] hold,
  output [2:0] next_0,
  output [2:0] next_1,
  output [2:0] next_2,
  output [2:0] next_3
);

  // parameters --------------------------------------------------
  
  reg [3:0] mask[1:7][0:3][0:3];  // [type][rotate_idx][row]
  initial begin
    // 1: ==================
    mask[1][0][0] = 4'b0000;
    mask[1][0][1] = 4'b1111;
    mask[1][0][2] = 4'b0000;
    mask[1][0][3] = 4'b0000;
    // ---------------------
    mask[1][1][0] = 4'b0010;
    mask[1][1][1] = 4'b0010;
    mask[1][1][2] = 4'b0010;
    mask[1][1][3] = 4'b0010;
    // ---------------------
    mask[1][2][0] = 4'b0000;
    mask[1][2][1] = 4'b0000;
    mask[1][2][2] = 4'b1111;
    mask[1][2][3] = 4'b0000;
    // ---------------------
    mask[1][3][0] = 4'b0100;
    mask[1][3][1] = 4'b0100;
    mask[1][3][2] = 4'b0100;
    mask[1][3][3] = 4'b0100;
    // 2: ==================
    mask[2][0][0] = 4'b1000;
    mask[2][0][1] = 4'b1110;
    mask[2][0][2] = 4'b0000;
    mask[2][0][3] = 4'b0000;
    // ---------------------
    mask[2][1][0] = 4'b0110;
    mask[2][1][1] = 4'b0100;
    mask[2][1][2] = 4'b0100;
    mask[2][1][3] = 4'b0000;
    // ---------------------
    mask[2][2][0] = 4'b0000;
    mask[2][2][1] = 4'b1110;
    mask[2][2][2] = 4'b0010;
    mask[2][2][3] = 4'b0000;
    // ---------------------
    mask[2][3][0] = 4'b0100;
    mask[2][3][1] = 4'b0100;
    mask[2][3][2] = 4'b1100;
    mask[2][3][3] = 4'b0000;
    // 3: ==================
    mask[3][0][0] = 4'b0010;
    mask[3][0][1] = 4'b1110;
    mask[3][0][2] = 4'b0000;
    mask[3][0][3] = 4'b0000;
    // ---------------------
    mask[3][1][0] = 4'b0100;
    mask[3][1][1] = 4'b0100;
    mask[3][1][2] = 4'b0110;
    mask[3][1][3] = 4'b0000;
    // ---------------------
    mask[3][2][0] = 4'b0000;
    mask[3][2][1] = 4'b1110;
    mask[3][2][2] = 4'b1000;
    mask[3][2][3] = 4'b0000;
    // ---------------------
    mask[3][3][0] = 4'b1100;
    mask[3][3][1] = 4'b0100;
    mask[3][3][2] = 4'b0100;
    mask[3][3][3] = 4'b0000;
    // 4: ==================
    mask[4][0][0] = 4'b0110;
    mask[4][0][1] = 4'b0110;
    mask[4][0][2] = 4'b0000;
    mask[4][0][3] = 4'b0000;
    // ---------------------
    mask[4][1][0] = 4'b0110;
    mask[4][1][1] = 4'b0110;
    mask[4][1][2] = 4'b0000;
    mask[4][1][3] = 4'b0000;
    // ---------------------
    mask[4][2][0] = 4'b0110;
    mask[4][2][1] = 4'b0110;
    mask[4][2][2] = 4'b0000;
    mask[4][2][3] = 4'b0000;
    // ---------------------
    mask[4][3][0] = 4'b0110;
    mask[4][3][1] = 4'b0110;
    mask[4][3][2] = 4'b0000;
    mask[4][3][3] = 4'b0000;
    // 5: ==================
    mask[5][0][0] = 4'b0110;
    mask[5][0][1] = 4'b1100;
    mask[5][0][2] = 4'b0000;
    mask[5][0][3] = 4'b0000;
    // ---------------------
    mask[5][1][0] = 4'b0100;
    mask[5][1][1] = 4'b0110;
    mask[5][1][2] = 4'b0010;
    mask[5][1][3] = 4'b0000;
    // ---------------------
    mask[5][2][0] = 4'b0000;
    mask[5][2][1] = 4'b0110;
    mask[5][2][2] = 4'b1100;
    mask[5][2][3] = 4'b0000;
    // ---------------------
    mask[5][3][0] = 4'b1000;
    mask[5][3][1] = 4'b1100;
    mask[5][3][2] = 4'b0100;
    mask[5][3][3] = 4'b0000;
    // 6: ==================
    mask[6][0][0] = 4'b0100;
    mask[6][0][1] = 4'b1110;
    mask[6][0][2] = 4'b0000;
    mask[6][0][3] = 4'b0000;
    // ---------------------
    mask[6][1][0] = 4'b0100;
    mask[6][1][1] = 4'b0110;
    mask[6][1][2] = 4'b0100;
    mask[6][1][3] = 4'b0000;
    // ---------------------
    mask[6][2][0] = 4'b0000;
    mask[6][2][1] = 4'b1110;
    mask[6][2][2] = 4'b0100;
    mask[6][2][3] = 4'b0000;
    // ---------------------
    mask[6][3][0] = 4'b0100;
    mask[6][3][1] = 4'b1100;
    mask[6][3][2] = 4'b0100;
    mask[6][3][3] = 4'b0000;
    // 7: ==================
    mask[7][0][0] = 4'b1100;
    mask[7][0][1] = 4'b0110;
    mask[7][0][2] = 4'b0000;
    mask[7][0][3] = 4'b0000;
    // ---------------------
    mask[7][1][0] = 4'b0010;
    mask[7][1][1] = 4'b0110;
    mask[7][1][2] = 4'b0100;
    mask[7][1][3] = 4'b0000;
    // ---------------------
    mask[7][2][0] = 4'b0000;
    mask[7][2][1] = 4'b1100;
    mask[7][2][2] = 4'b0110;
    mask[7][2][3] = 4'b0000;
    // ---------------------
    mask[7][3][0] = 4'b0100;
    mask[7][3][1] = 4'b1100;
    mask[7][3][2] = 4'b1000;
    mask[7][3][3] = 4'b0000;
  end
  
  reg [1:0] min_x_offset [1:7][0:3];  // [type][rotate_idx]
  initial begin
    // --------------------
    min_x_offset[1][0] = 2;
    min_x_offset[1][1] = 0;
    min_x_offset[1][2] = 2;
    min_x_offset[1][3] = 1;
    // --------------------
    min_x_offset[2][0] = 2;
    min_x_offset[2][1] = 1;
    min_x_offset[2][2] = 2;
    min_x_offset[2][3] = 2;
    // --------------------
    min_x_offset[3][0] = 2;
    min_x_offset[3][1] = 1;
    min_x_offset[3][2] = 2;
    min_x_offset[3][3] = 2;
    // --------------------
    min_x_offset[4][0] = 1;
    min_x_offset[4][1] = 1;
    min_x_offset[4][2] = 1;
    min_x_offset[4][3] = 1;
    // --------------------
    min_x_offset[5][0] = 2;
    min_x_offset[5][1] = 1;
    min_x_offset[5][2] = 2;
    min_x_offset[5][3] = 2;
    // --------------------
    min_x_offset[6][0] = 2;
    min_x_offset[6][1] = 1;
    min_x_offset[6][2] = 2;
    min_x_offset[6][3] = 2;
    // --------------------
    min_x_offset[7][0] = 2;
    min_x_offset[7][1] = 1;
    min_x_offset[7][2] = 2;
    min_x_offset[7][3] = 2;
  end
  
  reg [3:0] max_x_offset [1:7][0:3];  // [type][rotate_idx]
  initial begin
    // ---------------------
    max_x_offset[1][0] =  8;
    max_x_offset[1][1] =  9;
    max_x_offset[1][2] =  8;
    max_x_offset[1][3] = 10;
    // ---------------------
    max_x_offset[2][0] =  9;
    max_x_offset[2][1] =  9;
    max_x_offset[2][2] =  9;
    max_x_offset[2][3] = 10;
    // ---------------------
    max_x_offset[3][0] =  9;
    max_x_offset[3][1] =  9;
    max_x_offset[3][2] =  9;
    max_x_offset[3][3] = 10;
    // ---------------------
    max_x_offset[4][0] =  9;
    max_x_offset[4][1] =  9;
    max_x_offset[4][2] =  9;
    max_x_offset[4][3] =  9;
    // ---------------------
    max_x_offset[5][0] =  9;
    max_x_offset[5][1] =  9;
    max_x_offset[5][2] =  9;
    max_x_offset[5][3] = 10;
    // ---------------------
    max_x_offset[6][0] =  9;
    max_x_offset[6][1] =  9;
    max_x_offset[6][2] =  9;
    max_x_offset[6][3] = 10;
    // ---------------------
    max_x_offset[7][0] =  9;
    max_x_offset[7][1] =  9;
    max_x_offset[7][2] =  9;
    max_x_offset[7][3] = 10;
  end
  
  reg [4:0] max_y_offset [1:7][0:3];  // [type][rotate_idx]
  initial begin
    // ---------------------
    max_y_offset[1][0] = 20;
    max_y_offset[1][1] = 18;
    max_y_offset[1][2] = 19;
    max_y_offset[1][3] = 18;
    // ---------------------
    max_y_offset[2][0] = 20;
    max_y_offset[2][1] = 19;
    max_y_offset[2][2] = 19;
    max_y_offset[2][3] = 19;
    // ---------------------
    max_y_offset[3][0] = 20;
    max_y_offset[3][1] = 19;
    max_y_offset[3][2] = 19;
    max_y_offset[3][3] = 19;
    // ---------------------
    max_y_offset[4][0] = 20;
    max_y_offset[4][1] = 20;
    max_y_offset[4][2] = 20;
    max_y_offset[4][3] = 20;
    // ---------------------
    max_y_offset[5][0] = 20;
    max_y_offset[5][1] = 19;
    max_y_offset[5][2] = 19;
    max_y_offset[5][3] = 19;
    // ---------------------
    max_y_offset[6][0] = 20;
    max_y_offset[6][1] = 19;
    max_y_offset[6][2] = 19;
    max_y_offset[6][3] = 19;
    // ---------------------
    max_y_offset[7][0] = 20;
    max_y_offset[7][1] = 19;
    max_y_offset[7][2] = 19;
    max_y_offset[7][3] = 19;
  end
  
  localparam S_INIT = 0,
             S_GEN = 1,
             S_WAIT = 2,
             S_HOLD = 3,
             S_ROTATE = 4,
             S_LEFT = 5,
             S_RIGHT = 6,
             S_DOWN = 7,
             S_BAR = 8,
             S_BCHECK = 9,
             S_DCHECK = 10,
             S_MCHECK = 11,
             S_HCHECK = 12,
             S_CLEAR = 13,
             S_END = 14;
             
  // declaration --------------------------------------------------
    
  // nets
  wire [7:0] read_addr;
  wire [219:0] placed_mask;
  wire outside;
  wire valid;
  wire [2:0] next_type;
  wire [1:0] next_rotate_idx;
  wire [3:0] left_x_offset;
  wire [3:0] right_x_offset;
  wire [4:0] down_y_offset;
  wire [219:0] gen_mask;
  wire [219:0] hold_mask;
  wire [219:0] rotate_mask;
  wire [219:0] left_mask;
  wire [219:0] right_mask;
  wire [219:0] down_mask;
  reg [3:0] next_state;
  
  // registers
  reg [3:0] state = S_INIT;
  reg [199:0] placed_type [2:0];
  reg [2:0] curr_type;
  reg [219:0] curr_mask;
  reg [3:0] curr_x_offset;
  reg [4:0] curr_y_offset;
  reg [1:0] curr_rotate_idx;
  reg [2:0] check_type;
  reg [219:0] check_mask;
  reg [3:0] check_x_offset;
  reg [4:0] check_y_offset;
  reg [1:0] check_rotate_idx;
  
  // comb logic --------------------------------------------------
  
  assign read_addr = (19 - y) * 10 + (9 - x);
  assign placed_mask = {20'b0, placed_type[2] | placed_type[1] | placed_type[0]};
  assign outside = |curr_mask[219:200];
  assign valid = min_x_offset[check_type][check_rotate_idx] <= check_x_offset &&
                 check_x_offset <= max_x_offset[check_type][check_rotate_idx] &&
                 check_y_offset <= max_y_offset[check_type][check_rotate_idx] &&
                 !(|(check_mask & placed_mask));
  assign next_type = (curr_type == 7) ? 1 : curr_type + 1;
  assign next_rotate_idx = curr_rotate_idx + 1;
  assign left_x_offset = curr_x_offset - 1;
  assign right_x_offset = curr_x_offset + 1;
  assign down_y_offset = curr_y_offset + 1;
  assign gen_mask = {3'b000, mask[next_type][0][0], 3'b000,
                     3'b000, mask[next_type][0][1], 3'b000,
                     3'b000, mask[next_type][0][2], 3'b000,
                     3'b000, mask[next_type][0][3], 3'b000,
                     180'b0};
  assign hold_mask = {mask[hold][0][0], 6'b000,
                      mask[hold][0][1], 6'b000,
                      mask[hold][0][2], 6'b000,
                      mask[hold][0][3], 6'b000,
                      180'b0} >> (curr_x_offset - 2) >> (10 * curr_y_offset);
  assign rotate_mask = {mask[curr_type][next_rotate_idx][0], 6'b000,
                        mask[curr_type][next_rotate_idx][1], 6'b000,
                        mask[curr_type][next_rotate_idx][2], 6'b000,
                        mask[curr_type][next_rotate_idx][3], 6'b000,
                        180'b0} >> (curr_x_offset - 2) >> (10 * curr_y_offset);
  assign left_mask = curr_mask << 1;
  assign right_mask = curr_mask >> 1;
  assign down_mask = curr_mask >> 10;
  
  always @(*) begin
    next_state = S_INIT;
    if (reset_n) case (state)
      S_INIT: begin
        if (ctrl != 0) next_state = S_GEN;
        else next_state = S_INIT;
      end
      S_GEN: begin
        next_state = S_WAIT;
      end
      S_WAIT: begin
        case (ctrl)
          1: next_state = S_HOLD;
          2: next_state = S_ROTATE;
          3: next_state = S_LEFT;
          4: next_state = S_RIGHT;
          5: next_state = S_DOWN;
          6: next_state = S_BAR;
          default: next_state = S_WAIT;
        endcase
      end
      S_HOLD: begin
        next_state = S_HCHECK;
      end
      S_ROTATE, S_LEFT, S_RIGHT: begin
        next_state = S_MCHECK;
      end
      S_DOWN: begin
        next_state = S_DCHECK;
      end
      S_BAR: begin
        next_state = S_BCHECK;
      end
      S_BCHECK: begin
        if (valid) next_state = S_BAR;
        else if (outside) next_state = S_END;
        else next_state = S_CLEAR;
      end
      S_DCHECK: begin
        if (valid) next_state = S_WAIT;
        else if (outside) next_state = S_END;
        else next_state = S_CLEAR;
      end
      S_MCHECK, S_HCHECK: begin
        next_state = S_WAIT;
      end
      S_CLEAR: begin
        next_state = S_GEN;
      end
      S_END: begin
        if (ctrl != 0) next_state = S_INIT;
        else next_state = S_END;
      end
    endcase
  end
  
  // seq logic --------------------------------------------------
  
  always @(posedge clk) begin
    if (curr_mask[read_addr]) type <= curr_type;
    else type <= {placed_type[2][read_addr], placed_type[1][read_addr], placed_type[0][read_addr]};
  end
  
  always @(posedge clk) begin
    state <= next_state;
  end
  
  always @(posedge clk) begin
    case (state)
      S_INIT: begin
        hold <= 0;
        placed_type[2] <= 0;
        placed_type[1] <= 0;
        placed_type[0] <= 0;
        curr_type <= 0;
      end
      S_GEN: begin
        curr_type <= next_type;
        curr_mask <= gen_mask;
        curr_x_offset <= 5;
        curr_y_offset <= 0;
        curr_rotate_idx <= 0;
      end
      S_HOLD: begin
        check_type <= hold;
        check_mask <= hold_mask;
        check_x_offset <= curr_x_offset;
        check_y_offset <= curr_y_offset;
        check_rotate_idx <= 0;
      end
      S_ROTATE: begin
        check_type <= curr_type;
        check_mask <= rotate_mask;
        check_x_offset <= curr_x_offset;
        check_y_offset <= curr_y_offset;
        check_rotate_idx <= next_rotate_idx;
      end
      S_LEFT: begin
        check_type <= curr_type;
        check_mask <= left_mask;
        check_x_offset <= left_x_offset;
        check_y_offset <= curr_y_offset;
        check_rotate_idx <= curr_rotate_idx;
      end
      S_RIGHT: begin
        check_type <= curr_type;
        check_mask <= right_mask;
        check_x_offset <= right_x_offset;
        check_y_offset <= curr_y_offset;
        check_rotate_idx <= curr_rotate_idx;
      end
      S_DOWN, S_BAR: begin
        check_type <= curr_type;
        check_mask <= down_mask;
        check_x_offset <= curr_x_offset;
        check_y_offset <= down_y_offset;
        check_rotate_idx <= curr_rotate_idx;
      end
      S_BCHECK, S_DCHECK, S_MCHECK, S_HCHECK: begin
        if (valid) begin
          curr_type <= check_type;
          curr_mask <= check_mask;
          curr_x_offset <= check_x_offset;
          curr_y_offset <= check_y_offset;
          curr_rotate_idx <= check_rotate_idx;
          if (state == S_HCHECK) hold <= curr_type;
        end
        else if ((state == S_BCHECK || state == S_DCHECK) && !outside) begin
          placed_type[2] <= placed_type[2] | (curr_mask[199:0] & {200{curr_type[2]}});
          placed_type[1] <= placed_type[1] | (curr_mask[199:0] & {200{curr_type[1]}});
          placed_type[0] <= placed_type[0] | (curr_mask[199:0] & {200{curr_type[0]}});
        end
      end
      S_CLEAR: begin
      end
    endcase
  end
  
endmodule

`timescale 1ns / 1ps

module tetris(
  input clk,
  input reset_n,

  input [3:0] x,  // [0, 10)
  input [4:0] y,  // [0, 20)
  input [2:0] ctrl,

  output reg [4*4-1:0] score,  // 0xABCD BCD
  output reg [2:0] kind,
  output reg [2:0] hold,
  output reg [2:0] next [0:3]
);

  // parameters --------------------------------------------------

  // [kind][row][rotate_idx]
  localparam [3:0] mask[1:7][0:3][0:3] = '{
    '{ // 1: I
      { 4'b0000, 4'b0010, 4'b0000, 4'b0100 },
      { 4'b1111, 4'b0010, 4'b0000, 4'b0100 },
      { 4'b0000, 4'b0010, 4'b1111, 4'b0100 },
      { 4'b0000, 4'b0010, 4'b0000, 4'b0100 }
    },
    '{ // 2: J
      { 4'b1000, 4'b0110, 4'b0000, 4'b0100 },
      { 4'b1110, 4'b0100, 4'b1110, 4'b0100 },
      { 4'b0000, 4'b0100, 4'b0010, 4'b1100 },
      { 4'b0000, 4'b0000, 4'b0000, 4'b0000 }
    },
    '{ // 3: L
      { 4'b0010, 4'b0100, 4'b0000, 4'b1100 },
      { 4'b1110, 4'b0100, 4'b1110, 4'b0100 },
      { 4'b0000, 4'b0110, 4'b1000, 4'b0100 },
      { 4'b0000, 4'b0000, 4'b0000, 4'b0000 }
    },
    '{ // 4: O
      { 4'b0110, 4'b0110, 4'b0110, 4'b0110 },
      { 4'b0110, 4'b0110, 4'b0110, 4'b0110 },
      { 4'b0000, 4'b0000, 4'b0000, 4'b0000 },
      { 4'b0000, 4'b0000, 4'b0000, 4'b0000 }
    },
    '{ // 5: S
      { 4'b0110, 4'b0100, 4'b0000, 4'b1000 },
      { 4'b1100, 4'b0110, 4'b0110, 4'b1100 },
      { 4'b0000, 4'b0010, 4'b1100, 4'b0100 },
      { 4'b0000, 4'b0000, 4'b0000, 4'b0000 }
    },
    '{ // 6: T
      { 4'b0100, 4'b0100, 4'b0000, 4'b0100 },
      { 4'b1110, 4'b0110, 4'b1110, 4'b1100 },
      { 4'b0000, 4'b0100, 4'b0100, 4'b0100 },
      { 4'b0000, 4'b0000, 4'b0000, 4'b0000 }
    },
    '{ // 7: Z
      { 4'b1100, 4'b0010, 4'b0000, 4'b0100 },
      { 4'b0110, 4'b0110, 4'b1100, 4'b1100 },
      { 4'b0000, 4'b0100, 4'b0110, 4'b1000 },
      { 4'b0000, 4'b0000, 4'b0000, 4'b0000 }
    }
  };

  // [kind][rotate_idx]
  localparam [1:0] min_x_offset [1:7][0:3] = '{
    '{ 2, 0, 2, 1 },
    '{ 2, 1, 2, 2 },
    '{ 2, 1, 2, 2 },
    '{ 1, 1, 1, 1 },
    '{ 2, 1, 2, 2 },
    '{ 2, 1, 2, 2 },
    '{ 2, 1, 2, 2 }
  };

  // [kind][rotate_idx]
  localparam [3:0] max_x_offset [1:7][0:3] = '{
    '{  8,  9,  8, 10 },
    '{  9,  9,  9, 10 },
    '{  9,  9,  9, 10 },
    '{  9,  9,  9,  9 },
    '{  9,  9,  9, 10 },
    '{  9,  9,  9, 10 },
    '{  9,  9,  9, 10 }
  };

  // [kind][rotate_idx]
  localparam [4:0] max_y_offset [1:7][0:3] = '{
    '{ 20, 18, 19, 18 },
    '{ 20, 19, 19, 19 },
    '{ 20, 19, 19, 19 },
    '{ 20, 20, 20, 20 },
    '{ 20, 19, 19, 19 },
    '{ 20, 19, 19, 19 },
    '{ 20, 19, 19, 19 }
  };

  typedef enum {
    INIT, GEN, WAIT, HOLD,
    ROTATE, LEFT, RIGHT, DOWN, BAR,
    BCHECK, DCHECK, MCHECK, HCHECK,
    CLEAR, END
  } state_type;

  // declaration --------------------------------------------------

  // nets
  wire [7:0] read_addr;
  wire [219:0] placed_mask;
  wire outside;
  wire valid;
  wire [2:0] next_kind;
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
  state_type next_state;

  // registers
  state_type state = INIT;
  reg [199:0] placed_kind [2:0];
  reg [2:0] curr_kind;
  reg [219:0] curr_mask;
  reg [3:0] curr_x_offset;
  reg [4:0] curr_y_offset;
  reg [1:0] curr_rotate_idx;
  reg [2:0] check_kind;
  reg [219:0] check_mask;
  reg [3:0] check_x_offset;
  reg [4:0] check_y_offset;
  reg [1:0] check_rotate_idx;

  // comb logic --------------------------------------------------

  assign read_addr = (19 - y) * 10 + (9 - x);
  assign placed_mask = {20'b0, placed_kind[2] | placed_kind[1] | placed_kind[0]};
  assign outside = |curr_mask[219:200];
  assign valid = min_x_offset[check_kind][check_rotate_idx] <= check_x_offset &&
                 check_x_offset <= max_x_offset[check_kind][check_rotate_idx] &&
                 check_y_offset <= max_y_offset[check_kind][check_rotate_idx] &&
                 !(|(check_mask & placed_mask));
  assign next_kind = (curr_kind == 7) ? 1 : curr_kind + 1;
  assign next_rotate_idx = curr_rotate_idx + 1;
  assign left_x_offset = curr_x_offset - 1;
  assign right_x_offset = curr_x_offset + 1;
  assign down_y_offset = curr_y_offset + 1;
  assign gen_mask = {3'b000, mask[next_kind][0][0], 3'b000,
                     3'b000, mask[next_kind][1][0], 3'b000,
                     3'b000, mask[next_kind][2][0], 3'b000,
                     3'b000, mask[next_kind][3][0], 3'b000,
                     180'b0};
  assign hold_mask = {mask[hold][0][0], 6'b000,
                      mask[hold][1][0], 6'b000,
                      mask[hold][2][0], 6'b000,
                      mask[hold][3][0], 6'b000,
                      180'b0} >> (curr_x_offset - 2) >> (10 * curr_y_offset);
  assign rotate_mask = {mask[curr_kind][0][next_rotate_idx], 6'b000,
                        mask[curr_kind][1][next_rotate_idx], 6'b000,
                        mask[curr_kind][2][next_rotate_idx], 6'b000,
                        mask[curr_kind][3][next_rotate_idx], 6'b000,
                        180'b0} >> (curr_x_offset - 2) >> (10 * curr_y_offset);
  assign left_mask = curr_mask << 1;
  assign right_mask = curr_mask >> 1;
  assign down_mask = curr_mask >> 10;

  always_comb begin
    next_state = INIT;
    if (reset_n) case (state)
      INIT: begin
        if (ctrl != 0)
            next_state = GEN;
        else
            next_state = INIT;
      end
      GEN: begin
        next_state = WAIT;
      end
      WAIT: begin
        case (ctrl)
          1: next_state = HOLD;
          2: next_state = ROTATE;
          3: next_state = LEFT;
          4: next_state = RIGHT;
          5: next_state = DOWN;
          6: next_state = BAR;
          default: next_state = WAIT;
        endcase
      end
      HOLD: begin
        next_state = HCHECK;
      end
      ROTATE, LEFT, RIGHT: begin
        next_state = MCHECK;
      end
      DOWN: begin
        next_state = DCHECK;
      end
      BAR: begin
        next_state = BCHECK;
      end
      BCHECK: begin
        if (valid)
            next_state = BAR;
        else if (outside)
            next_state = END;
        else
            next_state = CLEAR;
      end
      DCHECK: begin
        if (valid)
            next_state = WAIT;
        else if (outside)
            next_state = END;
        else
            next_state = CLEAR;
      end
      MCHECK, HCHECK: begin
        next_state = WAIT;
      end
      CLEAR: begin
        next_state = GEN;
      end
      END: begin
        if (ctrl != 0)
            next_state = INIT;
        else
            next_state = END;
      end
    endcase
  end

  // seq logic --------------------------------------------------

  always_ff @(posedge clk)
    if (curr_mask[read_addr]) kind <= curr_kind;
    else kind <= {placed_kind[2][read_addr], placed_kind[1][read_addr], placed_kind[0][read_addr]};

  always_ff @(posedge clk)
    state <= next_state;

  always @(posedge clk) begin
    case (state)
      INIT: begin
        hold <= 0;
        placed_kind[2] <= 0;
        placed_kind[1] <= 0;
        placed_kind[0] <= 0;
        curr_kind <= 0;
      end
      GEN: begin
        curr_kind <= next_kind;
        curr_mask <= gen_mask;
        curr_x_offset <= 5;
        curr_y_offset <= 0;
        curr_rotate_idx <= 0;
      end
      HOLD: begin
        check_kind <= hold;
        check_mask <= hold_mask;
        check_x_offset <= curr_x_offset;
        check_y_offset <= curr_y_offset;
        check_rotate_idx <= 0;
      end
      ROTATE: begin
        check_kind <= curr_kind;
        check_mask <= rotate_mask;
        check_x_offset <= curr_x_offset;
        check_y_offset <= curr_y_offset;
        check_rotate_idx <= next_rotate_idx;
      end
      LEFT: begin
        check_kind <= curr_kind;
        check_mask <= left_mask;
        check_x_offset <= left_x_offset;
        check_y_offset <= curr_y_offset;
        check_rotate_idx <= curr_rotate_idx;
      end
      RIGHT: begin
        check_kind <= curr_kind;
        check_mask <= right_mask;
        check_x_offset <= right_x_offset;
        check_y_offset <= curr_y_offset;
        check_rotate_idx <= curr_rotate_idx;
      end
      DOWN, BAR: begin
        check_kind <= curr_kind;
        check_mask <= down_mask;
        check_x_offset <= curr_x_offset;
        check_y_offset <= down_y_offset;
        check_rotate_idx <= curr_rotate_idx;
      end
      BCHECK, DCHECK, MCHECK, HCHECK: begin
        if (valid) begin
          curr_kind <= check_kind;
          curr_mask <= check_mask;
          curr_x_offset <= check_x_offset;
          curr_y_offset <= check_y_offset;
          curr_rotate_idx <= check_rotate_idx;
          if (state == HCHECK) hold <= curr_kind;
        end
        else if ((state == BCHECK || state == DCHECK) && !outside) begin
          placed_kind[2] <= placed_kind[2] | (curr_mask[199:0] & {200{curr_kind[2]}});
          placed_kind[1] <= placed_kind[1] | (curr_mask[199:0] & {200{curr_kind[1]}});
          placed_kind[0] <= placed_kind[0] | (curr_mask[199:0] & {200{curr_kind[0]}});
        end
      end
      CLEAR: begin
      end
    endcase
  end

endmodule

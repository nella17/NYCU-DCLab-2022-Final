`timescale 1ns / 1ps

module tetris import enum_type::*;
(
  input clk,
  input reset_n,

  input [3:0] x,  // [0, 10)
  input [4:0] y,  // [0, 20)
  input control_type ctrl,

  output reg [4*4-1:0] score,  // 0xABCD BCD
  output reg [2:0] kind,
  output reg [2:0] hold,
  output reg [2:0] next [0:3],
  output ready
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
  wire [199:0] new_placed_kind [2:0];
  wire do_clear;
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
  reg [199:0] test_mask;
  reg [199:0] clear_mask;
  reg [4:0] clear_counter;

  // comb logic --------------------------------------------------

  assign ready = (state == WAIT);
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
  assign new_placed_kind[2] = (placed_kind[2] & ~clear_mask) | ((placed_kind[2] >> 10) & clear_mask);
  assign new_placed_kind[1] = (placed_kind[1] & ~clear_mask) | ((placed_kind[1] >> 10) & clear_mask);
  assign new_placed_kind[0] = (placed_kind[0] & ~clear_mask) | ((placed_kind[0] >> 10) & clear_mask);
  assign do_clear = &test_mask[9:0];

  always_comb begin
    next_state = INIT;
    if (reset_n) case (state)
      INIT:
        if (ctrl != NOEVENT)
            next_state = GEN;
        else
            next_state = INIT;
      GEN:
        next_state = WAIT;
      WAIT:
        case (ctrl)
          LEFT:       next_state = LEFT;
          RIGHT:      next_state = RIGHT;
          DOWN:       next_state = DOWN;
          DROP:       next_state = DROP;
          HOLD:       next_state = HOLD;
          ROTATE:     next_state = ROTATE;
          ROTATE_REV: next_state = ROTATE_REV;
          BAR:        next_state = BAR;
        endcase
      HOLD:
        next_state = HCHECK;
      LEFT, RIGHT, ROTATE, ROTATE_REV:
        next_state = MCHECK;
      DOWN:
        next_state = DCHECK;
      DROP:
        next_state = PCHECK;
      PCHECK:
        if (valid)
            next_state = DROP;
        else if (outside)
            next_state = END;
        else
            next_state = CLEAR;
      DCHECK:
        if (valid)
            next_state = WAIT;
        else if (outside)
            next_state = END;
        else
            next_state = CLEAR;
      MCHECK, HCHECK:
        next_state = WAIT;
      BCHECK:
        next_state = WAIT;
      CLEAR:
        if (clear_counter == 19)
          next_state = GEN;
        else
          next_state = CLEAR;
      END:
        if (ctrl != NOEVENT)
            next_state = INIT;
        else
            next_state = END;
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
      DOWN, DROP: begin
        check_kind <= curr_kind;
        check_mask <= down_mask;
        check_x_offset <= curr_x_offset;
        check_y_offset <= down_y_offset;
        check_rotate_idx <= curr_rotate_idx;
      end
      PCHECK, DCHECK, MCHECK, HCHECK: begin
        if (valid) begin
          curr_kind <= check_kind;
          curr_mask <= check_mask;
          curr_x_offset <= check_x_offset;
          curr_y_offset <= check_y_offset;
          curr_rotate_idx <= check_rotate_idx;
          if (state == HCHECK) hold <= curr_kind;
        end
        else if ((state == PCHECK || state == DCHECK) && !outside) begin
          placed_kind[2] <= placed_kind[2] | (curr_mask[199:0] & {200{curr_kind[2]}});
          placed_kind[1] <= placed_kind[1] | (curr_mask[199:0] & {200{curr_kind[1]}});
          placed_kind[0] <= placed_kind[0] | (curr_mask[199:0] & {200{curr_kind[0]}});
          test_mask <= placed_mask;
          clear_mask <= {200{1'b1}};
          clear_counter <= 0;
        end
      end
      CLEAR: begin
        test_mask <= test_mask >> 10;
        clear_mask <= clear_mask << 10;
        if (do_clear) begin
          placed_kind[2] <= new_placed_kind[2];
          placed_kind[1] <= new_placed_kind[1];
          placed_kind[0] <= new_placed_kind[0];
          test_mask <= new_placed_kind[2] | new_placed_kind[1] | new_placed_kind[0];
          clear_mask <= {200{1'b1}};
          clear_counter <= 0;
        end
        else clear_counter <= clear_counter + 1;
      end
    endcase
  end

endmodule

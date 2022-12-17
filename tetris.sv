`timescale 1ns / 1ps
`define BCD_ADD(in, inc) \
    ((in) + (inc) + ((inc) && (in) >= 9 ? 6 : 0))

module tetris import enum_type::*;
(
  input clk,
  input reset_n,

  input [3:0] x,  // [0, 10)
  input [4:0] y,  // [0, 20)
  input state_type ctrl,
  input [9:0] bar_mask,

  output state_type state,
  output reg [4*4-1:0] score,  // 0xABCD BCD
  output reg [2:0] kind,
  output reg [2:0] hold,
  output reg [2:0] next [0:3]
);
  genvar gi;

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
  wire boutside;
  wire valid;
  wire [1:0] next_rotate_idx;
  wire [1:0] next_rotate_rev_idx;
  wire [3:0] left_x_offset;
  wire [3:0] right_x_offset;
  wire [4:0] down_y_offset;
  wire [2:0] hold_kind;
  wire [219:0] gen_mask;
  wire [219:0] hold_mask;
  wire [219:0] rotate_mask;
  wire [219:0] rotate_rev_mask;
  wire [219:0] left_mask;
  wire [219:0] right_mask;
  wire [219:0] down_mask;
  wire do_clear;
  state_type next_state;

  // registers
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
  reg [199:0] pending_mask;
  reg [4:0] pending_counter;

  // comb logic --------------------------------------------------

  assign read_addr = (19 - y) * 10 + (9 - x);
  assign placed_mask = {20'b0, placed_kind[2] | placed_kind[1] | placed_kind[0]};
  assign outside = |curr_mask[219:200];
  assign boutside = |(placed_mask >> 10*(20-pending_counter));
  assign valid = min_x_offset[check_kind][check_rotate_idx] <= check_x_offset &&
                 check_x_offset <= max_x_offset[check_kind][check_rotate_idx] &&
                 check_y_offset <= max_y_offset[check_kind][check_rotate_idx] &&
                 !(|(check_mask & placed_mask));
  assign next_rotate_idx = curr_rotate_idx + 1;
  assign next_rotate_rev_idx = curr_rotate_idx - 1;
  assign left_x_offset = curr_x_offset - 1;
  assign right_x_offset = curr_x_offset + 1;
  assign down_y_offset = curr_y_offset + 1;
  assign hold_kind = (hold == 0) ? next[0] : hold;
  assign gen_mask = {3'b000, mask[next[0]][0][0], 3'b000,
                     3'b000, mask[next[0]][1][0], 3'b000,
                     3'b000, mask[next[0]][2][0], 3'b000,
                     3'b000, mask[next[0]][3][0], 3'b000,
                     180'b0};
  assign hold_mask = {3'b000, mask[hold_kind][0][0], 3'b000,
                      3'b000, mask[hold_kind][1][0], 3'b000,
                      3'b000, mask[hold_kind][2][0], 3'b000,
                      3'b000, mask[hold_kind][3][0], 3'b000,
                      180'b0};
  assign rotate_mask = {mask[curr_kind][0][next_rotate_idx], 6'b000,
                        mask[curr_kind][1][next_rotate_idx], 6'b000,
                        mask[curr_kind][2][next_rotate_idx], 6'b000,
                        mask[curr_kind][3][next_rotate_idx], 6'b000,
                        180'b0} >> (curr_x_offset - 2) >> (10 * curr_y_offset);
  assign rotate_rev_mask = {mask[curr_kind][0][next_rotate_rev_idx], 6'b000,
                            mask[curr_kind][1][next_rotate_rev_idx], 6'b000,
                            mask[curr_kind][2][next_rotate_rev_idx], 6'b000,
                            mask[curr_kind][3][next_rotate_rev_idx], 6'b000,
                            180'b0} >> (curr_x_offset - 2) >> (10 * curr_y_offset);
  assign left_mask = curr_mask << 1;
  assign right_mask = curr_mask >> 1;
  assign down_mask = curr_mask >> 10;
  assign do_clear = &test_mask[9:0];

  always_comb begin
    next_state = INIT;
    if (reset_n) case (state)
      INIT:
        if (ctrl != NONE)
            next_state = GEN;
        else
            next_state = INIT;
      GEN:
        next_state = WAIT;
      WAIT:
        if (ctrl != NONE)
          next_state = ctrl;
        else
          next_state = WAIT;
      HOLD:
        next_state = HCHECK;
      LEFT, RIGHT, ROTATE, ROTATE_REV:
        next_state = MCHECK;
      DOWN:
        next_state = DCHECK;
      DROP:
        next_state = PCHECK;
      BAR:
        next_state = WAIT;
      PCHECK:
        if (valid)
            next_state = DROP;
        else if (outside)
            next_state = END;
        else
            next_state = CPREP;
      DCHECK:
        if (valid)
            next_state = WAIT;
        else if (outside)
            next_state = END;
        else
            next_state = CPREP;
      MCHECK:
        next_state = WAIT;
      HCHECK:
        if (hold == 0) 
          next_state = GEN;
        else
          next_state = WAIT;
      CPREP:
        next_state = CLEAR;
      CLEAR:
        if (do_clear)
          next_state = CPREP;
        else if (clear_counter == 19)
          next_state = BPLACE;
        else
          next_state = CLEAR;
      BPLACE:
        if (boutside)
          next_state = END;
        else
          next_state = GEN;
      END:
        if (ctrl != 0)
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
        curr_kind <= 0;
        next[0] <= 1;
        next[1] <= 2;
        next[2] <= 3;
        next[3] <= 4;
        placed_kind[2] <= 0;
        placed_kind[1] <= 0;
        placed_kind[0] <= 0;
        pending_mask <= 0;
        pending_counter <= 0;
      end
      GEN: begin
        curr_kind <= next[0];
        next[0] <= next[1];
        next[1] <= next[2];
        next[2] <= next[3];
        next[3] <= (next[3] == 7) ? 1 : next[3] + 1;
        curr_mask <= gen_mask;
        curr_x_offset <= 5;
        curr_y_offset <= 0;
        curr_rotate_idx <= 0;
      end
      HOLD: begin
        check_kind <= hold_kind;
        check_mask <= hold_mask;
        check_x_offset <= 5;
        check_y_offset <= 0;
        check_rotate_idx <= 0;
      end
      ROTATE: begin
        check_kind <= curr_kind;
        check_mask <= rotate_mask;
        check_x_offset <= curr_x_offset;
        check_y_offset <= curr_y_offset;
        check_rotate_idx <= next_rotate_idx;
      end
      ROTATE_REV: begin
        check_kind <= curr_kind;
        check_mask <= rotate_rev_mask;
        check_x_offset <= curr_x_offset;
        check_y_offset <= curr_y_offset;
        check_rotate_idx <= next_rotate_rev_idx;
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
      BAR: begin
        pending_mask <= {pending_mask[189:0], bar_mask};
        pending_counter <= pending_counter + 1;
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
        else if ((state == PCHECK || state == DCHECK)) begin
          placed_kind[2] <= placed_kind[2] | (curr_mask[199:0] & {200{curr_kind[2]}});
          placed_kind[1] <= placed_kind[1] | (curr_mask[199:0] & {200{curr_kind[1]}});
          placed_kind[0] <= placed_kind[0] | (curr_mask[199:0] & {200{curr_kind[0]}});
        end
      end
      CPREP: begin
        test_mask <= placed_mask;
        clear_mask <= {200{1'b1}};
        clear_counter <= 0;
      end
      CLEAR: begin
        test_mask <= test_mask >> 10;
        clear_mask <= clear_mask << 10;
        clear_counter <= clear_counter + 1;
        if (do_clear) begin
          placed_kind[2] <= (placed_kind[2] & ~clear_mask) | ((placed_kind[2] >> 10) & clear_mask);
          placed_kind[1] <= (placed_kind[1] & ~clear_mask) | ((placed_kind[1] >> 10) & clear_mask);
          placed_kind[0] <= (placed_kind[0] & ~clear_mask) | ((placed_kind[0] >> 10) & clear_mask);
        end
      end
      BPLACE: begin
        placed_kind[2] <= (placed_kind[2] << (10 * pending_counter)) | pending_mask;
        placed_kind[1] <= (placed_kind[1] << (10 * pending_counter)) | pending_mask;
        placed_kind[0] <= (placed_kind[0] << (10 * pending_counter)) | pending_mask;
        pending_mask <= 0;
        pending_counter <= 0;
      end
    endcase
  end

  reg [4:0] score_carry = 0;
  always_ff @(posedge clk)
      if (~reset_n || state == INIT || ~do_clear)
          score_carry[0] <= 0;
      else
          score_carry[0] <= 1;
  generate for(gi = 0; gi < 4; gi = gi+1)
      always_ff @(posedge clk)
          if (~reset_n || state == INIT)
              score[gi*4+:4] <= 0;
          else
              { score_carry[gi+1], score[gi*4+:4] } <= `BCD_ADD(score[gi*4+:4], score_carry[gi]);
  endgenerate

endmodule

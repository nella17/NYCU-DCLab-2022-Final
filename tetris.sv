`timescale 1ns / 1ps
`define BCD_ADD(in, inc) \
    ((in) + (inc) + ((inc) && (in) >= 9 ? 6 : 0))

module tetris import enum_type::*;
(
  input clk,
  input reset_n,
  input [31:0] rng,

  input [4:0] x, y,  // [0, 10), [0, 20)
  input state_type ctrl,
  input [9:0] bar_mask,

  output state_type state,
  output reg [4*4-1:0] score,  // 0xABCD BCD
  output score_inc,
  output reg [3:0] kind,
  output reg [3:0] hold,
  output reg [3:0] next [0:3],
  output reg hold_locked,
  output reg [4:0] pending_counter,
  output reg [2*4-1:0] combo,
  output reg t_spin
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
  localparam [4:0] min_x_offset [1:7][0:3] = '{
    '{ 2, 0, 2, 1 },
    '{ 2, 1, 2, 2 },
    '{ 2, 1, 2, 2 },
    '{ 1, 1, 1, 1 },
    '{ 2, 1, 2, 2 },
    '{ 2, 1, 2, 2 },
    '{ 2, 1, 2, 2 }
  };

  // [kind][rotate_idx]
  localparam [4:0] max_x_offset [1:7][0:3] = '{
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
  wire outside,
       boutside,
       valid,
       pvalid,
       do_clear;
  wire [1:0] next_rotate_idx,
             next_rotate_rev_idx;
  wire [4:0] left_x_offset,
             right_x_offset,
             down_y_offset;
  wire [2:0] hold_kind;
  wire [219:0] placed_mask,
               gen_mask,
               hold_mask,
               rotate_mask,
               rotate_rev_mask,
               left_mask,
               right_mask,
               down_mask,
               preview_down_mask;
  state_type next_state;

  // registers
  reg [3:0] curr_kind  = 0,
            check_kind = 0;
  reg [4:0] curr_x_offset  = 0,
            curr_y_offset  = 0,
            check_x_offset = 0,
            check_y_offset = 0;
  reg [1:0] curr_rotate_idx  = 0,
            check_rotate_idx = 0;
  reg [219:0] curr_mask  = 0,
              check_mask = 0,
              preview_mask = 0;
  reg [199:0] placed_kind [3:0] = { 0, 0, 0, 0 },
              test_mask = 0,
              clear_mask = 0,
              pending_mask = 0;
  reg [4:0] clear_counter   = 0;
  reg curr_mask_updated = 0;

  // comb logic --------------------------------------------------

  assign read_addr = (19 - y) * 10 + (9 - x);
  assign placed_mask = {20'b0, placed_kind[3] | placed_kind[2] | placed_kind[1] | placed_kind[0]};
  assign outside = |curr_mask[219:200];
  assign boutside = |(placed_mask >> 10*(20-pending_counter));
  assign valid = min_x_offset[check_kind][check_rotate_idx] <= check_x_offset &&
                 check_x_offset <= max_x_offset[check_kind][check_rotate_idx] &&
                 check_y_offset <= max_y_offset[check_kind][check_rotate_idx] &&
                 !(|(check_mask & placed_mask));
  assign pvalid = !(|preview_mask[9:0]) &&
                  !(|(preview_down_mask & placed_mask));
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
  assign preview_down_mask = preview_mask >> 10;
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
        if (ctrl > WAIT)
          next_state = ctrl;
        else
          next_state = WAIT;
      HOLD:
        if (hold_locked) next_state = WAIT;
        else next_state = HCHECK;
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
    if (curr_mask[read_addr])
      kind <= curr_kind;
    else if (preview_mask[read_addr])
      kind <= 9;
    else
      kind <= {
        placed_kind[3][read_addr],
        placed_kind[2][read_addr],
        placed_kind[1][read_addr],
        placed_kind[0][read_addr]
      };

  always_ff @(posedge clk)
    state <= next_state;

  reg [0:2] i;
  always_ff @(posedge clk)
    if (~reset_n || state == INIT)
      next <= {
        rng[0+:3],
        rng[3+:3],
        rng[6+:3],
        rng[9+:3]
      };
    else if (state == GEN)
      next <= {
        next[1], 
        next[2],
        next[3],
        rng[0+:3]
      };
    else
      for(i = 0; i < 4; i++)
        if (next[i] == 0)
          next[i] <= rng[4+i*3+:3];

  always_ff @(posedge clk) begin
    if (~reset_n || state == INIT) begin
      hold <= 0;
      curr_kind <= 0;
      curr_mask <= 0;
      placed_kind <= { 0, 0, 0, 0 };
      pending_mask <= 0;
      pending_counter <= 0;
      hold_locked <= 0;
    end else begin
      case (state)
        GEN: begin
          curr_kind <= next[0];
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
          hold_locked <= 1;
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
          if (bar_mask) begin
            pending_mask <= { pending_mask[189:0], (bar_mask ^ 10'b1111111111) };
            pending_counter <= pending_counter + 1;
          end
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
            curr_mask <= 0;
            placed_kind[3] <= placed_kind[3] | (curr_mask[199:0] & {200{curr_kind[3]}});
            placed_kind[2] <= placed_kind[2] | (curr_mask[199:0] & {200{curr_kind[2]}});
            placed_kind[1] <= placed_kind[1] | (curr_mask[199:0] & {200{curr_kind[1]}});
            placed_kind[0] <= placed_kind[0] | (curr_mask[199:0] & {200{curr_kind[0]}});
          end
        end
        CPREP: begin
          test_mask <= placed_mask;
          clear_mask <= {200{1'b1}};
          clear_counter <= 0;
          hold_locked <= 0;
        end
        CLEAR: begin
          test_mask <= test_mask >> 10;
          clear_mask <= clear_mask << 10;
          clear_counter <= clear_counter + 1;
          if (do_clear) begin
            placed_kind[3] <= (placed_kind[3] & ~clear_mask) | ((placed_kind[3] >> 10) & clear_mask);
            placed_kind[2] <= (placed_kind[2] & ~clear_mask) | ((placed_kind[2] >> 10) & clear_mask);
            placed_kind[1] <= (placed_kind[1] & ~clear_mask) | ((placed_kind[1] >> 10) & clear_mask);
            placed_kind[0] <= (placed_kind[0] & ~clear_mask) | ((placed_kind[0] >> 10) & clear_mask);
          end
        end
        BPLACE: begin
          placed_kind[3] <= (placed_kind[3] << (10 * pending_counter)) | pending_mask;
          placed_kind[2] <= (placed_kind[2] << (10 * pending_counter));
          placed_kind[1] <= (placed_kind[1] << (10 * pending_counter));
          placed_kind[0] <= (placed_kind[0] << (10 * pending_counter));
          pending_mask <= 0;
          pending_counter <= 0;
        end
      endcase
    end
  end

  always_ff @(posedge clk) begin
    if (state == GEN || state == PCHECK || state == DCHECK || state == MCHECK || state == HCHECK)
      curr_mask_updated <= 1;
    else
      curr_mask_updated <= 0;
  end

  always_ff @(posedge clk) begin
    if (state == INIT)
      preview_mask <= 0;
    else if (curr_mask_updated)
      preview_mask <= curr_mask;
    else if (pvalid)
      preview_mask <= preview_down_mask;
  end

  reg [1:0] last_move [1:0];  // 0: DOWN, 1: ROTATE/ROTATE_REV, 2: other
  always @(posedge clk) begin
    if (state == GEN) begin
      last_move[1] <= 2;
      last_move[0] <= 2;
    end
    else if (state == WAIT && ctrl != NONE && ctrl != BAR) begin
      last_move[1] <= last_move[0];
      if (ctrl == DOWN)
        last_move[0] <= 0;
      else if (ctrl == ROTATE || ctrl == ROTATE_REV)
        last_move[0] <= 1;
      else
        last_move[0] <= 2;
    end
  end

  reg [2:0] lines_cleared = 0;
  reg [7:0] combo_score = 0;
  reg [7:0] score_pending = 0;
  reg [4:0] score_carry = 0;
  assign score_inc = score_carry[0];
  wire t_spin_detected = (last_move[1] == 1) && (last_move[0] == 0) && (curr_kind == 6);
  always_ff @(posedge clk) begin
    score_carry[0] <= 0;
    if (~reset_n || state == INIT) begin
      lines_cleared <= 0;
      combo_score <= 0;
      score_pending <= 0;
      t_spin <= 0;
    end 
    else if (state == CLEAR && do_clear) begin
      lines_cleared <= lines_cleared + 1;
    end
    else if (state == BPLACE) begin
      lines_cleared <= 0;
      if (lines_cleared == 0) begin
        combo_score <= 0;
        t_spin <= 0;
      end
      else begin
        combo_score <= combo_score + 1;
        case (lines_cleared)
          1: score_pending <= score_pending + 1 + combo_score + (t_spin_detected ? 4 : 0);
          2: score_pending <= score_pending + 3 + combo_score + (t_spin_detected ? 4 : 0);
          3: score_pending <= score_pending + 5 + combo_score + (t_spin_detected ? 4 : 0);
          4: score_pending <= score_pending + 8 + combo_score + (t_spin_detected ? 4 : 0);
        endcase
        t_spin <= t_spin_detected;
      end
    end
    else if (score_pending != 0) begin
      score_pending <= score_pending - 1;
      score_carry[0] <= 1;
    end
  end

  always @(posedge clk) begin
    if (combo_score == 0)
      combo <= 0;
    else begin
      combo[7:4] <= (combo_score - 1) / 10;
      combo[3:0] <= (combo_score - 1) % 10;
    end
  end

  generate for(gi = 0; gi < 4; gi = gi+1)
    always_ff @(posedge clk)
      if (~reset_n || state == INIT)
        score[gi*4+:4] <= 0;
      else
        { score_carry[gi+1], score[gi*4+:4] } <= `BCD_ADD(score[gi*4+:4], score_carry[gi]);
  endgenerate

endmodule

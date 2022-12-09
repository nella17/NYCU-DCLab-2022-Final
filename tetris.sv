`timescale 1ns / 1ps

module tetris(
  input [3:0] x,
  input [4:0] y,
  input ctrl_valid,
  input [1:0] ctrl,
  
  input clk,
  input reset_n,
  
  output [2:0] kind
);
  // parameters
  localparam [47:0] mask [1:7][0:3] = '{
    '{ // 1
       { 12'b000000000000, 
         12'b000000001111, 
         12'b000000000000,
         12'b000000000000 },
       { 12'b000000000010, 
         12'b000000000010, 
         12'b000000000010,
         12'b000000000010 },
       { 12'b000000000000, 
         12'b000000000000, 
         12'b000000001111,
         12'b000000000000 },
       { 12'b000000000100, 
         12'b000000000100, 
         12'b000000000100,
         12'b000000000100 } 
    },
    '{ // 2
       { 12'b000000001000, 
         12'b000000001110, 
         12'b000000000000,
         12'b000000000000 },
       { 12'b000000000110, 
         12'b000000000100, 
         12'b000000000100,
         12'b000000000000 },
       { 12'b000000000000, 
         12'b000000001110, 
         12'b000000000010,
         12'b000000000000 },
       { 12'b000000000100, 
         12'b000000000100, 
         12'b000000001100,
         12'b000000000000 } 
    },
    '{ // 3
       { 12'b000000000010, 
         12'b000000001110, 
         12'b000000000000,
         12'b000000000000 },
       { 12'b000000000100, 
         12'b000000000100, 
         12'b000000000110,
         12'b000000000000 },
       { 12'b000000000000, 
         12'b000000001110, 
         12'b000000001000,
         12'b000000000000 },
       { 12'b000000001100, 
         12'b000000000100, 
         12'b000000000100,
         12'b000000000000 } 
    },
    '{ // 4
       { 12'b000000000110, 
         12'b000000000110, 
         12'b000000000000,
         12'b000000000000 },
       { 12'b000000000110, 
         12'b000000000110, 
         12'b000000000000,
         12'b000000000000 },
       { 12'b000000000110, 
         12'b000000000110, 
         12'b000000000000,
         12'b000000000000 },
       { 12'b000000000110, 
         12'b000000000110, 
         12'b000000000000,
         12'b000000000000 } 
    },
    '{ // 5
       { 12'b000000000110, 
         12'b000000001100, 
         12'b000000000000,
         12'b000000000000 },
       { 12'b000000000100, 
         12'b000000000110, 
         12'b000000000010,
         12'b000000000000 },
       { 12'b000000000000, 
         12'b000000000110, 
         12'b000000001100,
         12'b000000000000 },
       { 12'b000000001000, 
         12'b000000001100, 
         12'b000000000100,
         12'b000000000000 } 
    },
    '{ // 6
       { 12'b000000000100, 
         12'b000000001110, 
         12'b000000000000,
         12'b000000000000 },
       { 12'b000000000100, 
         12'b000000000110, 
         12'b000000000100,
         12'b000000000000 },
       { 12'b000000000000, 
         12'b000000001110, 
         12'b000000000100,
         12'b000000000000 },
       { 12'b000000000100, 
         12'b000000001100, 
         12'b000000000100,
         12'b000000000000 } 
    },
    '{ // 7
       { 12'b000000001100, 
         12'b000000000110, 
         12'b000000000000,
         12'b000000000000 },
       { 12'b000000000010, 
         12'b000000000110, 
         12'b000000000100,
         12'b000000000000 },
       { 12'b000000000000, 
         12'b000000001100, 
         12'b000000000110,
         12'b000000000000 },
       { 12'b000000000100, 
         12'b000000001100, 
         12'b000000001000,
         12'b000000000000 } 
    }
  };
  
  localparam [3:0] min_x_offset [1:7][0:3] = '{
    '{ 2, 1, 2, 0 },
    '{ 1, 1, 1, 0 },
    '{ 1, 1, 1, 0 },
    '{ 1, 1, 1, 1 },
    '{ 1, 1, 1, 0 },
    '{ 1, 1, 1, 0 },
    '{ 1, 1, 1, 0 }
  };
  
  localparam [3:0] max_x_offset [1:7][0:3] = '{
    '{ 8, 10, 8, 9 },
    '{ 8, 9, 8, 8 },
    '{ 8, 9, 8, 8 },
    '{ 9, 9, 9, 9 },
    '{ 8, 9, 8, 8 },
    '{ 8, 9, 8, 8 },
    '{ 8, 9, 8, 8 }
  };
  
  localparam [4:0] max_y_offset [1:7][0:3] = '{
    '{ 19, 17, 18, 17 },
    '{ 19, 18, 18, 18 },
    '{ 19, 18, 18, 18 },
    '{ 19, 19, 19, 19 },
    '{ 19, 18, 18, 18 },
    '{ 19, 18, 18, 18 },
    '{ 19, 18, 18, 18 }
  };
  
  // internal signals
  enum { INIT, NEXT, GEN_NEXT, GEN, END, WAIT,
         ROTATE_LOAD, ROTATE_NEXT, ROTATE, 
         LEFT_NEXT, LEFT, RIGHT_NEXT, RIGHT,
         DOWN_NEXT, DOWN, CLEAR_PREP, CLEAR } state;
  reg [209:0] placed_mask;
  reg [199:0] placed_kind [2:0];
  reg [209:0] curr_mask;
  reg [2:0] curr_kind;
  wire [7:0] read_addr;
  
  // GEN/ROTATE/LEFT/RIGHT/DOWN
  reg [1:0] rotate_idx;
  reg [3:0] x_offset;
  reg [4:0] y_offset;
  
  // GEN/ROTATE
  reg [251:0] extended_offset_mask;
  wire [209:0] offset_mask;
  
  // ROTATE/LEFT/RIGHT/DOWN
  reg [1:0] next_rotate_idx;
  reg [3:0] next_x_offset;
  reg [4:0] next_y_offset;
  reg [209:0] next_mask;
  wire valid_x_min_offset;
  wire valid_x_max_offset;
  wire valid_y_max_offset;
  wire valid_offset;
  wire overlapped;
  
  // CLEAR
  reg [199:0] tmp_placed_mask;
  reg [4:0] clear_row;
  wire [209:0] clear_mask;
  
  assign kind = curr_mask[read_addr] ? curr_kind : { placed_kind[2][read_addr], placed_kind[1][read_addr], placed_kind[0][read_addr] };
  
  assign read_addr = (8'd19 - y) * 8'd10 + (8'd9 - x);
  
  assign valid_x_min_offset = min_x_offset[curr_kind][next_rotate_idx] <= next_x_offset;
  assign valid_x_max_offset = next_x_offset <= max_x_offset[curr_kind][next_rotate_idx];
  assign valid_y_max_offset = next_y_offset <= max_y_offset[curr_kind][next_rotate_idx];
  assign valid_offset = valid_x_min_offset & valid_x_max_offset & valid_y_max_offset;
  assign overlapped = |(placed_mask & next_mask);
  
  assign offset_mask = { extended_offset_mask[20*12+2 +: 10],
                         extended_offset_mask[19*12+2 +: 10], 
                         extended_offset_mask[18*12+2 +: 10],
                         extended_offset_mask[17*12+2 +: 10],
                         extended_offset_mask[16*12+2 +: 10],
                         extended_offset_mask[15*12+2 +: 10],
                         extended_offset_mask[14*12+2 +: 10],
                         extended_offset_mask[13*12+2 +: 10],
                         extended_offset_mask[12*12+2 +: 10],
                         extended_offset_mask[11*12+2 +: 10],
                         extended_offset_mask[10*12+2 +: 10],
                         extended_offset_mask[ 9*12+2 +: 10],
                         extended_offset_mask[ 8*12+2 +: 10],
                         extended_offset_mask[ 7*12+2 +: 10],
                         extended_offset_mask[ 6*12+2 +: 10],
                         extended_offset_mask[ 5*12+2 +: 10],
                         extended_offset_mask[ 4*12+2 +: 10],
                         extended_offset_mask[ 3*12+2 +: 10],
                         extended_offset_mask[ 2*12+2 +: 10],
                         extended_offset_mask[ 1*12+2 +: 10],
                         extended_offset_mask[ 0*12+2 +: 10] };
                         
  assign clear_mask = {210{1'b1}} << (8'd10 * clear_row);
  
  always @(posedge clk) begin
    if (~reset_n) begin
      state <= INIT;
    end 
    else case (state)
      INIT: begin
        placed_mask <= 0;
        placed_kind[2] <= 0;
        placed_kind[1] <= 0;
        placed_kind[0] <= 0;
        curr_mask <= 0;
        curr_kind <= 1;
        if (ctrl_valid) state <= NEXT;
      end
      NEXT: begin
        rotate_idx <= 0;
        x_offset <= 5;
        y_offset <= 0;
        extended_offset_mask <= ({ mask[curr_kind][0], {204{1'b0}} } << 5);
        state <= GEN_NEXT;
      end
      END: if (ctrl_valid) state <= INIT;
      GEN_NEXT: begin
        next_mask <= offset_mask;
        state <= GEN;
      end
      GEN: begin
        if (overlapped | |(placed_mask[209:200])) state <= END;
        else begin
          curr_mask <= next_mask;
          state <= WAIT;
        end
      end
      WAIT: begin
        if (ctrl_valid) begin
          case (ctrl)
            2'b11: state <= ROTATE_LOAD;
            2'b10: state <= LEFT_NEXT;
            2'b01: state <= DOWN_NEXT;
            2'b00: state <= RIGHT_NEXT;
          endcase
        end
      end
      ROTATE_LOAD: begin
        extended_offset_mask <= ({ mask[curr_kind][rotate_idx + 1], {204{1'b0}} } << x_offset) >> (12 * y_offset);
        state <= ROTATE_NEXT;
      end
      ROTATE_NEXT: begin
        next_rotate_idx <= rotate_idx + 1;
        next_x_offset <= x_offset;
        next_y_offset <= y_offset;
        next_mask <= offset_mask;
        state <= ROTATE;
      end
      ROTATE: begin
        if (~overlapped & valid_offset) begin
          curr_mask <= next_mask;
          rotate_idx <= next_rotate_idx;
        end
        state <= WAIT;
      end
      LEFT_NEXT: begin
        next_rotate_idx <= rotate_idx;
        next_x_offset <= x_offset + 1;
        next_mask <= (curr_mask << 1);
        state <= LEFT;
      end
      LEFT: begin
        if (~overlapped & valid_x_max_offset) begin
          curr_mask <= next_mask;
          x_offset <= next_x_offset;
        end
        state <= WAIT;
      end
      RIGHT_NEXT: begin
        next_rotate_idx <= rotate_idx;
        next_x_offset <= x_offset - 1;
        next_mask <= (curr_mask >> 1);
        state <= RIGHT;
      end
      RIGHT: begin
        if (~overlapped & valid_x_min_offset) begin
          curr_mask <= next_mask;
          x_offset <= next_x_offset;
        end
        state <= WAIT;
      end
      DOWN_NEXT: begin
        next_rotate_idx <= rotate_idx;
        next_y_offset <= y_offset + 1;
        next_mask <= (curr_mask >> 10);
        state <= DOWN;
      end
      DOWN: begin
        if (~overlapped & valid_y_max_offset) begin
          curr_mask <= next_mask;
          y_offset <= next_y_offset;
          state <= WAIT;
        end
        else begin
          placed_mask <= placed_mask | curr_mask;
          placed_kind[2] <= placed_kind[2] | (curr_mask[199:0] & {200{curr_kind[2]}});
          placed_kind[1] <= placed_kind[1] | (curr_mask[199:0] & {200{curr_kind[1]}});
          placed_kind[0] <= placed_kind[0] | (curr_mask[199:0] & {200{curr_kind[0]}});
          state <= CLEAR_PREP;
        end
      end
      CLEAR_PREP: begin
          tmp_placed_mask <= placed_mask;
          clear_row <= 0;
          state <= CLEAR;
      end
      CLEAR: begin
        if (&tmp_placed_mask[9:0]) begin
          placed_mask    <= (placed_mask    & ~clear_mask) | ((placed_mask    >> 10) & clear_mask);
          placed_kind[2] <= (placed_kind[2] & ~clear_mask) | ((placed_kind[2] >> 10) & clear_mask);
          placed_kind[1] <= (placed_kind[1] & ~clear_mask) | ((placed_kind[1] >> 10) & clear_mask);
          placed_kind[0] <= (placed_kind[0] & ~clear_mask) | ((placed_kind[0] >> 10) & clear_mask);
          state <= CLEAR_PREP;
        end
        else begin
          tmp_placed_mask <= (tmp_placed_mask >> 10);
          clear_row <= clear_row + 1;
          if (clear_row == 19) begin
            curr_kind <= (curr_kind == 7) ? 1 : (curr_kind + 1);
            state <= NEXT;
          end
        end
      end
    endcase
  end
endmodule

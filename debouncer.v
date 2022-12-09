`timescale 1ns / 1ps
module debouncer(
    input clk,
    input btn,
    output debounced_btn
);
    parameter PRESS_CLOCK_THR = 10000000; // 100ms
    parameter LONG_PRESS_THR = 50000000; // 500ms
    parameter CONTINUOUS_PRESS_THR = PRESS_CLOCK_THR; // 100ms
    
    localparam WAIT_PRESS = 0;
    localparam WAIT_LONG = 1;
    localparam AFTER_LONG = 2;
    
    reg [1:0] state = 0;
    reg [$clog2(LONG_PRESS_THR)-1:0] counter = 0;
    assign debounced_btn = ((state == WAIT_LONG || state == AFTER_LONG) && counter == 0);
    
    always @(posedge clk) begin
        if (~btn) begin
            state <= WAIT_PRESS;
            counter <= 0;
        end
        else case (state)
            WAIT_PRESS: begin
                if (counter == PRESS_CLOCK_THR - 1) begin
                    state <= WAIT_LONG;
                    counter <= 0;
                end
                else counter <= counter + 1;
            end
            WAIT_LONG: begin
                if (counter == LONG_PRESS_THR - 1) begin
                    state <= AFTER_LONG;
                    counter <= 0;
                end
                else counter <= counter + 1;
            end
            AFTER_LONG: begin
                if (counter == CONTINUOUS_PRESS_THR - 1) counter <= 0;
                else counter <= counter + 1;
            end
        endcase
    end
endmodule

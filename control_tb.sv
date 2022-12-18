`timescale 1ns / 1ps

module control_tb import enum_type::*;;

    reg sys_clk = 0;
    always #1 sys_clk <= ~sys_clk;

    reg  reset = 0;
    event reset_trigger;
    event reset_done_trigger;
    initial begin
        forever begin
            @ (reset_trigger);
            @ (negedge sys_clk);
            reset = 1;
            @ (negedge sys_clk);
            reset = 0;
            -> reset_done_trigger;
        end
    end

    reg [3:0] btn, sw;
    reg uart_rx;
    wire uart_tx;
    state_type state, control;

    control control_0(
        .clk(sys_clk),
        .reset_n(~reset),
        .usr_btn(btn),
        .usr_sw(sw),
        .uart_rx(uart_rx),
        .uart_tx(uart_tx),
        .state(state),
        .control(control)
    );

    initial begin
        #10 -> reset_trigger;
        @ (reset_done_trigger);
        $finish;
    end

endmodule

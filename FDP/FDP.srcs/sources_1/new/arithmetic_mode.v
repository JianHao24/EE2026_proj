`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11/06/2025 09:26:25 PM
// Design Name: 
// Module Name: arithmetic_mode
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


`timescale 1ns / 1ps

module arithmetic_module(
    // Clock inputs
    input clk_6p25MHz,
    input clk_1kHz,

    // Button inputs
    input btnC, btnU, btnD, btnL, btnR,

    // Expose flags for module control
    input reset,
    input is_arithmetic_mode,

    // Mouse inputs (for future compatibility)
    input [11:0] xpos,
    input [11:0] ypos,
    input use_mouse,
    input mouse_left,
    input mouse_middle,

    // OLED outputs
    input [12:0] one_pixel_index,
    input [12:0] two_pixel_index,
    output [15:0] one_oled_data,
    output [15:0] two_oled_data,

    // Status outputs
    output overflow_flag,
    output div_by_zero_flag
);


    
    // Cursor controller signals
    wire [1:0] cursor_row_keypad;
    wire [2:0] cursor_col_keypad;
    wire [1:0] cursor_row_operand;
    wire [1:0] cursor_col_operand;
    wire keypad_btn_pressed;
    wire [3:0] keypad_selected_value;
    wire operand_btn_pressed;
    wire [1:0] operand_selected_value;
    
    // Input system signals
    wire has_decimal;
    wire has_negative;
    wire [3:0] input_index;
    wire signed [31:0] fp_value;
    wire [31:0] bcd_value;
    wire input_complete;
    wire [3:0] decimal_pos;
    
    // Calculator engine signals
    wire signed [31:0] result;
    wire result_valid;
    wire overflow;
    wire div_by_zero;
    wire is_operand_mode;
    wire [1:0] current_operation;
    
    // Assign outputs
    assign overflow_flag = overflow;
    assign div_by_zero_flag = div_by_zero;

    arithmetic_cursor cursor_ctrl(
        .clk(clk_1kHz),
        .reset(reset || !is_arithmetic_mode),
        .btnC(is_arithmetic_mode ? btnC : 1'b0),
        .btnU(is_arithmetic_mode ? btnU : 1'b0),
        .btnD(is_arithmetic_mode ? btnD : 1'b0),
        .btnL(is_arithmetic_mode ? btnL : 1'b0),
        .btnR(is_arithmetic_mode ? btnR : 1'b0),
        .is_operand_mode(is_operand_mode),
        .cursor_row_keypad(cursor_row_keypad),
        .cursor_col_keypad(cursor_col_keypad),
        .cursor_row_operand(cursor_row_operand),
        .cursor_col_operand(cursor_col_operand),
        .keypad_btn_pressed(keypad_btn_pressed),
        .keypad_selected_value(keypad_selected_value),
        .operand_btn_pressed(operand_btn_pressed),
        .operand_selected_value(operand_selected_value)
    );


    bcd_to_fp_input_system #(
        .DIGIT_CAPACITY(8),
        .FIXED_FRAC_BITS(16)
    ) input_builder(
        .clk(clk_1kHz),
        .reset(reset || !is_arithmetic_mode),
        .keypad_btn_pressed(keypad_btn_pressed),
        .selected_keypad_value(keypad_selected_value),
        .is_active_mode(!is_operand_mode && is_arithmetic_mode),
        .enable_negative(1'b0),
        .enable_backspace(1'b1),
        .has_decimal(has_decimal),
        .has_negative(has_negative),
        .input_index(input_index),
        .fp_value(fp_value),
        .bcd_value(bcd_value),
        .input_complete(input_complete),
        .decimal_pos(decimal_pos)
    );


    basic_calculator_engine calc_engine(
        .clk(clk_1kHz),
        .rst(reset || !is_arithmetic_mode),
        .input_valid(input_complete),
        .input_val(fp_value),
        .op_valid(operand_btn_pressed),
        .op_sel(operand_selected_value),
        .result(result),
        .result_valid(result_valid),
        .overflow(overflow),
        .div_by_zero(div_by_zero),
        .is_operand_mode(is_operand_mode),
        .current_operation(current_operation)
    );


    arithmetic_display_selector display_selector(
        .clk(clk_6p25MHz),
        .pixel_index(one_pixel_index),
        .cursor_row_keypad(cursor_row_keypad),
        .cursor_col_keypad(cursor_col_keypad),
        .cursor_row_operand(cursor_row_operand),
        .cursor_col_operand(cursor_col_operand),
        .has_decimal(has_decimal),
        .is_operand_mode(is_operand_mode),
        .oled_data(one_oled_data)
    );


    arithmetic_text_selector text_selector(
        .clk(clk_6p25MHz),
        .pixel_index(two_pixel_index),
        .computed_result(result),
        .is_operand_mode(is_operand_mode),
        .bcd_value(bcd_value),
        .decimal_pos(decimal_pos),
        .input_index(input_index),
        .has_decimal(has_decimal),
        .oled_data(two_oled_data)
    );

endmodule

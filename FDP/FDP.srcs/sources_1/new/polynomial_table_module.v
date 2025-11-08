`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 22.03.2025 10:41:01
// Design Name: 
// Module Name: polynomial_table_module
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
/*
This module wraps around the polynomial table functionality, requiring only the
coefficients and is_table_mode to properly function/interface with the rest of the program.
*/


module polytable_mode(
    // Clocks
    input clk_6p25MHz,
    input clk_1kHz,
    input clk_100MHz,
    
    // Controls
    input btnC, btnU, btnD, btnL, btnR,
    input is_table_mode,

    // Coefficients
    input signed [31:0] coeff_a, coeff_b, coeff_c, coeff_d,

    // Display
    input [12:0] one_pixel_index, two_pixel_index,
    output [15:0] one_oled_data, two_oled_data,
    output is_table_input_mode_outgoing
);

    // Internal signals
    wire is_table_input_mode;
    assign is_table_input_mode_outgoing = is_table_input_mode;
    
    wire [1:0] cursor_row;
    wire [2:0] cursor_col;
    wire keypad_btn_pressed;
    wire [3:0] keypad_selected_value;
    wire signed [31:0] starting_x;
    
    // Input system signals
    wire has_decimal, has_negative;
    wire [3:0] input_index;
    wire signed [31:0] fp_value;
    wire [31:0] bcd_value;
    wire input_complete;
    wire [3:0] decimal_pos;
    
    // Display wires
    wire [15:0] keypad_oled_data, table_oled_data, input_oled_data;

    // Cursor controller
    polytable_select table_controller(
        .clk_100MHz(clk_100MHz),
        .clk(clk_1kHz),
        .btnC(btnC),
        .btnU(btnU),
        .btnD(btnD),
        .btnL(btnL),
        .btnR(btnR),
        .is_table_mode(is_table_mode),
        .input_complete(input_complete),
        .fp_input_value(fp_value),
        .is_table_input_mode(is_table_input_mode),
        .cursor_row(cursor_row),
        .cursor_col(cursor_col),
        .keypad_btn_pressed(keypad_btn_pressed),
        .keypad_selected_value(keypad_selected_value),
        .starting_x(starting_x)
    );

    // Input system for X value entry
    bcd_to_fp_input_system #(
        .DIGIT_CAPACITY(8),
        .FIXED_FRAC_BITS(16)
    ) input_builder_table (
        .clk(clk_1kHz),
        .reset(!is_table_input_mode || !is_table_mode),
        .keypad_btn_pressed(keypad_btn_pressed),
        .selected_keypad_value(keypad_selected_value),
        .is_active_mode(is_table_input_mode && is_table_mode),
        .enable_negative(1'b1),
        .enable_backspace(1'b0),
        .has_decimal(has_decimal),
        .has_negative(has_negative),
        .input_index(input_index),
        .fp_value(fp_value),
        .bcd_value(bcd_value),
        .input_complete(input_complete),
        .decimal_pos(decimal_pos)
    );
    
    // Display modules
    polytable_keypad_display keypad_display(
        .clk(clk_6p25MHz),
        .pixel_index(one_pixel_index),
        .cursor_row(cursor_row),
        .cursor_col(cursor_col),
        .has_decimal(has_decimal),
        .has_negative(has_negative),
        .input_index(input_index),
        .oled_data(keypad_oled_data)
    );

    polytable_display table_display(
        .clk(clk_6p25MHz),
        .pixel_index(one_pixel_index),
        .is_table_mode(is_table_mode && !is_table_input_mode),
        .starting_x(starting_x),
        .coeff_a(coeff_a),
        .coeff_b(coeff_b),
        .coeff_c(coeff_c),
        .coeff_d(coeff_d),
        .oled_data(table_oled_data)
    );

    coefficient_input_display input_display(
        .clk(clk_6p25MHz),
        .pixel_index(two_pixel_index),
        .bcd_value(bcd_value),
        .decimal_pos(decimal_pos),
        .input_index(input_index),
        .has_decimal(has_decimal),
        .has_negative(has_negative),
        .coeff_state(3'b111),
        .oled_data(input_oled_data)
    );

    // Output multiplexing
    polytable_keypad_render keypad(
        .is_table_mode(is_table_mode),
        .is_table_input_mode(is_table_input_mode),
        .keypad_oled_data(keypad_oled_data),
        .table_oled_data(table_oled_data),
        .oled_data(one_oled_data)
    );

    assign two_oled_data = is_table_input_mode ? input_oled_data : 16'b0;
    
endmodule

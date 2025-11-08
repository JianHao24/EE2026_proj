`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 
// Design Name: 
// Module Name: polynomial_display_selector
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: Display selector for polynomial mode - routes to keypad, coefficient,
//              or mode selection displays based on current state
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module polynomial_display_selector(
    input clk,
    input [12:0] pixel_index,
    input [1:0] cursor_row_keypad,
    input [2:0] cursor_col_keypad,
    input [1:0] cursor_row_coeff,
    input [1:0] cursor_col_coeff,
    input [1:0] cursor_row_mode,
    input [1:0] cursor_col_mode,
    input has_decimal,
    input waiting_coeff_selection,
    input waiting_mode_selection,
    input [2:0] current_coeff_index,
    output reg [15:0] oled_data
);
    
    // Display outputs from all modes
    wire [15:0] keypad_display_data;
    wire [15:0] coeff_display_data;
    wire [15:0] mode_display_data;
    
    // Instantiate keypad display
    polynomial_keypad_display keypad_inst(
        .clk(clk),
        .pixel_index(pixel_index),
        .cursor_row(cursor_row_keypad),
        .cursor_col(cursor_col_keypad),
        .has_decimal(has_decimal),
        .oled_data(keypad_display_data)
    );
    
    // Instantiate coefficient selection display
    polynomial_coeff_display coeff_inst(
        .clk(clk),
        .pixel_index(pixel_index),
        .cursor_row(cursor_row_coeff),
        .cursor_col(cursor_col_coeff),
        .current_coeff_index(current_coeff_index),
        .oled_data(coeff_display_data)
    );
    
    // Instantiate mode selection display
    polynomial_mode_display mode_inst(
        .clk(clk),
        .pixel_index(pixel_index),
        .cursor_row(cursor_row_mode),
        .cursor_col(cursor_col_mode),
        .oled_data(mode_display_data)
    );
    
    // Mode-based display selection with priority
    always @(*) begin
        if (waiting_mode_selection)
            oled_data = mode_display_data;      // Mode selection (f(x) or f'(x))
        else if (waiting_coeff_selection)
            oled_data = coeff_display_data;     // Coefficient selection mode
        else
            oled_data = keypad_display_data;    // Number input mode
    end
    
endmodule


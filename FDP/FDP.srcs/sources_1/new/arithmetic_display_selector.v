`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 06.11.2025 00:34:59
// Design Name: 
// Module Name: arithmetic_display_selector
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


module arithmetic_display_selector(
    input clk,
    input [12:0]pixel_index,
    input [1:0]cursor_row_keypad,
    input [2:0]cursor_col_keypad,
    input [1:0]cursor_row_operand,
    input [1:0]cursor_col_operand,
    input has_decimal,
    input is_operand_mode,
    output reg [15:0]oled_data
    );
    
    // Display outputs
    wire [15:0]keypad_display_data;
    wire [15:0]operand_display_data;
    
    // Instantiate keypad display module
    arithmetic_keypad_display keypad_inst(
        .clk(clk),
        .pixel_index(pixel_index),
        .cursor_row(cursor_row_keypad),
        .cursor_col(cursor_col_keypad),
        .has_decimal(has_decimal),
        .oled_data(keypad_display_data)
    );
    
    // Instantiate operand display module
    arithmetic_operand_display operand_inst(
        .clk(clk),
        .pixel_index(pixel_index),
        .cursor_row(cursor_row_operand),
        .cursor_col(cursor_col_operand),
        .oled_data(operand_display_data)
    );
    
    // Mode-based display selection
    always @(*) begin
        oled_data = is_operand_mode ? operand_display_data : keypad_display_data;
    end
    
endmodule

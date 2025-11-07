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

`timescale 1ns / 1ps

module arithmetic_display_selector(
    input clk,
    input [12:0]pixel_index,
    input [1:0]cursor_row_keypad,
    input [2:0]cursor_col_keypad,
    input [1:0]cursor_row_operand,
    input [1:0]cursor_col_operand,
    input [1:0]cursor_row_trig,
    input [1:0]cursor_col_trig,
    input has_decimal,
    input waiting_operand,
    input waiting_trig,
    output reg [15:0]oled_data
);
    
    // Display outputs from all three modes
    wire [15:0]keypad_display_data;
    wire [15:0]operand_display_data;
    wire [15:0]trig_display_data;
    
    // Instantiate keypad display (with split right side)
    arithmetic_keypad_display keypad_inst(
        .clk(clk),
        .pixel_index(pixel_index),
        .cursor_row(cursor_row_keypad),
        .cursor_col(cursor_col_keypad),
        .has_decimal(has_decimal),
        .oled_data(keypad_display_data)
    );
    
    // Instantiate operand display (existing - unchanged)
    arithmetic_operand_display operand_inst(
        .clk(clk),
        .pixel_index(pixel_index),
        .cursor_row(cursor_row_operand),
        .cursor_col(cursor_col_operand),
        .oled_data(operand_display_data)
    );
    
    // Instantiate trig display (new - mirrors operand)
    arithmetic_trig_display trig_inst(
        .clk(clk),
        .pixel_index(pixel_index),
        .cursor_row(cursor_row_trig),
        .cursor_col(cursor_col_trig),
        .oled_data(trig_display_data)
    );
    
    // Mode-based display selection with priority
    always @(*) begin
        if (waiting_trig)
            oled_data = trig_display_data;      // Trig selection mode
        else if (waiting_operand)
            oled_data = operand_display_data;   // Operation selection mode
        else
            oled_data = keypad_display_data;    // Number input mode
    end
    
endmodule

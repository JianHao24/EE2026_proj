`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 22.03.2025 10:46:46
// Design Name: 
// Module Name: polynomial_table_table_keypad_renderer
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
This module is concerned with choosing the output OLED for the first screen, where the user will either see the keypad or the polynomial table
*/
module polytable_keypad_render(
    input is_table_mode,
    input is_table_input_mode,
    input [15:0] keypad_oled_data,
    input [15:0] table_oled_data,
    output reg [15:0] oled_data
    );

    always @ (*) begin
        if (is_table_input_mode) begin
            oled_data <= keypad_oled_data;
        end
        else if (is_table_mode) begin
            oled_data <= table_oled_data;
        end
        else begin
            // Default to white
            oled_data <= 16'hFFFF;
        end
    end
endmodule

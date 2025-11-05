`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 24.10.2025 22:54:10
// Design Name: 
// Module Name: arithmetic_keypad_display
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


module arithmetic_keypad_display(
    input clk,
    input [12:0]pixel_index,
    input [1:0]cursor_row,
    input [2:0]cursor_col,
    input has_decimal,
    output reg [15:0]oled_data
    );

    // OLED dimensions
    parameter width = 96;
    parameter height = 64;

    // Extract pixel coordinates
    wire [6:0] x = pixel_index % width;
    wire [6:0] y = pixel_index / width;

    // Keypad layout constants
    parameter button_width = 24;
    parameter button_height = 16;
    parameter keypad_start_x = 0;
    parameter keypad_start_y = 0;
    parameter checkmark_x = 72;

    // Colors
    parameter white = 16'hFFFF;
    parameter black = 16'h0000;
    parameter red = 16'hF800;

    // Determine current button position
    wire [1:0] btn_row = y / button_height;
    wire [1:0] btn_col = x / button_width;
    
    // Boundary checks
    wire in_button_area = (x < checkmark_x) && (btn_row < 4 && btn_col < 3);
    wire in_checkmark_area = (x >= checkmark_x);
    
    // Relative positions within button
    reg [6:0] local_x;
    reg [6:0] local_y;

    // Selection and state logic
    wire selected_button = (in_button_area && btn_row == cursor_row && btn_col == cursor_col);
    wire selected_checkmark = (in_checkmark_area && cursor_col == 3'd3);
    wire decimal_button = (in_button_area && btn_row == 2'd3 && btn_col == 2'd1);
    wire disabled_decimal = (decimal_button && has_decimal);

    // Character rendering signals
    wire [15:0] char_pixel_data;
    wire char_pixel_active;
    reg [5:0] display_char;
    
    // Character sprite positions
    reg [6:0] char_start_x;
    reg [5:0] char_start_y;

    // Button character renderer instance
    char_renderer button_char_renderer(
        .clk(clk),
        .pixel_index(pixel_index),
        .char(display_char),
        .start_x(char_start_x),
        .start_y(char_start_y),
        .colour(selected_button ? white : black),
        .oled_data(char_pixel_data),
        .active_pixel(char_pixel_active)
    );

    always @ (*) begin
        if (in_button_area) begin
            // Map button position to character
            case({btn_row, btn_col})
                {2'd0, 2'd0}: display_char = 6'd7;  // 7
                {2'd0, 2'd1}: display_char = 6'd8;  // 8
                {2'd0, 2'd2}: display_char = 6'd9;  // 9
                {2'd1, 2'd0}: display_char = 6'd4;  // 4
                {2'd1, 2'd1}: display_char = 6'd5;  // 5
                {2'd1, 2'd2}: display_char = 6'd6;  // 6
                {2'd2, 2'd0}: display_char = 6'd1;  // 1
                {2'd2, 2'd1}: display_char = 6'd2;  // 2
                {2'd2, 2'd2}: display_char = 6'd3;  // 3
                {2'd3, 2'd0}: display_char = 6'd0;  // 0
                {2'd3, 2'd1}: display_char = 6'd14; // . (decimal point)
                {2'd3, 2'd2}: display_char = 6'd38; // X (backspace)
                default: display_char = 6'd32;      // space
            endcase

            // Calculate relative position within button
            local_x = x % button_width;
            local_y = y % button_height;

            // Draw button border
            if (local_x == 0 || local_x == button_width - 1 || 
                local_y == 0 || local_y == button_height - 1) begin
                oled_data = black;
            end
            else begin
                // Set background color based on selection state
                if (selected_button) begin
                    oled_data = disabled_decimal ? red : black;
                end
                else begin
                    oled_data = white;
                end

                // Center the character in the button
                char_start_x = (btn_col * button_width) + (button_width/2) - 4;
                char_start_y = (btn_row * button_height) + (button_height/2) - 6;

                // Overlay character if active
                if (char_pixel_active) begin
                    oled_data = selected_button ? white : black;
                end
            end
        end
        else if (in_checkmark_area) begin
            // Display equals sign for checkmark
            display_char = 6'd42;
            local_x = x - checkmark_x;

            // Draw border
            if (local_x == 0 || local_x == button_width - 1 || 
                y == 0 || y == height - 1) begin
                oled_data = black;
            end
            else begin
                // Set background color
                oled_data = selected_checkmark ? black : white;

                // Center equals sign vertically
                if (y >= 24 && y < 40) begin
                    char_start_x = checkmark_x + 8;
                    char_start_y = 24;

                    // Overlay character if active
                    if (char_pixel_active) begin
                        oled_data = selected_checkmark ? white : black;
                    end
                end
            end
        end
    end
endmodule
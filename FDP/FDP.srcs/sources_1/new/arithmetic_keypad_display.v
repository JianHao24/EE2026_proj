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
// Description: Updated - trig button now shows "T" instead of "f"
// 
// Dependencies: 
// 
// Revision:
// Revision 0.02 - Changed trig button label
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
    parameter keypad_end_x = 72;  // 3 columns of keypad
    
    // Right column split into upper and lower half
    parameter right_col_x = 72;
    parameter upper_button_end_y = 32;  // Upper half: rows 0-1
    parameter lower_button_start_y = 32; // Lower half: rows 2-3

    // Colors
    parameter white = 16'hFFFF;
    parameter black = 16'h0000;
    parameter red = 16'hF800;
    parameter blue = 16'h001F;
    parameter green = 16'h07E0;

    // Determine current area
    wire in_keypad = (x < keypad_end_x);
    wire in_right_upper = (x >= right_col_x) && (y < upper_button_end_y);
    wire in_right_lower = (x >= right_col_x) && (y >= lower_button_start_y);
    
    // Keypad button position (4 rows, 3 cols)
    wire [1:0] btn_row = y / button_height;
    wire [1:0] btn_col = x / button_width;
    
    // Right column position
    wire [1:0] right_section = y / (height / 2);  // 0 = upper, 1 = lower
    
    // Calculate local position within button
    reg [6:0] local_x;
    reg [6:0] local_y;
    
    // Selection logic
    wire selected_keypad = in_keypad && (btn_row == cursor_row) && (btn_col == cursor_col);
    wire selected_right = (cursor_col == 3) && 
                         ((in_right_upper && cursor_row < 2) || 
                          (in_right_lower && cursor_row >= 2));
    
    // Decimal button disable
    wire decimal_button = in_keypad && (btn_row == 2'd3) && (btn_col == 2'd1);
    wire disabled_decimal = (decimal_button && has_decimal);
    
    // Character rendering
    wire [15:0] char_pixel_data;
    wire char_pixel_active;
    reg [5:0] display_char;
    reg [6:0] char_start_x;
    reg [5:0] char_start_y;
    
    char_renderer button_char_renderer(
        .clk(clk),
        .pixel_index(pixel_index),
        .char(display_char),
        .start_x(char_start_x),
        .start_y(char_start_y),
        .colour(selected_keypad || selected_right ? white : black),
        .oled_data(char_pixel_data),
        .active_pixel(char_pixel_active)
    );

    always @(*) begin
        // Default values
        local_x = 0;
        local_y = 0;
        display_char = 6'd32; // space
        char_start_x = 0;
        char_start_y = 0;
        oled_data = white;
        
        if (in_keypad) begin
            // ===== KEYPAD AREA (LEFT 3 COLUMNS) =====
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
                {2'd3, 2'd1}: display_char = 6'd14; // .
                {2'd3, 2'd2}: display_char = 6'd38; // X (backspace)
                default: display_char = 6'd32;
            endcase
            
            local_x = x % button_width;
            local_y = y % button_height;
            
            // Draw border
            if (local_x == 0 || local_x == button_width - 1 || 
                local_y == 0 || local_y == button_height - 1) begin
                oled_data = black;
            end else begin
                oled_data = selected_keypad ? (disabled_decimal ? red : black) : white;
                
                // Center character
                char_start_x = (btn_col * button_width) + (button_width/2) - 4;
                char_start_y = (btn_row * button_height) + (button_height/2) - 6;
                
                if (char_pixel_active) begin
                    oled_data = char_pixel_data;
                end
            end
            
        end else if (in_right_upper) begin
            // ===== RIGHT UPPER BUTTON (Operations Toggle) =====
            display_char = 6'd42; // = (equals sign for "confirm and select operation")
            
            local_x = x - right_col_x;
            local_y = y;
            
            // Draw border
            if (local_x == 0 || local_x == button_width - 1 || 
                local_y == 0 || local_y == upper_button_end_y - 1) begin
                oled_data = black;
            end else begin
                oled_data = (selected_right && cursor_row < 2) ? blue : white;
                
                // Center character
                char_start_x = right_col_x + (button_width/2) - 4;
                char_start_y = (upper_button_end_y/2) - 6;
                
                if (char_pixel_active) begin
                    oled_data = char_pixel_data;
                end
            end
            
        end else if (in_right_lower) begin
            // ===== RIGHT LOWER BUTTON (Trig Toggle) =====
            // CHANGED: Now displays "T" instead of "f"
            display_char = 6'd29; // T (for Trig)
            
            local_x = x - right_col_x;
            local_y = y - lower_button_start_y;
            
            // Draw border
            if (local_x == 0 || local_x == button_width - 1 || 
                local_y == 0 || local_y == (height - lower_button_start_y - 1)) begin
                oled_data = black;
            end else begin
                oled_data = (selected_right && cursor_row >= 2) ? green : white;
                
                // Center character
                char_start_x = right_col_x + (button_width/2) - 4;
                char_start_y = lower_button_start_y + ((height - lower_button_start_y)/2) - 6;
                
                if (char_pixel_active) begin
                    oled_data = char_pixel_data;
                end
            end
        end
    end
endmodule
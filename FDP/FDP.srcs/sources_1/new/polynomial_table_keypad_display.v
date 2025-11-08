`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 20.03.2025 14:34:43
// Design Name: 
// Module Name: polynomial_table_keypad_display
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


module polytable_keypad_display(
    input clk,
    input [12:0] pixel_index,
    input [1:0] cursor_row,
    input [2:0] cursor_col,
    input has_decimal,
    input has_negative,
    input [3:0] input_index,
    output reg [15:0] oled_data,
    input is_dfx_mode
);

    // OLED dimensions
    parameter width = 96;
    parameter height = 64;

    // Extract pixel coordinates
    wire [6:0] x = pixel_index % width;
    wire [6:0] y = pixel_index / width;

    // Optimized keypad layout constants with spacing (MATCHING ARITHMETIC)
    parameter button_width = 22;
    parameter button_height = 14;
    parameter h_spacing = 2;
    parameter v_spacing = 2;
    parameter keypad_start_x = 2;
    parameter keypad_start_y = 1;
    parameter keypad_end_x = 74;
    
    // Right column split into upper and lower half
    parameter right_col_x = 74;
    parameter right_col_width = 22;
    parameter upper_button_end_y = 32;
    parameter lower_button_start_y = 32;

    // Colors - Blue theme with red accent for right buttons (MATCHING ARITHMETIC)
    parameter white = 16'hFFFF;
    parameter black = 16'h0000;
    parameter blue_bg = 16'h001F;
    parameter red_bg = 16'hF800;
    parameter spacing_color = 16'hFFFF;
    parameter red = 16'hF800;

    // Determine current area
    wire in_keypad = (x >= keypad_start_x && x < keypad_end_x && y >= keypad_start_y);
    wire in_right_upper = (x >= right_col_x) && (y < upper_button_end_y);
    wire in_right_lower = (x >= right_col_x) && (y >= lower_button_start_y);
    
    // Keypad button position with spacing (4 rows, 3 cols)
    wire [6:0] adjusted_x = x - keypad_start_x;
    wire [6:0] adjusted_y = y - keypad_start_y;
    wire [1:0] btn_row = adjusted_y / (button_height + v_spacing);
    wire [1:0] btn_col = adjusted_x / (button_width + h_spacing);
    
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
        .colour(selected_keypad || selected_right ? black : white),
        .oled_data(char_pixel_data),
        .active_pixel(char_pixel_active)
    );

    // String rendering for multi-character labels
    wire [15:0] str_pixel_data;
    wire str_pixel_active;
    reg [17:0] display_string;
    reg [6:0] str_start_x;
    reg [5:0] str_start_y;
    
    string_renderer string_renderer_inst(
        .clk(clk),
        .word({display_string, 30'h3FFFFFFF}),
        .start_x(str_start_x),
        .start_y(str_start_y),
        .pixel_index(pixel_index),
        .colour(selected_right ? black : white),
        .oled_data(str_pixel_data),
        .active_pixel(str_pixel_active)
    );

    always @(*) begin
        // Default values
        local_x = 0;
        local_y = 0;
        display_char = 6'd32;
        display_string = 18'd0;
        char_start_x = 0;
        char_start_y = 0;
        str_start_x = 0;
        str_start_y = 0;
        oled_data = white;
        
        if (in_keypad) begin
            // ===== KEYPAD AREA (LEFT 3 COLUMNS) =====
            // Layout: 1-2-3 / 4-5-6 / 7-8-9 / 0-.-X (MATCHING ARITHMETIC)
            case({btn_row, btn_col})
                {2'd0, 2'd0}: display_char = 6'd1;
                {2'd0, 2'd1}: display_char = 6'd2;
                {2'd0, 2'd2}: display_char = 6'd3;
                {2'd1, 2'd0}: display_char = 6'd4;
                {2'd1, 2'd1}: display_char = 6'd5;
                {2'd1, 2'd2}: display_char = 6'd6;
                {2'd2, 2'd0}: display_char = 6'd7;
                {2'd2, 2'd1}: display_char = 6'd8;
                {2'd2, 2'd2}: display_char = 6'd9;
                {2'd3, 2'd0}: display_char = 6'd0;
                {2'd3, 2'd1}: display_char = 6'd14; // .
                {2'd3, 2'd2}: display_char = 6'd38; // X (backspace)
                default: display_char = 6'd32;
            endcase
            
            local_x = adjusted_x % (button_width + h_spacing);
            local_y = adjusted_y % (button_height + v_spacing);
            
            // Check if we're in the spacing area or button area
            if (local_x >= button_width || local_y >= button_height) begin
                oled_data = spacing_color;
            end else begin
                // Draw border
                if (local_x == 0 || local_x == button_width - 1 || 
                    local_y == 0 || local_y == button_height - 1) begin
                    oled_data = black;
                end else begin
                    // Button background
                    if (selected_keypad) begin
                        oled_data = disabled_decimal ? red : white;
                    end else begin
                        oled_data = blue_bg;
                    end
                    
                    // Center character
                    char_start_x = keypad_start_x + (btn_col * (button_width + h_spacing)) + (button_width/2) - 4;
                    char_start_y = keypad_start_y + (btn_row * (button_height + v_spacing)) + (button_height/2) - 6;
                    
                    if (char_pixel_active) begin
                        oled_data = char_pixel_data;
                    end
                end
            end
            
        end else if (in_right_upper) begin
            // ===== RIGHT UPPER BUTTON (FX Mode) =====
            display_string = {6'd20, 6'd38, 6'd32}; // "FX" (F=20, X=38)
            
            local_x = x - right_col_x;
            local_y = y;
            
            // Draw border
            if (local_x == 0 || local_x == right_col_width - 1 || 
                local_y == 0 || local_y == upper_button_end_y - 1) begin
                oled_data = black;
            end else begin
                oled_data = (selected_right && cursor_row < 2) ? white : red_bg;
                
                // Center string
                str_start_x = right_col_x + (right_col_width/2) - 8;
                str_start_y = (upper_button_end_y/2) - 6;
                
                if (str_pixel_active) begin
                    oled_data = str_pixel_data;
                end
            end
            
        end else if (in_right_lower) begin
            // ===== RIGHT LOWER BUTTON (DFX Mode) =====
            display_string = {6'd18, 6'd20, 6'd38}; // "DFX" (D=18, F=20, X=38)
            
            local_x = x - right_col_x;
            local_y = y - lower_button_start_y;
            
            // Draw border
            if (local_x == 0 || local_x == right_col_width - 1 || 
                local_y == 0 || local_y == (height - lower_button_start_y - 1)) begin
                oled_data = black;
            end else begin
                oled_data = (selected_right && cursor_row >= 2) ? white : red_bg;
                
                // Center string
                str_start_x = right_col_x + (right_col_width/2) - 12;
                str_start_y = lower_button_start_y + ((height - lower_button_start_y)/2) - 6;
                
                if (str_pixel_active) begin
                    oled_data = str_pixel_data;
                end
            end
        end
    end
endmodule
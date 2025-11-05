`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 24.10.2025 22:56:11
// Design Name: 
// Module Name: arithmetic_operand_display
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


module arithmetic_operand_display(
    input clk,
    input [12:0]pixel_index,
    input [1:0]cursor_row,
    input [1:0]cursor_col,
    output reg [15:0]oled_data
    );
    // OLED dimensions
    parameter width = 96;
    parameter height = 64;
    
    // Extract pixel coordinates
    wire [6:0] x = pixel_index % width;
    wire [5:0] y = pixel_index / width;
    
    // Operand layout constants
    parameter button_width = 48;
    parameter button_height = 32;
    
    // Colors
    parameter white = 16'hFFFF;
    parameter black = 16'h0000;
    
    // Determine current button position
    wire [1:0] btn_row = y / button_height;
    wire [1:0] btn_col = x / button_width;
    wire in_button_area = (btn_row < 2 && btn_col < 2);
    
    // Relative positions within button
    reg [6:0] local_x;
    reg [5:0] local_y;
    
    // Selection logic
    wire selected_button = (in_button_area && btn_row == cursor_row && btn_col == cursor_col);
    
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
        // Default white background
        oled_data = white;
        
        if (in_button_area) begin
            // Map button position to operator character
            case({btn_row, btn_col})
                {2'd0, 2'd0}: display_char = 6'd10;  // + (plus)
                {2'd0, 2'd1}: display_char = 6'd11;  // - (minus)
                {2'd1, 2'd0}: display_char = 6'd12;  // × (multiply)
                {2'd1, 2'd1}: display_char = 6'd13;  // ÷ (divide)
                default: display_char = 6'd32;       // space
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
                oled_data = selected_button ? black : white;
                
                // Center the character in the button
                char_start_x = (btn_col * button_width) + (button_width/2) - 4;
                char_start_y = (btn_row * button_height) + (button_height/2) - 6;
                
                // Overlay character if active
                if (char_pixel_active) begin
                    oled_data = selected_button ? white : black;
                end
            end
        end
        
        // Draw grid dividers
        if (x == width/2 || y == height/2) begin
            oled_data = black;
        end
    end
endmodule

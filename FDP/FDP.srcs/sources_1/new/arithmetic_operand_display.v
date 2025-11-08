
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


`timescale 1ns / 1ps

module operator_keypad(
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

    // Original button layout: 2x2 grid (restored size)
    parameter button_width = 48;
    parameter button_height = 32;

    // Colors - Blue theme
    parameter white = 16'hFFFF;
    parameter black = 16'h0000;
    parameter blue_bg = 16'h001F;     // Blue background

    // Determine current button position
    wire [1:0] btn_row = y / button_height;
    wire [1:0] btn_col = x / button_width;
    
    // Boundary check
    wire in_button_area = (btn_row < 2) && (btn_col < 2);
    
    // Local position within button
    reg [6:0] local_x;
    reg [6:0] local_y;

    // Selection logic
    wire selected = in_button_area && (btn_row == cursor_row) && (btn_col == cursor_col);
    
    // Character rendering
    wire [15:0] char_pixel_data;
    wire char_pixel_active;
    reg [5:0] display_char;
    reg [6:0] char_start_x;
    reg [5:0] char_start_y;
    
    char_renderer char_renderer_inst(
        .clk(clk),
        .pixel_index(pixel_index),
        .char(display_char),
        .start_x(char_start_x),
        .start_y(char_start_y),
        .colour(selected ? black : white),  // Black text on white bg when selected
        .oled_data(char_pixel_data),
        .active_pixel(char_pixel_active)
    );

    always @(*) begin
        local_x = x % button_width;
        local_y = y % button_height;
        display_char = 6'd32; // space
        
        if (in_button_area) begin
            // Calculate centered position for character
            char_start_x = (btn_col * button_width) + (button_width / 2) - 4;
            char_start_y = (btn_row * button_height) + (button_height / 2) - 6;
            
            // Map button to operation
            case({btn_row, btn_col})
                4'b00_00: display_char = 6'd10; // + (addition - correct encoding)
                4'b00_01: display_char = 6'd11; // - (subtraction)
                4'b01_00: display_char = 6'd12; // * (multiplication)
                4'b01_01: display_char = 6'd13; // / (division)
                default: display_char = 6'd32;  // space
            endcase
            
            // Draw border
            if (local_x == 0 || local_x == button_width - 1 || 
                local_y == 0 || local_y == button_height - 1) begin
                oled_data = black;
            end else begin
                // White background if selected, blue otherwise
                oled_data = selected ? white : blue_bg;
                
                // Overlay character if active
                if (char_pixel_active) begin
                    oled_data = char_pixel_data;  // Black text when selected, white when not
                end
            end
        end else begin
            oled_data = blue_bg;  // Blue background outside buttons
        end
    end
endmodule
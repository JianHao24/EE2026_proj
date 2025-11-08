`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 
// Design Name: 
// Module Name: polynomial_mode_display
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: Display for mode selection - shows f(x) and f'(x) options
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module polynomial_mode_display(
    input clk,
    input [12:0] pixel_index,
    input [1:0] cursor_row,
    input [1:0] cursor_col,
    output reg [15:0] oled_data
);

    // OLED dimensions
    parameter width = 96;
    parameter height = 64;

    // Extract pixel coordinates
    wire [6:0] x = pixel_index % width;
    wire [5:0] y = pixel_index / width;

    // Button layout constants
    parameter button_width = 40;
    parameter button_height = 24;
    parameter start_x = 8;
    parameter start_y = 20;
    
    // Colors
    parameter white = 16'hFFFF;
    parameter black = 16'h0000;
    parameter blue = 16'h001F;

    // Button positions
    wire [1:0] btn_col = (x - start_x) / button_width;
    
    wire in_display_area = (x >= start_x) && (x < start_x + 2*button_width) && 
                           (y >= start_y) && (y < start_y + button_height);
    
    wire selected_button = in_display_area && (cursor_row == 0) && (btn_col == cursor_col);
    
    // Character rendering
    wire [15:0] char_pixel_data;
    wire char_pixel_active;
    reg [47:0] label_string;  // 8 characters max
    
    string_renderer_optimized label_renderer(
        .clk(clk),
        .word(label_string),
        .start_x(start_x + btn_col * button_width + 4),
        .start_y(start_y + 8),
        .pixel_index(pixel_index),
        .colour(selected_button ? white : black),
        .oled_data(char_pixel_data),
        .active_pixel(char_pixel_active)
    );

    always @(*) begin
        // Default values
        oled_data = white;
        label_string = 48'hFFFFFFFFFFFF;
        
        if (in_display_area) begin
            // Determine button label
            case(btn_col)
                2'd0: label_string = {6'd6, 6'd40, 6'd33, 6'd41, 6'd32, 6'd32, 6'd32, 6'd32}; // "f(x)"
                2'd1: label_string = {6'd6, 6'd27, 6'd40, 6'd33, 6'd41, 6'd32, 6'd32, 6'd32}; // "f'(x)"
                default: label_string = 48'hFFFFFFFFFFFF;
            endcase
            
            // Draw border
            if ((x - start_x - btn_col * button_width) == 0 || 
                (x - start_x - btn_col * button_width) == button_width - 1 || 
                (y - start_y) == 0 || 
                (y - start_y) == button_height - 1) begin
                oled_data = black;
            end else begin
                // Button background
                if (selected_button) begin
                    oled_data = blue;
                end else begin
                    oled_data = white;
                end
                
                // Render label
                if (char_pixel_active) begin
                    oled_data = char_pixel_data;
                end
            end
        end
    end
endmodule


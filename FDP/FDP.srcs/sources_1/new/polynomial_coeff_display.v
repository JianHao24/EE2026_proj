`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 
// Design Name: 
// Module Name: polynomial_coeff_display
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: Display for coefficient selection - shows a0, a1, a2, a3, a4, and x
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module polynomial_coeff_display(
    input clk,
    input [12:0] pixel_index,
    input [1:0] cursor_row,
    input [1:0] cursor_col,
    input [2:0] current_coeff_index,
    output reg [15:0] oled_data
);

    // OLED dimensions
    parameter width = 96;
    parameter height = 64;

    // Extract pixel coordinates
    wire [6:0] x = pixel_index % width;
    wire [6:0] y = pixel_index / width;

    // Button layout constants
    parameter button_width = 32;
    parameter button_height = 20;
    parameter start_x = 8;
    parameter start_y = 12;
    
    // Colors
    parameter white = 16'hFFFF;
    parameter black = 16'h0000;
    parameter blue = 16'h001F;
    parameter green = 16'h07E0;

    // Button positions
    wire [1:0] btn_row = (y - start_y) / button_height;
    wire [1:0] btn_col = (x - start_x) / button_width;
    
    wire in_display_area = (x >= start_x) && (x < start_x + 3*button_width) && 
                           (y >= start_y) && (y < start_y + 2*button_height);
    
    wire selected_button = in_display_area && (btn_row == cursor_row) && (btn_col == cursor_col);
    wire current_button = in_display_area && 
                          ((btn_row == 0 && btn_col == 0 && current_coeff_index == 0) ||
                           (btn_row == 0 && btn_col == 1 && current_coeff_index == 1) ||
                           (btn_row == 0 && btn_col == 2 && current_coeff_index == 2) ||
                           (btn_row == 1 && btn_col == 0 && current_coeff_index == 3) ||
                           (btn_row == 1 && btn_col == 1 && current_coeff_index == 4) ||
                           (btn_row == 1 && btn_col == 2 && current_coeff_index == 5));
    
    // Character rendering
    wire [15:0] char_pixel_data;
    wire char_pixel_active;
    reg [5:0] display_char;
    reg [6:0] char_start_x;
    reg [5:0] char_start_y;
    reg [47:0] label_string;  // 8 characters max
    
    string_renderer_optimized label_renderer(
        .clk(clk),
        .word(label_string),
        .start_x(char_start_x),
        .start_y(char_start_y),
        .pixel_index(pixel_index),
        .colour(selected_button ? white : black),
        .oled_data(char_pixel_data),
        .active_pixel(char_pixel_active)
    );

    always @(*) begin
        // Default values
        display_char = 6'd32;
        char_start_x = 0;
        char_start_y = 0;
        oled_data = white;
        label_string = 48'hFFFFFFFFFFFF;
        
        if (in_display_area) begin
            // Determine button label
            case({btn_row, btn_col})
                {2'd0, 2'd0}: label_string = {6'd10, 6'd0, 6'd32, 6'd32, 6'd32, 6'd32, 6'd32, 6'd32}; // "a0"
                {2'd0, 2'd1}: label_string = {6'd10, 6'd1, 6'd32, 6'd32, 6'd32, 6'd32, 6'd32, 6'd32}; // "a1"
                {2'd0, 2'd2}: label_string = {6'd10, 6'd2, 6'd32, 6'd32, 6'd32, 6'd32, 6'd32, 6'd32}; // "a2"
                {2'd1, 2'd0}: label_string = {6'd10, 6'd3, 6'd32, 6'd32, 6'd32, 6'd32, 6'd32, 6'd32}; // "a3"
                {2'd1, 2'd1}: label_string = {6'd10, 6'd4, 6'd32, 6'd32, 6'd32, 6'd32, 6'd32, 6'd32}; // "a4"
                {2'd1, 2'd2}: label_string = {6'd33, 6'd32, 6'd32, 6'd32, 6'd32, 6'd32, 6'd32, 6'd32}; // "x"
                default: label_string = 48'hFFFFFFFFFFFF;
            endcase
            
            char_start_x = start_x + btn_col * button_width + 8;
            char_start_y = start_y + btn_row * button_height + 6;
            
            // Draw border
            if ((x - start_x - btn_col * button_width) == 0 || 
                (x - start_x - btn_col * button_width) == button_width - 1 || 
                (y - start_y - btn_row * button_height) == 0 || 
                (y - start_y - btn_row * button_height) == button_height - 1) begin
                oled_data = black;
            end else begin
                // Button background
                if (selected_button) begin
                    oled_data = blue;
                end else if (current_button) begin
                    oled_data = green;
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


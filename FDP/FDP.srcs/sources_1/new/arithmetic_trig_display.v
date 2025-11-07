`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11/07/2025 10:38:52 PM
// Design Name: 
// Module Name: arithmetic_trig_display
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: Updated to show "SIN", "COS", "TAN" labels
// 
// Dependencies: 
// 
// Revision:
// Revision 0.02 - Added text labels
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module arithmetic_trig_display(
    input clk,
    input [12:0]pixel_index,
    input [1:0]cursor_row,
    input [1:0]cursor_col,
    output reg [15:0]oled_data
);

    // OLED dimensions (mirrors operand display layout)
    parameter width = 96;
    parameter height = 64;

    // Extract pixel coordinates
    wire [6:0] x = pixel_index % width;
    wire [6:0] y = pixel_index / width;

    // Button layout: 2x2 grid
    // Row 0: SIN  COS
    // Row 1: TAN  (empty)
    parameter button_width = 48;
    parameter button_height = 32;

    // Colors
    parameter white = 16'hFFFF;
    parameter black = 16'h0000;
    parameter green = 16'h07E0;

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
    
    // Character rendering for multi-character strings
    wire [15:0] str_pixel_data;
    wire str_pixel_active;
    reg [17:0] display_string;  // 3 chars x 6 bits
    reg [6:0] str_start_x;
    reg [5:0] str_start_y;
    
    string_renderer_optimized string_renderer_inst(
        .clk(clk),
        .word({display_string, 30'h3FFFFFFF}),  // Pad to 48 bits with spaces
        .start_x(str_start_x),
        .start_y(str_start_y),
        .pixel_index(pixel_index),
        .colour(selected ? white : black),
        .oled_data(str_pixel_data),
        .active_pixel(str_pixel_active)
    );

    always @(*) begin
        local_x = x % button_width;
        local_y = y % button_height;
        display_string = 18'd0;
        
        if (in_button_area) begin
            // Calculate centered position for text (3 characters = 24 pixels wide)
            // Each char is 8 pixels wide, so 3 chars = 24 pixels
            // Center in 48-pixel button: (48-24)/2 = 12 pixel offset
            str_start_x = (btn_col * button_width) + (button_width / 2) - 12;
            str_start_y = (btn_row * button_height) + (button_height / 2) - 6;
            
            // Map button to trig function label
            // Character encoding: A=10, C=12, I=18, N=23, O=24, S=28, T=29
            case({btn_row, btn_col})
                4'b00_00: display_string = {6'd28, 6'd18, 6'd23};  // "SIN"
                4'b00_01: display_string = {6'd12, 6'd24, 6'd28};  // "COS"
                4'b01_00: display_string = {6'd29, 6'd10, 6'd23};  // "TAN"
                4'b01_01: display_string = {6'd63, 6'd63, 6'd63};  // Empty (all spaces)
                default: display_string = {6'd63, 6'd63, 6'd63};
            endcase
            
            // Draw border
            if (local_x == 0 || local_x == button_width - 1 || 
                local_y == 0 || local_y == button_height - 1) begin
                oled_data = black;
            end else begin
                // Green background for trig functions
                oled_data = selected ? green : white;
                
                // Overlay string if active
                if (str_pixel_active) begin
                    oled_data = str_pixel_data;
                end
            end
        end else begin
            oled_data = white;
        end
    end
endmodule
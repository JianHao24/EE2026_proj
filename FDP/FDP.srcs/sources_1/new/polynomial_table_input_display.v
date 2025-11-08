`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 22.03.2025 09:59:26
// Design Name: 
// Module Name: polynomial_table_input_display
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


module polynomial_table_input_display(
    input clk,
    input [12:0] pixel_index,
    input is_table_input_mode,

    // from input_builder,
    input [31:0] bcd_value,
    input has_decimal,
    input has_negative,
    input [3:0] input_index,
    input [3:0] decimal_pos,

    output reg [15:0] oled_data
    );

    // OLED dimensions
    parameter WIDTH = 96;
    parameter HEIGHT = 64;
    
    // Extract pixel coordinates
    wire [6:0] x = pixel_index % WIDTH;
    wire [6:0] y = pixel_index / WIDTH;
    
    // Display positioning
    parameter TITLE_Y = 20;
    parameter VALUE_Y = 40;
    
    // Colors
    parameter WHITE = 16'hFFFF;
    parameter BLACK = 16'h0000;
    
    // String renderers for title and value
    reg [47:0] title_text;
    reg [47:0] value_text;
    
    wire [15:0] title_string_data;
    wire title_active;
    wire [15:0] value_string_data;
    wire value_active;
    
    // String renderer for "INPUT:" title
    string_renderer title_renderer(
        .clk(clk),
        .word(title_text),
        .start_x(24), // Center horizontally
        .start_y(TITLE_Y),
        .pixel_index(pixel_index),
        .colour(BLACK),
        .oled_data(title_string_data),
        .active_pixel(title_active)
    );
    
    // String renderer for value display
    string_renderer value_renderer(
        .clk(clk),
        .word(value_text),
        .start_x(24), // Center horizontally
        .start_y(VALUE_Y),
        .pixel_index(pixel_index),
        .colour(BLACK),
        .oled_data(value_string_data),
        .active_pixel(value_active)
    );

    // Function to convert BCD digits to character codes
    function [47:0] bcd_to_string(
        input [31:0] bcd_val,
        input has_neg,
        input has_dec,
        input [3:0] dec_pos,
        input [3:0] inp_idx
    );
        reg [5:0] char_codes[0:7];
        integer i; 
        integer char_idx;
        begin
            // Initialize all character positions to space
            for (i = 0; i < 8; i = i + 1) begin
                char_codes[i] = 6'b111111; // Nonsense for blanks
            end
            
            char_idx = 0;
            
            // Add negative sign if present
            if (has_neg) begin
                char_codes[char_idx] = 6'b001011; // Negative sign (11)
                char_idx = char_idx + 1;
            end
            
            // Process each BCD digit
            for (i = 0; i < inp_idx; i = i + 1) begin
                if (char_idx < 8) begin
                    // Add decimal point if needed
                    if (has_dec && i == dec_pos+1) begin
                        char_codes[char_idx] = 6'b001110; // Decimal point (14)
                        char_idx = char_idx + 1;
                    end
                    
                    // Only add the digit if we have space
                    if (char_idx < 8) begin
                        // Extract the BCD digit and convert to character code
                        // Each digit is 4 bits in the BCD value
                        // This is part-select syntax! I.e. go to the correct place and take the 4 bits from that position
                        char_codes[char_idx] = {2'b00, bcd_val[(4 * (inp_idx - i - 1)) +: 4]};
                        char_idx = char_idx + 1;
                    end
                end
            end
            
            // Add decimal point at the end if needed
            if (has_dec && dec_pos == inp_idx && char_idx < 8) begin
                char_codes[char_idx] = 6'b001110; // Decimal point (14)
            end
            
            // Pack characters into 48-bit output
            bcd_to_string = {
                char_codes[0], char_codes[1], char_codes[2], char_codes[3],
                char_codes[4], char_codes[5], char_codes[6], char_codes[7]
            };
        end
    endfunction

    always @ (posedge clk) begin
        // "INPUT" title
//        title_text[0] = 6'b010111;
//        title_text[1] = 6'b011100;
//        title_text[2] = 6'b011110;
//        title_text[3] = 6'b100100;
//        title_text[4] = 6'b100011; 
            
        title_text = {  
            6'b010111, // I
            6'b011100, // N
            6'b011110, // P
            6'b100100, // U
            6'b100011, // T
            6'b111111, // " "
            6'b100110,  // X
            6'b111111 // " "
        };

        value_text = bcd_to_string(
            bcd_value, has_negative, has_decimal, decimal_pos, input_index
        );
    end

    // Display logic
    always @(posedge clk) begin
        if (is_table_input_mode) begin
            // Default white background
            oled_data = WHITE;
            
            // Display title and value using string renderers
            if (title_active) begin
                oled_data = title_string_data;
            end
            else if (value_active) begin
                oled_data = value_string_data;
            end
            
            if (x == 0 || x == WIDTH-1 || y == 0 || y == HEIGHT-1) begin
                oled_data = BLACK;
            end
        end
        else begin
            oled_data = BLACK;
        end
    end
    


endmodule

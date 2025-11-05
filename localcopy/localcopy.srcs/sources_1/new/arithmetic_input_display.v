`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 24.10.2025 23:00:09
// Design Name: 
// Module Name: arithmetic_input_display
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


module arithmetic_input_display(
    input clk,
    input [12:0] pixel_index,
    input [31:0] bcd_value,
    input [3:0] decimal_pos,
    input [3:0] input_index,
    input has_decimal,
    output reg [15:0] oled_data
);
    // OLED dimensions
    parameter width = 96;
    parameter height = 64;

    // Extract pixel coordinates
    wire [6:0] x = pixel_index % width;
    wire [5:0] y = pixel_index / width;
    
    // Colors
    parameter white = 16'hFFFF;
    parameter black = 16'h0000;
    
    // Display constants
    parameter text_start_x = 8;
    parameter text_start_y = 24;
    
    // Extract individual BCD digits
    wire [3:0] bcd_digits[0:7];
    assign bcd_digits[0] = bcd_value[3:0];
    assign bcd_digits[1] = bcd_value[7:4];
    assign bcd_digits[2] = bcd_value[11:8];
    assign bcd_digits[3] = bcd_value[15:12];
    assign bcd_digits[4] = bcd_value[19:16];
    assign bcd_digits[5] = bcd_value[23:20];
    assign bcd_digits[6] = bcd_value[27:24];
    assign bcd_digits[7] = bcd_value[31:28];
    
    // Character storage for the string to display
    reg [47:0] display_string = 48'hFFFFFFFFFFFF; // All spaces initially
    
    // Change detection registers
    reg [3:0] last_input_index = 0;
    reg last_has_decimal = 0;
    reg [3:0] last_decimal_pos = 0;
    reg [31:0] last_bcd_value = 0;
    
    // State machine
    reg [2:0] current_state = 0;
    parameter idle = 0;
    parameter start_update = 1;
    parameter process_digit = 2;
    parameter render = 3;
    
    // Processing variables
    reg [3:0] char_index = 0;     
    reg [3:0] digit_index = 0;     

    // String renderer output
    wire [15:0] str_pixel_data;
    wire str_pixel_active;
    
    // String renderer instance
    string_renderer_optimized string_renderer(
        .clk(clk),
        .word(display_string),
        .start_x(text_start_x),
        .start_y(text_start_y),
        .pixel_index(pixel_index),
        .colour(black),
        .oled_data(str_pixel_data),
        .active_pixel(str_pixel_active)
    );
    
    // Cursor variables
    reg [6:0] cursor_pos_x;
    wire cursor_is_active = (x >= cursor_pos_x && x < cursor_pos_x + 8 && 
                             y >= text_start_y + 10 && y < text_start_y + 12);
    reg [3:0] blink_counter = 0;
    reg cursor_show = 1;
    
    // State machine to update the display string
    always @ (posedge clk) begin
        // Update cursor position
        cursor_pos_x <= text_start_x + input_index * 8;
        
        // Blink cursor
        blink_counter <= blink_counter + 1;
        if (blink_counter == 15) begin
            cursor_show <= ~cursor_show;
            blink_counter <= 0;
        end
        
        // Check if any inputs have changed
        if (input_index != last_input_index || has_decimal != last_has_decimal || 
            decimal_pos != last_decimal_pos || bcd_value != last_bcd_value) begin
            current_state <= start_update;
            last_input_index <= input_index;
            last_has_decimal <= has_decimal;
            last_decimal_pos <= last_decimal_pos;
            last_bcd_value <= bcd_value;
        end
        
        // State machine
        case (current_state)
            idle: begin
                // Wait for changes
            end
            
            start_update: begin
                // Reset processing variables
                char_index <= 0;
                digit_index <= 0;
                display_string <= 48'hFFFFFFFFFFFF; // All spaces
                
                // Handle special case of empty input
                if (input_index == 0) begin
                    current_state <= render;
                end
                else begin
                    current_state <= process_digit;
                end
            end
            
            process_digit: begin
                if (char_index < input_index && char_index < 8) begin
                    if (has_decimal && char_index == decimal_pos) begin
                        // Insert decimal point at this position
                        display_string[47 - char_index*6 -: 6] <= 6'd14; // Decimal point
                        char_index <= char_index + 1;
                    end
                    else begin
                        // Insert digit from BCD value
                        display_string[47 - char_index*6 -: 6] <= bcd_digits[digit_index];
                        char_index <= char_index + 1;
                        digit_index <= digit_index + 1;
                    end
                end
                else begin
                    // Finished processing all positions
                    current_state <= render;
                end
            end
            
            render: begin
                current_state <= idle;
            end
        endcase
    end
    
    // Main rendering logic
    always @(*) begin
        // Default to white background
        oled_data = white;
        
        // Render string
        if (str_pixel_active) begin
            oled_data = str_pixel_data;
        end
        
        // Render blinking cursor
        if (cursor_is_active && cursor_show) begin
            oled_data = black;
        end
    end
endmodule

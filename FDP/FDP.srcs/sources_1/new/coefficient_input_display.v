`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 08.04.2025 14:07:06
// Design Name: 
// Module Name: coefficient_input_display
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

/*
Structure/style of this code largely follows that of integral_input_display
only with more Input labels.
*/
module coefficient_input_display(
    input clk,
    input [12:0] pixel_index,
    input [31:0] bcd_value,
    input [3:0] decimal_pos,
    input [3:0] input_index,
    input has_decimal,
    input has_negative,
    input [2:0] coeff_state, // Which coefficient we're entering (0=a, 1=b, 2=c, 3=d)
    output reg [15:0] oled_data
    );

    // OLED dimensions
    parameter WIDTH = 96;
    parameter HEIGHT = 64;

    // Extract pixel coordinates
    wire [6:0] x = pixel_index % WIDTH;
    wire [5:0] y = pixel_index / WIDTH;
    
    // Colors
    parameter WHITE = 16'hFFFF;
    parameter BLACK = 16'h0000;
    parameter BLUE = 16'h001F;
    parameter GREEN = 16'h07E0;
    
    // Display constants
    parameter TEXT_START_X = 8;
    parameter TEXT_START_Y = 24;
    parameter LABEL_Y = 8;
    
    // Extract individual BCD digits
    wire [3:0] digits[0:7];
    assign digits[0] = bcd_value[3:0];
    assign digits[1] = bcd_value[7:4];
    assign digits[2] = bcd_value[11:8];
    assign digits[3] = bcd_value[15:12];
    assign digits[4] = bcd_value[19:16];
    assign digits[5] = bcd_value[23:20];
    assign digits[6] = bcd_value[27:24];
    assign digits[7] = bcd_value[31:28];
    
    // Character storage for the string to display
    reg [47:0] display_string = 48'hFFFFFFFFFFFF; // All spaces initially
    
    // Strings for labels
    reg [47:0] label_a = {6'd23, 6'd28, 6'd30, 6'd36, 6'd35, 6'd32, 6'd15, 6'd32}; // "INPUT A"
    reg [47:0] label_b = {6'd23, 6'd28, 6'd30, 6'd36, 6'd35, 6'd32, 6'd16, 6'd32}; // "INPUT B"
    reg [47:0] label_c = {6'd23, 6'd28, 6'd30, 6'd36, 6'd35, 6'd32, 6'd17, 6'd32}; // "INPUT C"
    reg [47:0] label_d = {6'd23, 6'd28, 6'd30, 6'd36, 6'd35, 6'd32, 6'd18, 6'd32}; // "INPUT D"
    reg [47:0] label_x = {6'd23, 6'd28, 6'd30, 6'd36, 6'd35, 6'd32, 6'd38, 6'd32}; // "INPUT X"
    reg [47:0] current_label;
    
    // Change detection
    reg [3:0] prev_input_index = 0;
    reg prev_has_decimal = 0;
    reg prev_has_negative = 0;
    reg [3:0] prev_decimal_pos = 0;
    reg [31:0] prev_bcd_value = 0;
    
    // State machine
    reg [2:0] state = 0;
    parameter IDLE = 0;
    parameter START_UPDATE = 1;
    parameter PROCESS_DIGIT = 2;
    parameter RENDER = 3;
    
    // Processing variables
    reg [3:0] i = 0;     
    reg [3:0] bcd_pos = 0;     

    // String renderer outputs
    wire [15:0] string_data;
    wire string_active;
    wire [15:0] label_data;
    wire label_active;
    
    // Input value renderer
    string_renderer_optimized renderer(
        .clk(clk),
        .word(display_string),
        .start_x(TEXT_START_X),
        .start_y(TEXT_START_Y),
        .pixel_index(pixel_index),
        .colour(BLACK),
        .oled_data(string_data),
        .active_pixel(string_active)
    );
    
    // Label renderer
    string_renderer_optimized label_renderer(
        .clk(clk),
        .word(current_label),
        .start_x(TEXT_START_X),
        .start_y(LABEL_Y),
        .pixel_index(pixel_index),
        .colour(GREEN),  // Use green for the label
        .oled_data(label_data),
        .active_pixel(label_active)
    );
    
    // Cursor variables
    reg [6:0] cursor_x;
    wire cursor_active = (x >= cursor_x && x < cursor_x + 8 && 
                         y >= TEXT_START_Y + 10 && y < TEXT_START_Y + 12);
    reg [3:0] cursor_blink_counter = 0;
    reg cursor_visible = 1;
    
    // Update label based on coeff_state
    always @(*) begin
        case (coeff_state)
            2'b00: current_label = label_a;
            2'b01: current_label = label_b;
            2'b10: current_label = label_c;
            2'b11: current_label = label_d;
            default: current_label = label_x;
        endcase
    end
    
    // State machine to update the display string
    always @(posedge clk) begin
        // Update cursor position
        cursor_x <= TEXT_START_X + input_index * 8;
        
        // Blink cursor
        cursor_blink_counter <= cursor_blink_counter + 1;
        if (cursor_blink_counter == 15) begin
            cursor_visible <= ~cursor_visible;
            cursor_blink_counter <= 0;
        end
        
        // Check if any inputs have changed
        if (input_index != prev_input_index || 
            has_decimal != prev_has_decimal || 
            has_negative != prev_has_negative ||
            decimal_pos != prev_decimal_pos || 
            bcd_value != prev_bcd_value) begin
            state <= START_UPDATE;
            prev_input_index <= input_index;
            prev_has_decimal <= has_decimal;
            prev_has_negative <= has_negative;
            prev_decimal_pos <= decimal_pos;
            prev_bcd_value <= bcd_value;
        end
        
        // State machine
        case (state)
            IDLE: begin
                // Wait for changes
            end
            
            START_UPDATE: begin
                // Reset processing variables
                i <= 0;
                bcd_pos <= 0;
                display_string <= 48'hFFFFFFFFFFFF; // All spaces
                
                // Handle special case of empty input
                if (input_index == 0) begin
                    state <= RENDER;
                end
                else begin
                    // If there's a negative sign, we need to handle it first
                    if (has_negative) begin
                        display_string[47:42] <= 6'd11; // Negative sign
                        i <= 1; // Start processing from position 1
                    end
                    state <= PROCESS_DIGIT;
                end
            end
            
            PROCESS_DIGIT: begin
                if (i < input_index && i < 8) begin
                    if (has_decimal && i == decimal_pos) begin
                        // Insert decimal point at this position
                        display_string[47 - i*6 -: 6] <= 6'd14; // Decimal point
                        i <= i + 1;
                    end
                    else begin
                        // Insert digit from BCD value
                        display_string[47 - i*6 -: 6] <= digits[bcd_pos];
                        i <= i + 1;
                        bcd_pos <= bcd_pos + 1;
                    end
                end
                else begin
                    // Finished processing all positions
                    state <= RENDER;
                end
            end
            
            RENDER: begin
                state <= IDLE;
            end
        endcase
    end

    // Main rendering logic
    always @(*) begin
        // Default to white background
        oled_data = WHITE;
        
        // Polynomial equation display at the top
        // if (y <= 6 && x >= 5 && x <= 90) begin
            // // Draw the polynomial equation: ax³ + bx² + cx + d
            // // Highlighting the current coefficient
            
            // // 'a' coefficient (position 10-15)
            // if (x >= 10 && x <= 15) begin
                // if (coeff_state == 0)
                    // oled_data = GREEN;  // Highlight if this is the current coefficient
            // end
            
            // // 'x³' (position 16-22)
            // if (x >= 16 && x <= 22) begin
                // oled_data = BLACK;
            // end
            
            // // '+' (position 23-25)
            // if (x >= 23 && x <= 25) begin
                // oled_data = BLACK;
            // end
            
            // // 'b' coefficient (position 27-32)
            // if (x >= 27 && x <= 32) begin
                // if (coeff_state == 1)
                    // oled_data = GREEN;  // Highlight if this is the current coefficient
            // end
            
            // // 'x²' (position 33-39)
            // if (x >= 33 && x <= 39) begin
                // oled_data = BLACK;
            // end
            
            // // '+' (position 40-42)
            // if (x >= 40 && x <= 42) begin
                // oled_data = BLACK;
            // end
            
            // // 'c' coefficient (position 44-49)
            // if (x >= 44 && x <= 49) begin
                // if (coeff_state == 2)
                    // oled_data = GREEN;  // Highlight if this is the current coefficient
            // end
            
            // // 'x' (position 50-53)
            // if (x >= 50 && x <= 53) begin
                // oled_data = BLACK;
            // end
            
            // // '+' (position 54-56)
            // if (x >= 54 && x <= 56) begin
                // oled_data = BLACK;
            // end
            
            // // 'd' coefficient (position 58-63)
            // if (x >= 58 && x <= 63) begin
                // if (coeff_state == 3)
                    // oled_data = GREEN;  // Highlight if this is the current coefficient
            // end
        // end
        
        // Render label (if active)
        if (label_active) begin
            oled_data = label_data;
        end
        
        // Render input string
        if (string_active) begin
            oled_data = string_data;
        end
        
        // Render blinking cursor
        if (cursor_active && cursor_visible) begin
            oled_data = BLACK;
        end
    end
endmodule

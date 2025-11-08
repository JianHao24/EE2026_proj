`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 23.03.2025 13:01:15
// Design Name: 
// Module Name: polynomial_table_table_display_optimized
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


module polynomial_table_table_display_optimized(
    input clk,
    input [12:0] pixel_index,
    input is_table_mode,
    
    // From polynomial_table_cursor_controller
    input signed [31:0] starting_x,

    // From some other module
    input signed [31:0] coeff_a,
    input signed [31:0] coeff_b,
    input signed [31:0] coeff_c,
    input signed [31:0] coeff_d,
    
    // Output
    output reg [15:0] oled_data
    );

    // OLED display parameters
    parameter WIDTH = 96;
    parameter HEIGHT = 64;
    
    // Table layout constants
    parameter ROW_HEIGHT = 12;    
    parameter COL_WIDTH = 48;
    parameter HEADER_HEIGHT = 12; 
    parameter TABLE_ROWS = 5;

    // Reduced-precision fixed point (Q8.8 instead of Q16.16)
    // This dramatically reduces DSP and LUT usage
    reg signed [15:0] reduced_starting_x;
    reg signed [15:0] reduced_coeff_a;
    reg signed [15:0] reduced_coeff_b;
    reg signed [15:0] reduced_coeff_c;
    reg signed [15:0] reduced_coeff_d;

    // Calculation state machine
    reg [2:0] state = 0;
    reg [2:0] calc_row = 0;
    reg needs_update = 1;
    reg [31:0] prev_starting_x = 0;     

    // Store results in a table (use BRAM)
    (* ram_style = "block" *) reg signed [15:0] x_values[0:TABLE_ROWS-1];
    (* ram_style = "block" *) reg signed [15:0] y_values[0:TABLE_ROWS-1];

    // Temporary variables for calculation
    reg signed [15:0] x_val;
    reg signed [15:0] x_squared;
    reg signed [15:0] x_cubed;
    reg signed [15:0] term_a;
    reg signed [15:0] term_b;
    reg signed [15:0] term_c;

    // Simple fixed-point number to string conversion (only 5 chars)
    function [29:0] simple_int_to_string(input signed [15:0] value);
        reg [15:0] abs_val;
        reg [3:0] dig1, dig2, dig3, dig4, dig5;
        begin
            // Get absolute value
            abs_val = (value < 0) ? -value : value;
            
            // Extract digits (limited to 5 digits)
            dig1 = abs_val / 1000;
            dig2 = (abs_val / 100) % 10;
            dig3 = (abs_val / 10) % 10;
            dig4 = abs_val % 10;
            
            // Convert to character codes (simplified)
            simple_int_to_string = {
                (value < 0) ? 6'd11 : 6'd32, // Minus or space
                dig1 > 0 ? dig1 + 6'd0 : 6'd32, // First digit or space 
                dig1 > 0 || dig2 > 0 ? dig2 + 6'd0 : 6'd32, // Second digit or space
                dig1 > 0 || dig2 > 0 || dig3 > 0 ? dig3 + 6'd0 : 6'd32, // Third digit or space
                dig4 + 6'd0 // Last digit (always show)
            };
        end
    endfunction

    // Update detection
    always @(posedge clk) begin
        if (starting_x != prev_starting_x) begin
            needs_update <= 1;
            prev_starting_x <= starting_x;
        end
    end

    // The main calculation state machine - calculates one row per clock cycle
    // This replaces the massive combinational logic in the original
    always @(posedge clk) begin
        if (needs_update && is_table_mode) begin
            case (state)
                0: begin // Initialize and convert to reduced precision
                    reduced_starting_x <= starting_x[23:8]; // Take middle 16 bits
                    reduced_coeff_a <= coeff_a[23:8];
                    reduced_coeff_b <= coeff_b[23:8];
                    reduced_coeff_c <= coeff_c[23:8];
                    reduced_coeff_d <= coeff_d[23:8];
                    calc_row <= 0;
                    state <= 1;
                end
                
                1: begin // Calculate x value for current row
                    x_val <= reduced_starting_x + (calc_row << 8); // Add row number in Q8.8
                    state <= 2;
                end
                
                2: begin // Calculate x² term
                    x_values[calc_row] <= x_val; // Store x value
                    x_squared <= ((x_val * x_val) >>> 8); // Q8.8 multiplication
                    state <= 3;
                end
                
                3: begin // Calculate x³ term
                    x_cubed <= ((x_squared * x_val) >>> 8); // Q8.8 multiplication
                    state <= 4;
                end
                
                4: begin // Calculate polynomial terms
                    term_a <= ((reduced_coeff_a * x_cubed) >>> 8);
                    term_b <= ((reduced_coeff_b * x_squared) >>> 8);
                    term_c <= ((reduced_coeff_c * x_val) >>> 8);
                    state <= 5;
                end
                
                5: begin // Final sum and store result
                    y_values[calc_row] <= term_a + term_b + term_c + reduced_coeff_d;
                    
                    // Move to next row or finish
                    if (calc_row < TABLE_ROWS-1) begin
                        calc_row <= calc_row + 1;
                        state <= 1; // Next row
                    end
                    else begin
                        needs_update <= 0;
                        state <= 0; // Done
                    end
                end
            endcase
        end
    end

    // Display logic - simplified to reduce resource usage
    wire [6:0] x = pixel_index % WIDTH;
    wire [5:0] y = pixel_index / WIDTH;
    
    // Determine which part of the table we're in
    wire in_header = (y < HEADER_HEIGHT);
    wire in_table_body = (y >= HEADER_HEIGHT && y < HEADER_HEIGHT + TABLE_ROWS * ROW_HEIGHT);
    wire in_border = (x == 0 || x == WIDTH-1 || y == 0 || y == HEIGHT-1 || 
                     x == COL_WIDTH || y == HEADER_HEIGHT);
    
    // Current row in the table
    wire [2:0] current_row = (y - HEADER_HEIGHT) / ROW_HEIGHT;
    
    // Display text for current position (simplified)
    wire [29:0] x_text = simple_int_to_string(x_values[current_row]);
    wire [29:0] y_text = simple_int_to_string(y_values[current_row]);
    
    // Simplified header text
    wire [11:0] header_x = {6'd38, 6'd32}; // "X "
    wire [11:0] header_y = {6'd39, 6'd32}; // "Y "
    
    // Simplified display renderer
    always @(posedge clk) begin
        if (is_table_mode) begin
            if (in_border)
                oled_data <= 16'h0; // Black border
            else if (in_header) begin
                if (x < COL_WIDTH/2)
                    oled_data <= (x-4)/8 == 0 && header_x[5:0] != 6'd32 ? 16'h0000 : 16'hFFFF;
                else if (x < COL_WIDTH)
                    oled_data <= (x-COL_WIDTH/2-4)/8 == 0 && header_x[11:6] != 6'd32 ? 16'h0000 : 16'hFFFF;
                else if (x < COL_WIDTH + COL_WIDTH/2)
                    oled_data <= (x-COL_WIDTH-4)/8 == 0 && header_y[5:0] != 6'd32 ? 16'h0000 : 16'hFFFF;
                else
                    oled_data <= (x-COL_WIDTH-COL_WIDTH/2-4)/8 == 0 && header_y[11:6] != 6'd32 ? 16'h0000 : 16'hFFFF;
            end
            else if (in_table_body) begin
                if (x < COL_WIDTH/2)
                    oled_data <= (x-4)/8 < 5 && x_text[(4-(x-4)/8)*6 +: 6] != 6'd32 ? 16'h0000 : 16'hFFFF;
                else if (x < COL_WIDTH)
                    oled_data <= (x-COL_WIDTH/2-4)/8 < 5 && x_text[(4-(x-COL_WIDTH/2-4)/8)*6 +: 6] != 6'd32 ? 16'h0000 : 16'hFFFF;
                else if (x < COL_WIDTH + COL_WIDTH/2)
                    oled_data <= (x-COL_WIDTH-4)/8 < 5 && y_text[(4-(x-COL_WIDTH-4)/8)*6 +: 6] != 6'd32 ? 16'h0000 : 16'hFFFF;
                else
                    oled_data <= (x-COL_WIDTH-COL_WIDTH/2-4)/8 < 5 && y_text[(4-(x-COL_WIDTH-COL_WIDTH/2-4)/8)*6 +: 6] != 6'd32 ? 16'h0000 : 16'hFFFF;
            end
            else
                oled_data <= 16'hFFFF; // White background
        end
        else
            oled_data <= 16'hFFFF; // White background when not in table mode
    end
    
endmodule

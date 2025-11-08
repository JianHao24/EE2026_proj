`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 
// Design Name: 
// Module Name: polynomial_coeff_status_display
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: Displays polynomial coefficient status - shows current coefficient
//              being edited and polynomial degree
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module polynomial_coeff_status_display(
    input clk,
    input [12:0] pixel_index,
    input [2:0] current_coeff_index,
    input [159:0] coeffs,  // Packed: {a4, a3, a2, a1, a0}, each 32 bits
    input signed [31:0] x_value,
    input [2:0] polynomial_degree,
    input eval_mode,
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
    
    // Text positioning
    parameter text_start_x = 4;
    parameter text_start_y = 4;
    parameter line_height = 8;
    
    // Extract coefficients
    wire signed [31:0] a0 = coeffs[31:0];
    wire signed [31:0] a1 = coeffs[63:32];
    wire signed [31:0] a2 = coeffs[95:64];
    wire signed [31:0] a3 = coeffs[127:96];
    wire signed [31:0] a4 = coeffs[159:128];
    
    // Status string (simplified - just show current coefficient index)
    reg [47:0] status_string;
    wire [15:0] status_pixel_data;
    wire status_pixel_active;
    
    // Generate status string
    always @(*) begin
        case(current_coeff_index)
            3'd0: status_string = {6'd10, 6'd0, 6'd58, 6'd32, 6'd32, 6'd32, 6'd32, 6'd32}; // "a0:"
            3'd1: status_string = {6'd10, 6'd1, 6'd58, 6'd32, 6'd32, 6'd32, 6'd32, 6'd32}; // "a1:"
            3'd2: status_string = {6'd10, 6'd2, 6'd58, 6'd32, 6'd32, 6'd32, 6'd32, 6'd32}; // "a2:"
            3'd3: status_string = {6'd10, 6'd3, 6'd58, 6'd32, 6'd32, 6'd32, 6'd32, 6'd32}; // "a3:"
            3'd4: status_string = {6'd10, 6'd4, 6'd58, 6'd32, 6'd32, 6'd32, 6'd32, 6'd32}; // "a4:"
            3'd5: status_string = {6'd33, 6'd58, 6'd32, 6'd32, 6'd32, 6'd32, 6'd32, 6'd32}; // "x:"
            default: status_string = 48'hFFFFFFFFFFFF;
        endcase
    end
    
    string_renderer_optimized status_renderer(
        .clk(clk),
        .word(status_string),
        .start_x(text_start_x),
        .start_y(text_start_y),
        .pixel_index(pixel_index),
        .colour(black),
        .oled_data(status_pixel_data),
        .active_pixel(status_pixel_active)
    );
    
    // Mode display
    reg [47:0] mode_string;
    wire [15:0] mode_pixel_data;
    wire mode_pixel_active;
    
    always @(*) begin
        if (eval_mode)
            mode_string = {6'd6, 6'd27, 6'd40, 6'd33, 6'd41, 6'd32, 6'd32, 6'd32}; // "f'(x)"
        else
            mode_string = {6'd6, 6'd40, 6'd33, 6'd41, 6'd32, 6'd32, 6'd32, 6'd32}; // "f(x)"
    end
    
    string_renderer_optimized mode_renderer(
        .clk(clk),
        .word(mode_string),
        .start_x(text_start_x),
        .start_y(text_start_y + line_height),
        .pixel_index(pixel_index),
        .colour(black),
        .oled_data(mode_pixel_data),
        .active_pixel(mode_pixel_active)
    );
    
    // Degree display
    reg [47:0] degree_string;
    wire [15:0] degree_pixel_data;
    wire degree_pixel_active;
    
    always @(*) begin
        case(polynomial_degree)
            3'd0: degree_string = {6'd4, 6'd5, 6'd7, 6'd58, 6'd32, 6'd0, 6'd32, 6'd32}; // "Deg:0"
            3'd1: degree_string = {6'd4, 6'd5, 6'd7, 6'd58, 6'd32, 6'd1, 6'd32, 6'd32}; // "Deg:1"
            3'd2: degree_string = {6'd4, 6'd5, 6'd7, 6'd58, 6'd32, 6'd2, 6'd32, 6'd32}; // "Deg:2"
            3'd3: degree_string = {6'd4, 6'd5, 6'd7, 6'd58, 6'd32, 6'd3, 6'd32, 6'd32}; // "Deg:3"
            3'd4: degree_string = {6'd4, 6'd5, 6'd7, 6'd58, 6'd32, 6'd4, 6'd32, 6'd32}; // "Deg:4"
            default: degree_string = 48'hFFFFFFFFFFFF;
        endcase
    end
    
    string_renderer_optimized degree_renderer(
        .clk(clk),
        .word(degree_string),
        .start_x(text_start_x),
        .start_y(text_start_y + 2*line_height),
        .pixel_index(pixel_index),
        .colour(black),
        .oled_data(degree_pixel_data),
        .active_pixel(degree_pixel_active)
    );
    
    // Display output logic
    always @(*) begin
        oled_data = white;
        
        if (status_pixel_active) begin
            oled_data = status_pixel_data;
        end else if (mode_pixel_active) begin
            oled_data = mode_pixel_data;
        end else if (degree_pixel_active) begin
            oled_data = degree_pixel_data;
        end
    end
endmodule


`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 24.10.2025 15:24:49
// Design Name: 
// Module Name: char_renderer
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


module char_renderer(
    input clk,
    input [12:0] pixel_index,
    input [5:0] char,
    input [6:0] start_x,
    input [5:0] start_y,
    input [15:0] colour,
    output reg [15:0] oled_data,
    output reg active_pixel
    );
    parameter width = 96;
    parameter height = 64;
    parameter char_width = 8;
    parameter char_height = 12;
    
    // Determine pixel coordinates
    wire [6:0] x = pixel_index % width;
    wire [5:0] y = pixel_index / width;
    
    // Check if pixel is within character bounds
    wire in_bounds = (x >= start_x && x < start_x + char_width && 
                      y >= start_y && y < start_y + char_height);
    
    // Calculate position within character
    wire [3:0] row = in_bounds ? (y - start_y) : 4'd15;
    wire [2:0] col = in_bounds ? (x - start_x) : 3'd7;
    
    // Pixel data from ROM
    wire [7:0] pixel_row;
    
    // Use optimized sprite library
    sprite_library_optimized char_rom(
        .character(char),
        .row(row),
        .pixels(pixel_row)
    );
    
    // Output logic
    always @(posedge clk) begin
        if (in_bounds && pixel_row[char_width-1-col]) begin
            oled_data <= colour;
            active_pixel <= 1;
        end
        else begin
            oled_data <= 16'b11111_111111_11111;
            active_pixel <= 0;
        end
    end
endmodule
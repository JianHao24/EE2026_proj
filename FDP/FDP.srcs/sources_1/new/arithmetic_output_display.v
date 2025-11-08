`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 06.11.2025 00:39:27
// Design Name: 
// Module Name: arithmetic_output_display
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


module calculator_output(
    input clk,
    input [12:0] pixel_index,
    input signed [31:0] computed_result,
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
    
    // Text positioning constants
    parameter text_x_offset = 8;
    parameter text_y_offset = 24;
    
    // Conversion control signals
    reg [31:0] cached_result;
    reg trigger_conversion;
    wire conversion_complete;
    wire [47:0] formatted_string;
    
    // FSM for conversion control
    reg [1:0] control_state;
    localparam ST_IDLE = 2'd0;
    localparam ST_CONVERT = 2'd1;
    localparam ST_RENDER = 2'd2;
    
    // String renderer signals
    wire [15:0] rendered_data;
    wire pixel_is_active;
    
    // Fixed-point to string converter instance
    fp_to_string converter_inst(
        .clk(clk),
        .start_conversion(trigger_conversion),
        .fp_value(computed_result),
        .conversion_done(conversion_complete),
        .result(formatted_string)
    );
    
    // String renderer instance
    string_renderer renderer_inst(
        .clk(clk),
        .word(formatted_string),
        .start_x(text_x_offset),
        .start_y(text_y_offset),
        .pixel_index(pixel_index),
        .colour(black),
        .oled_data(rendered_data),
        .active_pixel(pixel_is_active)
    );
    
    // Conversion control FSM
    always @(posedge clk) begin
        trigger_conversion <= 1'b0;
        
        case (control_state)
            ST_IDLE: begin
                if (computed_result != cached_result) begin
                    cached_result <= computed_result;
                    trigger_conversion <= 1'b1;
                    control_state <= ST_CONVERT;
                end
                else begin
                    trigger_conversion <= 1'b1;
                    control_state <= ST_CONVERT;
                end
            end
            
            ST_CONVERT: begin
                if (conversion_complete) begin
                    control_state <= ST_RENDER;
                end
            end
            
            ST_RENDER: begin
                control_state <= ST_IDLE;
            end
            
            default: control_state <= ST_IDLE;
        endcase
    end
    
    // Display output logic
    always @(*) begin
        oled_data = white;
        
        if (pixel_is_active) begin
            oled_data = rendered_data;
        end
    end
    
endmodule
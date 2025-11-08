`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 06.11.2025 00:44:44
// Design Name: 
// Module Name: arithmetic_text_selector
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


module calculator_text(
    input clk,
    input [12:0] pixel_index,
    input signed [31:0] computed_result,
    input waiting_operand,
    input waiting_trig,
    input [31:0] bcd_value,
    input [3:0] decimal_pos,
    input [3:0] input_index,
    input has_decimal,
    output reg [15:0] oled_data
);
    
    // Display outputs
    wire [15:0] input_display_data;
    wire [15:0] output_display_data;
    
    // Instantiate input display module
    calculator_input input_inst(
        .clk(clk),
        .pixel_index(pixel_index),
        .bcd_value(bcd_value),
        .decimal_pos(decimal_pos),
        .input_index(input_index),
        .has_decimal(has_decimal),
        .oled_data(input_display_data)
    );
    
    // Instantiate output display module
    calculator_output output_inst(
        .clk(clk),
        .pixel_index(pixel_index),
        .computed_result(computed_result),
        .oled_data(output_display_data)
    );
    
    // Mode-based text selection
    always @(*) begin
        if (waiting_trig)
            oled_data = input_display_data;  // Keep showing input while selecting trig
        else if (waiting_operand)
            oled_data = output_display_data;
        else
            oled_data = input_display_data;
    end
endmodule
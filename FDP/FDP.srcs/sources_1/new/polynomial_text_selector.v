`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 
// Design Name: 
// Module Name: polynomial_text_selector
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: Text display selector for polynomial mode - shows input values,
//              coefficients, x value, and evaluation results
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module polynomial_text_selector(
    input clk,
    input [12:0] pixel_index,
    input signed [31:0] computed_result,
    input waiting_coeff_selection,
    input waiting_mode_selection,
    input show_result,
    input [31:0] bcd_value,
    input [3:0] decimal_pos,
    input [3:0] input_index,
    input has_decimal,
    input has_negative,
    input [2:0] current_coeff_index,
    input [159:0] coeffs,  // Packed: {a4, a3, a2, a1, a0}, each 32 bits
    input signed [31:0] x_value,
    input [2:0] polynomial_degree,
    input eval_mode,
    output reg [15:0] oled_data
);
    
    // Display outputs
    wire [15:0] input_display_data;
    wire [15:0] output_display_data;
    wire [15:0] coeff_status_data;
    
    // Instantiate input display module
    arithmetic_input_display input_inst(
        .clk(clk),
        .pixel_index(pixel_index),
        .bcd_value(bcd_value),
        .decimal_pos(decimal_pos),
        .input_index(input_index),
        .has_decimal(has_decimal),
        .has_negative(has_negative),
        .oled_data(input_display_data)
    );
    
    // Instantiate output display module
    arithmetic_output_display output_inst(
        .clk(clk),
        .pixel_index(pixel_index),
        .computed_result(computed_result),
        .oled_data(output_display_data)
    );
    
    // Coefficient status display (shows which coefficient is being edited)
    polynomial_coeff_status_display status_inst(
        .clk(clk),
        .pixel_index(pixel_index),
        .current_coeff_index(current_coeff_index),
        .coeffs(coeffs),
        .x_value(x_value),
        .polynomial_degree(polynomial_degree),
        .eval_mode(eval_mode),
        .oled_data(coeff_status_data)
    );
    
    // Mode-based text selection
    always @(*) begin
        if (waiting_mode_selection)
            oled_data = coeff_status_data;  // Show status while selecting mode
        else if (waiting_coeff_selection)
            oled_data = coeff_status_data;  // Show coefficient status
        else if (show_result)
            oled_data = output_display_data;  // Show result
        else
            oled_data = input_display_data;  // Default: show input
    end
endmodule


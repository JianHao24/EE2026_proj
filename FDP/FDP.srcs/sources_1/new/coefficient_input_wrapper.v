`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11/08/2025 05:09:42 PM
// Design Name: 
// Module Name: coefficient_input_wrapper
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




module coefficient_input_wrapper(
    input clk_6p25MHz,
    input clk_1kHz,
    input btnC, btnU, btnD, btnL, btnR,
    input [12:0] one_pixel_index,
    input [12:0] two_pixel_index,
    input reset,
    output [15:0] one_oled_data,
    output [15:0] two_oled_data,
    output signed [31:0] coeff_a,
    output signed [31:0] coeff_b,
    output signed [31:0] coeff_c,
    output signed [31:0] coeff_d,
    output coefficients_ready
);

    // State machine for coefficient entry
    reg [2:0] coeff_state = 0;  // 0=A, 1=B, 2=C, 3=D, 4=Done
    
    // Store coefficients in persistent registers
    reg signed [31:0] stored_a = 0, stored_b = 0, stored_c = 0, stored_d = 0;
    reg stored_coeffs_ready = 0;
    
    // Input system control
    reg input_system_reset = 0;
    reg prev_input_complete = 0;
    
    // Keypad interaction signals
    wire [1:0] cursor_row;
    wire [2:0] cursor_col;
    wire keypad_btn_pressed;
    wire [3:0] keypad_selected_value;
    wire input_complete;
    wire signed [31:0] fp_value;
    
    // Input builder signals
    wire has_decimal, has_negative;
    wire [3:0] input_index;
    wire [31:0] bcd_value;
    wire [3:0] decimal_pos;
    
    // Display outputs
    wire [15:0] keypad_oled_data;
    wire [15:0] input_oled_data;
    
    // Output the stored coefficients (persistent across mode switches)
    assign coefficients_ready = stored_coeffs_ready;
    assign coeff_a = stored_a;
    assign coeff_b = stored_b;
    assign coeff_c = stored_c;
    assign coeff_d = stored_d;
    
    // Cursor controller for keypad
    coeff_controller coeff_ctrl(
        .clk(clk_1kHz),
        .reset(reset),
        .btnC(btnC), .btnU(btnU), .btnD(btnD), .btnL(btnL), .btnR(btnR),
        .is_integral_mode(1'b1),
        .is_integral_input_mode(coeff_state < 4),
        .cursor_row(cursor_row),
        .cursor_col(cursor_col),
        .keypad_btn_pressed(keypad_btn_pressed),
        .keypad_selected_value(keypad_selected_value)
    );
    
    // Input builder with proper reset signal
    bcd_to_fp_input_system #(
        .DIGIT_CAPACITY(8),
        .FIXED_FRAC_BITS(16)
    ) input_builder (
        .clk(clk_1kHz),
        .reset(input_system_reset || reset),
        .keypad_btn_pressed(keypad_btn_pressed),
        .selected_keypad_value(keypad_selected_value),
        .is_active_mode(coeff_state < 4),
        .enable_negative(1'b1),
        .enable_backspace(1'b0),
        .has_decimal(has_decimal),
        .has_negative(has_negative),
        .input_index(input_index),
        .fp_value(fp_value),
        .bcd_value(bcd_value),
        .input_complete(input_complete),
        .decimal_pos(decimal_pos)
    );
    
    // Keypad display
    polytable_keypad_display keypad_display(
        .clk(clk_6p25MHz),
        .pixel_index(one_pixel_index),
        .cursor_row(cursor_row),
        .cursor_col(cursor_col),
        .has_decimal(has_decimal),
        .has_negative(has_negative),
        .input_index(input_index),
        .oled_data(keypad_oled_data)
    );
    
    // Input display
    coefficient_input_display coeff_display(
        .clk(clk_6p25MHz),
        .pixel_index(two_pixel_index),
        .bcd_value(bcd_value),
        .decimal_pos(decimal_pos),
        .input_index(input_index),
        .has_decimal(has_decimal),
        .has_negative(has_negative),
        .coeff_state(coeff_state[1:0]),
        .oled_data(input_oled_data)
    );
    
    assign one_oled_data = keypad_oled_data;
    assign two_oled_data = input_oled_data;
    
    // State machine - only reset input system, NOT stored coefficients
    always @(posedge clk_1kHz) begin
        input_system_reset <= 0;
        prev_input_complete <= input_complete;
        
        if (reset) begin
            coeff_state <= stored_coeffs_ready ? 4 : 0;
            input_system_reset <= 1;
        end
        else if (input_complete && !prev_input_complete) begin
            case (coeff_state)
                0: begin 
                    stored_a <= fp_value; 
                    coeff_state <= 1;
                    input_system_reset <= 1;
                end
                1: begin 
                    stored_b <= fp_value; 
                    coeff_state <= 2;
                    input_system_reset <= 1;
                end
                2: begin 
                    stored_c <= fp_value; 
                    coeff_state <= 3;
                    input_system_reset <= 1;
                end
                3: begin 
                    stored_d <= fp_value; 
                    coeff_state <= 4;
                    stored_coeffs_ready <= 1;
                end
            endcase
        end
    end
    
endmodule
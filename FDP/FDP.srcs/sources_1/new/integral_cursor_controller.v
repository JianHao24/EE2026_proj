`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03.04.2025 13:08:09
// Design Name: 
// Module Name: integral_cursor_controller
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


module coeff_controller(
    input clk,
    input reset,
    input btnC,
    input btnU,
    input btnD,
    input btnL,
    input btnR,
    input is_integral_mode,
    input is_integral_input_mode,
    output reg [1:0] cursor_row = 0,
    output reg [2:0] cursor_col = 0,
    output reg keypad_btn_pressed = 0,
    output reg [3:0] keypad_selected_value = 0
    );

    // Previous button states for debouncing
    reg prev_btnC = 0;
    reg prev_btnU = 0;
    reg prev_btnD = 0;
    reg prev_btnL = 0;
    reg prev_btnR = 0;

    // Debouncing counters
    reg [7:0] debounce_C = 0;
    reg [7:0] debounce_U = 0;
    reg [7:0] debounce_D = 0;
    reg [7:0] debounce_L = 0;
    reg [7:0] debounce_R = 0;

    reg [8:0] count = 500;

    // Flag to track if on the checkmark
    wire on_checkmark = (cursor_col == 3'd3);

    // Button handling loop
    always @ (posedge clk) begin
        if (reset || !is_integral_mode) begin
            // Reset all state variables to initial values
            cursor_row <= 0;
            cursor_col <= 0;
            keypad_btn_pressed <= 0;
            keypad_selected_value <= 0;
            
            // Reset debounce counters and button states
            prev_btnC <= 0;
            prev_btnU <= 0;
            prev_btnD <= 0;
            prev_btnL <= 0;
            prev_btnR <= 0;
            debounce_C <= 0;
            debounce_U <= 0;
            debounce_D <= 0;
            debounce_L <= 0;
            debounce_R <= 0;
            count <= 500;
        end
        else if (is_integral_input_mode) begin
            if (count == 0) begin
                // Reset button pressed signal each cycle
                keypad_btn_pressed <= 0;
            
                // Decrement debounce counters if active
                if (debounce_U > 0) debounce_U <= debounce_U - 1;
                if (debounce_D > 0) debounce_D <= debounce_D - 1;
                if (debounce_L > 0) debounce_L <= debounce_L - 1;
                if (debounce_R > 0) debounce_R <= debounce_R - 1;
                if (debounce_C > 0) debounce_C <= debounce_C - 1;

                // Up button processing
                if (btnU && !prev_btnU && debounce_U == 0) begin
                    if (cursor_row > 0 && !on_checkmark) begin
                        cursor_row <= cursor_row - 1;
                    end
                    debounce_U <= 200;
                end

                // Down
                if (btnD && !prev_btnD && debounce_D == 0) begin
                    if (cursor_row < 3 && !on_checkmark) begin
                        cursor_row <= cursor_row + 1;
                    end
                    debounce_D <= 200;
                end

                // Left
                if (btnL && !prev_btnL && debounce_L == 0) begin
                    if (on_checkmark) begin
                        // Moving left from checkmark goes to the main keypad
                        cursor_col <= 3'd2;
                    end else if (cursor_col > 0) begin
                        cursor_col <= cursor_col - 1;
                    end
                    debounce_L <= 200;
                end

                // Right
                if (btnR && !prev_btnR && debounce_R == 0) begin
                    if (!on_checkmark && cursor_col < 2) begin
                        cursor_col <= cursor_col + 1;
                    end else if (!on_checkmark && cursor_col == 2) begin
                        cursor_col <= 3'd3;  // Go to checkmark column
                    end
                    debounce_R <= 200;
                end

                // Center (Selection)
                if (btnC && !prev_btnC && debounce_C == 0) begin
                    keypad_btn_pressed <= 1;

                    if (on_checkmark) begin
                        // Checkmark selected
                        keypad_selected_value <= 4'd12;  // Special value for checkmark

                        // Reset cursor position after submission
                        cursor_col <= 0;
                        cursor_row <= 0;
                    end else begin
                        // Determining selected value based on cursor position in main keypad
                        case(cursor_row)
                            2'd0: keypad_selected_value <= cursor_col + 4'd7; // 7, 8, 9
                            2'd1: keypad_selected_value <= cursor_col + 4'd4; // 4, 5, 6
                            2'd2: keypad_selected_value <= cursor_col + 4'd1; // 1, 2, 3
                            2'd3: begin
                                case(cursor_col)
                                    2'd0: keypad_selected_value <= 4'd0; // 0
                                    2'd1: keypad_selected_value <= 4'd10; // . decimal
                                    2'd2: keypad_selected_value <= 4'd13; 
                                endcase
                            end
                        endcase
                    end

                    debounce_C <= 200;
                end

                // Update previous button states
                prev_btnU <= btnU;
                prev_btnD <= btnD;
                prev_btnL <= btnL;
                prev_btnR <= btnR;
                prev_btnC <= btnC;
            end
            else begin
                count <= count - 1;
            end
        end
    end
endmodule

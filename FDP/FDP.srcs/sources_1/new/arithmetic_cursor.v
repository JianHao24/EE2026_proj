`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11/06/2025 09:35:50 PM
// Design Name: 
// Module Name: arithmetic_cursor
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

module arithmetic_cursor(
    input clk,
    input reset,
    input btnC,
    input btnU,
    input btnD,
    input btnL,
    input btnR,
    input waiting_operand,
    output reg [1:0]cursor_row_keypad = 0,
    output reg [2:0]cursor_col_keypad = 0,
    output reg [1:0]cursor_row_operand = 0,
    output reg [1:0]cursor_col_operand = 0,
    output reg keypad_btn_pressed = 0,
    output reg [3:0]keypad_selected_value = 0,
    output reg operand_btn_pressed = 0,
    output reg [1:0]operand_selected_value = 0
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

    // Waiting counter
    reg [8:0] counter = 9'd500;

    // Flag to track if on the checkmark
    wire on_checkmark = (cursor_col_keypad == 3'd3 && !waiting_operand);

    // Button handling loop
    always @ (posedge clk) begin
        if (reset) begin
            // Reset all state variables to initial values
            cursor_row_keypad <= 0;
            cursor_col_keypad <= 0;
            cursor_row_operand <= 0;
            cursor_col_operand <= 0;
            keypad_btn_pressed <= 0;
            keypad_selected_value <= 0;
            operand_btn_pressed <= 0;
            operand_selected_value <= 0;
            
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
            counter <= 500;
        end
        else begin
            // Reset button pressed signal each cycle
            keypad_btn_pressed <= 0;
            operand_btn_pressed <= 0;
        
            // Decrement debounce counters if active
            if (debounce_U > 0) debounce_U <= debounce_U - 1;
            if (debounce_D > 0) debounce_D <= debounce_D - 1;
            if (debounce_L > 0) debounce_L <= debounce_L - 1;
            if (debounce_R > 0) debounce_R <= debounce_R - 1;
            if (debounce_C > 0) debounce_C <= debounce_C - 1;

            if (!waiting_operand) begin
                if (counter == 0) begin
                    // Up button processing
                    if (btnU && !prev_btnU && debounce_U == 0) begin
                        if (cursor_row_keypad > 0 && !on_checkmark) begin
                            cursor_row_keypad <= cursor_row_keypad - 1;
                        end
                        debounce_U <= 200;
                    end

                    // Down
                    if (btnD && !prev_btnD && debounce_D == 0) begin
                        if (cursor_row_keypad < 3 && !on_checkmark) begin
                            cursor_row_keypad <= cursor_row_keypad + 1;
                        end
                        debounce_D <= 200;
                    end

                    // Left
                    if (btnL && !prev_btnL && debounce_L == 0) begin
                        if (on_checkmark) begin
                            // Moving left from checkmark goes to the main keypad
                            cursor_col_keypad <= 3'd2;
                        end else if (cursor_col_keypad > 0) begin
                            cursor_col_keypad <= cursor_col_keypad - 1;
                        end
                        debounce_L <= 200;
                    end

                    // Right
                    if (btnR && !prev_btnR && debounce_R == 0) begin
                        if (!on_checkmark && cursor_col_keypad < 2) begin
                            cursor_col_keypad <= cursor_col_keypad + 1;
                        end else if (!on_checkmark && cursor_col_keypad == 2) begin
                            cursor_col_keypad <= 3'd3;  // Go to
                        end
                        debounce_R <= 200;
                    end

                    // Center (Selection)
                    if (btnC && !prev_btnC && debounce_C == 0) begin
                        keypad_btn_pressed <= 1;
                        counter <= 500;
                        if (on_checkmark) begin
                            // Checkmark selected
                            keypad_selected_value <= 4'd12;  // Special value for checkmark
                        end else begin
                            // Determining selected value based on cursor position in main keypad
                            case(cursor_row_keypad)
                                2'd0: keypad_selected_value <= cursor_col_keypad + 4'd7; // 7, 8, 9
                                2'd1: keypad_selected_value <= cursor_col_keypad + 4'd4; // 4, 5, 6
                                2'd2: keypad_selected_value <= cursor_col_keypad + 4'd1; // 1, 2, 3
                                2'd3: begin
                                    case(cursor_col_keypad)
                                        2'd0: keypad_selected_value <= 4'd0; // 0
                                        2'd1: keypad_selected_value <= 4'd10; // . decimal
                                        2'd2: keypad_selected_value <= 4'd11; // x backspace
                                    endcase
                                end
                            endcase
                        end

                        debounce_C <= 200;
                    end
                end
                else begin
                    counter <= counter -1;
                end
            end
            else begin
                // OPERAND MODE
                // Up button handling
                if (btnU && !prev_btnU && debounce_U == 0) begin
                    if (cursor_row_operand > 0) begin
                        cursor_row_operand <= cursor_row_operand - 1;
                    end
                    debounce_U <= 200;
                end
            
                // Down button handling
                if (btnD && !prev_btnD && debounce_D == 0) begin
                    if (cursor_row_operand < 1) begin  
                        cursor_row_operand <= cursor_row_operand + 1;
                    end
                    debounce_D <= 200;
                end
            
                // Left button handling
                if (btnL && !prev_btnL && debounce_L == 0) begin
                    if (cursor_col_operand > 0) begin
                        cursor_col_operand <= cursor_col_operand - 1;
                    end
                    debounce_L <= 200;
                end
            
                // Right button handling
                if (btnR && !prev_btnR && debounce_R == 0) begin
                    if (cursor_col_operand < 1) begin  
                        cursor_col_operand <= cursor_col_operand + 1;
                    end
                    debounce_R <= 200;
                end
            
                // Center button handling (selection)
                if (btnC && !prev_btnC && debounce_C == 0) begin
                    operand_btn_pressed <= 1;
                
                    // Determine selected operand based on cursor position
                    case({cursor_row_operand, cursor_col_operand})
                        4'b00_00: operand_selected_value <= 2'd0; // +
                        4'b00_01: operand_selected_value <= 2'd1; // -
                        4'b01_00: operand_selected_value <= 2'd2; // ร-
                        4'b01_01: operand_selected_value <= 2'd3; // รท
                    endcase
                
                    debounce_C <= 200;
                end
            end

        

            // Update previous button states
            prev_btnU <= btnU;
            prev_btnD <= btnD;
            prev_btnL <= btnL;
            prev_btnR <= btnR;
            prev_btnC <= btnC;
        end
    end


endmodule

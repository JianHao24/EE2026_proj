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
    output reg [1:0] cursor_row_keypad = 0,
    output reg [2:0] cursor_col_keypad = 0,
    output reg [1:0] cursor_row_operand = 0,
    output reg [1:0] cursor_col_operand = 0,
    output reg keypad_btn_pressed = 0,
    output reg [3:0] keypad_selected_value = 0,
    output reg operand_btn_pressed = 0,
    output reg [1:0] operand_selected_value = 0
);

    // Button state tracking
    reg prev_btnC, prev_btnU, prev_btnD, prev_btnL, prev_btnR;
    
    // Debounce timers
    reg [7:0] timer_C, timer_U, timer_D, timer_L, timer_R;
    
    // Input cooldown
    reg [8:0] input_cooldown;
    
    // Position checks
    wire at_checkmark = (cursor_col_keypad == 3'd3) && !waiting_operand;

    always @(posedge clk) begin
        // Store previous button states
        prev_btnC <= btnC;
        prev_btnU <= btnU;
        prev_btnD <= btnD;
        prev_btnL <= btnL;
        prev_btnR <= btnR;
        
        // Count down debounce timers
        if (timer_C > 0) timer_C <= timer_C - 1;
        if (timer_U > 0) timer_U <= timer_U - 1;
        if (timer_D > 0) timer_D <= timer_D - 1;
        if (timer_L > 0) timer_L <= timer_L - 1;
        if (timer_R > 0) timer_R <= timer_R - 1;
        
        // Count down input cooldown
        if (input_cooldown > 0) input_cooldown <= input_cooldown - 1;
    end

    // Main control logic
    always @(posedge clk) begin
        if (reset) begin
            cursor_row_keypad <= 0;
            cursor_col_keypad <= 0;
            cursor_row_operand <= 0;
            cursor_col_operand <= 0;
            keypad_btn_pressed <= 0;
            keypad_selected_value <= 0;
            operand_btn_pressed <= 0;
            operand_selected_value <= 0;
            timer_C <= 0;
            timer_U <= 0;
            timer_D <= 0;
            timer_L <= 0;
            timer_R <= 0;
            input_cooldown <= 9'd500;
        end else begin
            // Clear single-cycle signals
            keypad_btn_pressed <= 0;
            operand_btn_pressed <= 0;

            if (!waiting_operand) begin
                // Keypad mode - respect input cooldown
                if (input_cooldown == 0) begin
                    // Up button - move up if not at top and not on checkmark
                    if (btnU && !prev_btnU && timer_U == 0) begin
                        if (cursor_row_keypad > 0 && !at_checkmark) begin
                            cursor_row_keypad <= cursor_row_keypad - 1;
                        end
                        timer_U <= 8'd200;
                    end

                    // Down button - move down if not at bottom and not on checkmark
                    if (btnD && !prev_btnD && timer_D == 0) begin
                        if (cursor_row_keypad < 2'd3 && !at_checkmark) begin
                            cursor_row_keypad <= cursor_row_keypad + 1;
                        end
                        timer_D <= 8'd200;
                    end

                    // Left button
                    if (btnL && !prev_btnL && timer_L == 0) begin
                        if (at_checkmark) begin
                            // Move from checkmark to main keypad
                            cursor_col_keypad <= 3'd2;
                        end else if (cursor_col_keypad > 0) begin
                            cursor_col_keypad <= cursor_col_keypad - 1;
                        end
                        timer_L <= 8'd200;
                    end

                    // Right button
                    if (btnR && !prev_btnR && timer_R == 0) begin
                        if (!at_checkmark) begin
                            if (cursor_col_keypad < 3'd2) begin
                                cursor_col_keypad <= cursor_col_keypad + 1;
                            end else if (cursor_col_keypad == 3'd2) begin
                                // Move to checkmark
                                cursor_col_keypad <= 3'd3;
                            end
                        end
                        timer_R <= 8'd200;
                    end

                    // Center button - selection
                    if (btnC && !prev_btnC && timer_C == 0) begin
                        keypad_btn_pressed <= 1;
                        input_cooldown <= 9'd500;
                        
                        if (at_checkmark) begin
                            keypad_selected_value <= 4'd12; // Checkmark
                        end else begin
                            // Map cursor position to keypad value
                            case(cursor_row_keypad)
                                2'd0: keypad_selected_value <= cursor_col_keypad + 4'd7; // 7,8,9
                                2'd1: keypad_selected_value <= cursor_col_keypad + 4'd4; // 4,5,6
                                2'd2: keypad_selected_value <= cursor_col_keypad + 4'd1; // 1,2,3
                                2'd3: begin
                                    case(cursor_col_keypad)
                                        2'd0: keypad_selected_value <= 4'd0;  // 0
                                        2'd1: keypad_selected_value <= 4'd10; // .
                                        2'd2: keypad_selected_value <= 4'd11; // x
                                        default: keypad_selected_value <= 4'd0;
                                    endcase
                                end
                            endcase
                        end
                        timer_C <= 8'd200;
                    end
                end
            end else begin
                // Operand mode - no input cooldown
                // Up button
                if (btnU && !prev_btnU && timer_U == 0) begin
                    if (cursor_row_operand > 0) begin
                        cursor_row_operand <= cursor_row_operand - 1;
                    end
                    timer_U <= 8'd200;
                end
            
                // Down button
                if (btnD && !prev_btnD && timer_D == 0) begin
                    if (cursor_row_operand < 2'd1) begin
                        cursor_row_operand <= cursor_row_operand + 1;
                    end
                    timer_D <= 8'd200;
                end
            
                // Left button
                if (btnL && !prev_btnL && timer_L == 0) begin
                    if (cursor_col_operand > 0) begin
                        cursor_col_operand <= cursor_col_operand - 1;
                    end
                    timer_L <= 8'd200;
                end
            
                // Right button
                if (btnR && !prev_btnR && timer_R == 0) begin
                    if (cursor_col_operand < 2'd1) begin
                        cursor_col_operand <= cursor_col_operand + 1;
                    end
                    timer_R <= 8'd200;
                end
            
                // Center button - operand selection
                if (btnC && !prev_btnC && timer_C == 0) begin
                    operand_btn_pressed <= 1;
                    // Map operand grid to values
                    case({cursor_row_operand, cursor_col_operand})
                        4'b00_00: operand_selected_value <= 2'd0; // +
                        4'b00_01: operand_selected_value <= 2'd1; // -
                        4'b01_00: operand_selected_value <= 2'd2; // ×
                        4'b01_01: operand_selected_value <= 2'd3; // ÷
                        default: operand_selected_value <= 2'd0;
                    endcase
                    timer_C <= 8'd200;
                end
            end
        end
    end

endmodule

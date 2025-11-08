`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 
// Design Name: 
// Module Name: polynomial_cursor
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: Cursor controller for polynomial mode - handles navigation for
//              keypad input, coefficient selection, and mode selection
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module polynomial_cursor(
    input clk,
    input reset,
    input btnC,
    input btnU,
    input btnD,
    input btnL,
    input btnR,
    input waiting_coeff_selection,
    input waiting_mode_selection,
    output reg [1:0] cursor_row_keypad = 0,
    output reg [2:0] cursor_col_keypad = 0,
    output reg [1:0] cursor_row_coeff = 0,
    output reg [1:0] cursor_col_coeff = 0,
    output reg [1:0] cursor_row_mode = 0,
    output reg [1:0] cursor_col_mode = 0,
    output reg keypad_btn_pressed = 0,
    output reg [3:0] keypad_selected_value = 0,
    output reg coeff_btn_pressed = 0,
    output reg [2:0] coeff_selected_index = 0,
    output reg mode_btn_pressed = 0,
    output reg mode_selected_value = 0
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

    // Flag to track if on the right column (checkmark area)
    wire on_right_col = (cursor_col_keypad == 3'd3 && !waiting_coeff_selection && !waiting_mode_selection);
    wire on_upper_button = on_right_col && (cursor_row_keypad < 2);  // Rows 0-1: coefficient selection
    wire on_lower_button = on_right_col && (cursor_row_keypad >= 2); // Rows 2-3: mode selection

    // Button handling loop
    always @ (posedge clk) begin
        if (reset) begin
            // Reset all state variables to initial values
            cursor_row_keypad <= 0;
            cursor_col_keypad <= 0;
            cursor_row_coeff <= 0;
            cursor_col_coeff <= 0;
            cursor_row_mode <= 0;
            cursor_col_mode <= 0;
            keypad_btn_pressed <= 0;
            keypad_selected_value <= 0;
            coeff_btn_pressed <= 0;
            coeff_selected_index <= 0;
            mode_btn_pressed <= 0;
            mode_selected_value <= 0;
            
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
            // Reset button pressed signals each cycle
            keypad_btn_pressed <= 0;
            coeff_btn_pressed <= 0;
            mode_btn_pressed <= 0;
        
            // Decrement debounce counters if active
            if (debounce_U > 0) debounce_U <= debounce_U - 1;
            if (debounce_D > 0) debounce_D <= debounce_D - 1;
            if (debounce_L > 0) debounce_L <= debounce_L - 1;
            if (debounce_R > 0) debounce_R <= debounce_R - 1;
            if (debounce_C > 0) debounce_C <= debounce_C - 1;

            if (waiting_mode_selection) begin
                // ===== MODE SELECTION MODE =====
                // Layout: 2x1 grid
                // Row 0: f(x)  f'(x)
                // Row 1: (empty)
                
                // Up button handling
                if (btnU && !prev_btnU && debounce_U == 0) begin
                    if (cursor_row_mode > 0) begin
                        cursor_row_mode <= cursor_row_mode - 1;
                    end
                    debounce_U <= 200;
                end
            
                // Down button handling
                if (btnD && !prev_btnD && debounce_D == 0) begin
                    if (cursor_row_mode < 1) begin  
                        cursor_row_mode <= cursor_row_mode + 1;
                    end
                    debounce_D <= 200;
                end
            
                // Left button handling
                if (btnL && !prev_btnL && debounce_L == 0) begin
                    if (cursor_col_mode > 0) begin
                        cursor_col_mode <= cursor_col_mode - 1;
                    end
                    debounce_L <= 200;
                end
            
                // Right button handling
                if (btnR && !prev_btnR && debounce_R == 0) begin
                    if (cursor_col_mode < 1) begin  
                        cursor_col_mode <= cursor_col_mode + 1;
                    end
                    debounce_R <= 200;
                end
            
                // Center button handling (selection)
                if (btnC && !prev_btnC && debounce_C == 0) begin
                    mode_btn_pressed <= 1;
                
                    // Determine selected mode based on cursor position
                    case({cursor_row_mode, cursor_col_mode})
                        4'b00_00: mode_selected_value <= 1'b0; // f(x)
                        4'b00_01: mode_selected_value <= 1'b1; // f'(x)
                        default: mode_selected_value <= 1'b0;
                    endcase
                
                    debounce_C <= 200;
                end
                
            end else if (waiting_coeff_selection) begin
                // ===== COEFFICIENT SELECTION MODE =====
                // Layout: 3x2 grid (6 coefficients: a0..a4, x)
                // Row 0: a0  a1  a2
                // Row 1: a3  a4  x
                
                // Up button handling
                if (btnU && !prev_btnU && debounce_U == 0) begin
                    if (cursor_row_coeff > 0) begin
                        cursor_row_coeff <= cursor_row_coeff - 1;
                    end
                    debounce_U <= 200;
                end
            
                // Down button handling
                if (btnD && !prev_btnD && debounce_D == 0) begin
                    if (cursor_row_coeff < 1) begin  
                        cursor_row_coeff <= cursor_row_coeff + 1;
                    end
                    debounce_D <= 200;
                end
            
                // Left button handling
                if (btnL && !prev_btnL && debounce_L == 0) begin
                    if (cursor_col_coeff > 0) begin
                        cursor_col_coeff <= cursor_col_coeff - 1;
                    end
                    debounce_L <= 200;
                end
            
                // Right button handling
                if (btnR && !prev_btnR && debounce_R == 0) begin
                    if (cursor_col_coeff < 2) begin  
                        cursor_col_coeff <= cursor_col_coeff + 1;
                    end
                    debounce_R <= 200;
                end
            
                // Center button handling (selection)
                if (btnC && !prev_btnC && debounce_C == 0) begin
                    coeff_btn_pressed <= 1;
                
                    // Determine selected coefficient based on cursor position
                    case({cursor_row_coeff, cursor_col_coeff})
                        4'b00_00: coeff_selected_index <= 3'd0; // a0
                        4'b00_01: coeff_selected_index <= 3'd1; // a1
                        4'b00_10: coeff_selected_index <= 3'd2; // a2
                        4'b01_00: coeff_selected_index <= 3'd3; // a3
                        4'b01_01: coeff_selected_index <= 3'd4; // a4
                        4'b01_10: coeff_selected_index <= 3'd5; // x
                        default: coeff_selected_index <= 3'd0;
                    endcase
                
                    debounce_C <= 200;
                end
                
            end else begin
                // ===== KEYPAD INPUT MODE =====
                // Layout: 4 rows x 4 columns
                // Cols 0-2: Number keypad
                // Col 3: Split - upper (coefficient selection), lower (mode selection)
                
                if (counter == 0) begin
                    // Up button processing
                    if (btnU && !prev_btnU && debounce_U == 0) begin
                        if (cursor_row_keypad > 0 && !on_right_col) begin
                            cursor_row_keypad <= cursor_row_keypad - 1;
                        end else if (on_right_col && cursor_row_keypad > 0) begin
                            // Allow moving up in right column
                            cursor_row_keypad <= cursor_row_keypad - 1;
                        end
                        debounce_U <= 200;
                    end

                    // Down
                    if (btnD && !prev_btnD && debounce_D == 0) begin
                        if (cursor_row_keypad < 3 && !on_right_col) begin
                            cursor_row_keypad <= cursor_row_keypad + 1;
                        end else if (on_right_col && cursor_row_keypad < 3) begin
                            // Allow moving down in right column
                            cursor_row_keypad <= cursor_row_keypad + 1;
                        end
                        debounce_D <= 200;
                    end

                    // Left
                    if (btnL && !prev_btnL && debounce_L == 0) begin
                        if (on_right_col) begin
                            // Moving left from right column goes to the main keypad
                            cursor_col_keypad <= 3'd2;
                        end else if (cursor_col_keypad > 0) begin
                            cursor_col_keypad <= cursor_col_keypad - 1;
                        end
                        debounce_L <= 200;
                    end

                    // Right
                    if (btnR && !prev_btnR && debounce_R == 0) begin
                        if (!on_right_col && cursor_col_keypad < 2) begin
                            cursor_col_keypad <= cursor_col_keypad + 1;
                        end else if (!on_right_col && cursor_col_keypad == 2) begin
                            cursor_col_keypad <= 3'd3;  // Go to right column
                        end
                        debounce_R <= 200;
                    end

                    // Center (Selection)
                    if (btnC && !prev_btnC && debounce_C == 0) begin
                        keypad_btn_pressed <= 1;
                        counter <= 500;
                        
                        if (on_upper_button) begin
                            // Upper button selected - go to coefficient selection mode
                            keypad_selected_value <= 4'd12;  // Enter for coefficient selection
                        end else if (on_lower_button) begin
                            // Lower button selected - go to mode selection
                            keypad_selected_value <= 4'd13;  // Enter for mode selection
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
                    counter <= counter - 1;
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


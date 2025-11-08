`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 20.03.2025 11:22:53
// Design Name: 
// Module Name: polynomial_table_cursor_controller
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

/*
This module is responsible for controlling cursor movement when the table mode is active.
In is_table_input_mode, the cursor will interface with polynomial_table_keypad_display to gather user input which is sent over to input_bcd_to_fp_builder_table.
The updated input value will subsequently used in computations.

In regular is_table_mode, only the up-down buttons will be active which in theory, should allow the user to scroll through input values.
*/


module polytable_select(
    input [6:0] mouse_xpos,
    input [6:0] mouse_ypos,
    input mouse_left,
    input mouse_middle,
    input clk,
    input clk_100MHz,
    input btnC,
    input btnU,
    input btnD,
    input btnL,
    input btnR,
    input is_table_mode,
    input use_mouse,
    input input_complete,
    input signed [31:0] fp_input_value,
    output reg is_table_input_mode = 0,
    output reg [1:0] cursor_row = 0,
    output reg [2:0] cursor_col = 0,
    output reg keypad_btn_pressed = 0,
    output reg [3:0] keypad_selected_value = 0,
    output reg signed [31:0] starting_x = 0,
    output reg is_dfx_mode = 0
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
    
    // Debouncing for left mouse button
    parameter DEBOUNCE_DELAY = 2000000;
    reg [21:0] counter;
    reg debounced;
    
    initial begin
        counter = 0;
        debounced = 1'b0;
        is_dfx_mode = 1'b0;
    end
    
    always @(posedge clk_100MHz) begin
        if (mouse_left == debounced) 
            counter <= 0;
        else begin
            counter <= counter + 1;
            if (counter >= DEBOUNCE_DELAY) debounced <= mouse_left;
        end
    end
    
    reg mouse_left_prev;
    initial begin 
        mouse_left_prev = 1'b0; 
    end
    
    // Waiting counter for button press delay
    reg [8:0] wait_counter = 9'd500;
    
    // Flag to track if on the right column
    wire on_right_col = (cursor_col == 3'd3 && is_table_input_mode);
    wire on_upper_button = on_right_col && (cursor_row < 2);
    wire on_lower_button = on_right_col && (cursor_row >= 2);
   
    always @ (posedge clk) begin
        if (!use_mouse) begin
            // Reset button pressed signal each cycle
            keypad_btn_pressed <= 0;

            // Decrement debounce counters
            if (debounce_U > 0) debounce_U <= debounce_U - 1;
            if (debounce_D > 0) debounce_D <= debounce_D - 1;
            if (debounce_L > 0) debounce_L <= debounce_L - 1;
            if (debounce_R > 0) debounce_R <= debounce_R - 1;
            if (debounce_C > 0) debounce_C <= debounce_C - 1;

            // Only processing buttons if in table mode
            if (is_table_mode) begin
                // Switching between table navigation mode and input mode
                if (btnC && !prev_btnC && debounce_C == 0 || mouse_middle) begin
                    debounce_C <= 200;
                    if (!is_table_input_mode) begin
                        is_table_input_mode <= 1;
                        cursor_row <= 0;
                        cursor_col <= 0;
                    end
                end

                // Cursor movement and input selection logic
                if (is_table_input_mode) begin
                    // Update starting_x when input is complete
                    if (input_complete) begin
                        starting_x <= fp_input_value;
                        is_table_input_mode <= 0;
                    end
                    
                    if (wait_counter == 0) begin
                        // Up button processing
                        if (btnU && !prev_btnU && debounce_U == 0) begin
                            if (cursor_row > 0 && !on_right_col) begin
                                cursor_row <= cursor_row - 1;
                            end else if (on_right_col && cursor_row > 0) begin
                                cursor_row <= cursor_row - 1;
                            end
                            debounce_U <= 200;
                        end

                        // Down
                        if (btnD && !prev_btnD && debounce_D == 0) begin
                            if (cursor_row < 3 && !on_right_col) begin
                                cursor_row <= cursor_row + 1;
                            end else if (on_right_col && cursor_row < 3) begin
                                cursor_row <= cursor_row + 1;
                            end
                            debounce_D <= 200;
                        end

                        // Left
                        if (btnL && !prev_btnL && debounce_L == 0) begin
                            if (on_right_col) begin
                                cursor_col <= 3'd2;
                            end else if (cursor_col > 0) begin
                                cursor_col <= cursor_col - 1;
                            end
                            debounce_L <= 200;
                        end

                        // Right
                        if (btnR && !prev_btnR && debounce_R == 0) begin
                            if (!on_right_col && cursor_col < 2) begin
                                cursor_col <= cursor_col + 1;
                            end else if (!on_right_col && cursor_col == 2) begin
                                cursor_col <= 3'd3;
                            end
                            debounce_R <= 200;
                        end

                        // Center button (Selection)
                        if (btnC && !prev_btnC && debounce_C == 0) begin
                            debounce_C <= 200;
                            keypad_btn_pressed <= 1;
                            wait_counter <= 500;
                            
                            if (on_upper_button) begin
                                // Upper button: FX mode
                                is_dfx_mode <= 1'b0;
                                keypad_selected_value <= 4'd12;
                            end else if (on_lower_button) begin
                                // Lower button: DFX mode
                                is_dfx_mode <= 1'b1;
                                keypad_selected_value <= 4'd12;
                            end else begin
                                // Number keypad - exact position mapping with proper bit widths
                                case({cursor_row, cursor_col})
                                    // Row 0: buttons 1, 2, 3
                                    5'b00_000: keypad_selected_value <= 4'd1;
                                    5'b00_001: keypad_selected_value <= 4'd2;
                                    5'b00_010: keypad_selected_value <= 4'd3;
                                    // Row 1: buttons 4, 5, 6
                                    5'b01_000: keypad_selected_value <= 4'd4;
                                    5'b01_001: keypad_selected_value <= 4'd5;
                                    5'b01_010: keypad_selected_value <= 4'd6;
                                    // Row 2: buttons 7, 8, 9
                                    5'b10_000: keypad_selected_value <= 4'd7;
                                    5'b10_001: keypad_selected_value <= 4'd8;
                                    5'b10_010: keypad_selected_value <= 4'd9;
                                    // Row 3: buttons 0, ., X
                                    5'b11_000: keypad_selected_value <= 4'd0;
                                    5'b11_001: keypad_selected_value <= 4'd10; // Decimal
                                    5'b11_010: keypad_selected_value <= 4'd11; // Backspace
                                    default: keypad_selected_value <= 4'd0;
                                endcase
                            end
                        end
                    end else begin
                        wait_counter <= wait_counter - 1;
                    end
                end else begin
                    // Navigation Mode - scroll through table
                    if (btnU && !prev_btnU && debounce_U == 0) begin
                        debounce_U <= 200;
                        starting_x <= starting_x + 32'h00010000; // Add 1.0
                    end
                    
                    if (btnD && !prev_btnD && debounce_D == 0) begin
                        debounce_D <= 200;
                        starting_x <= starting_x - 32'h00010000; // Subtract 1.0
                    end
                end
            end else begin
                starting_x <= 0;
                is_table_input_mode <= 0;
            end

            // Update previous button states
            prev_btnU <= btnU;
            prev_btnD <= btnD;
            prev_btnL <= btnL;
            prev_btnR <= btnR;
            prev_btnC <= btnC;
        end else if (use_mouse) begin
            // Mouse mode (simplified for now)
            keypad_btn_pressed <= 0;
            if (debounce_C > 0) debounce_C <= debounce_C - 1;
            
            if (btnC && !prev_btnC && debounce_C == 0 || mouse_middle) begin
                debounce_C <= 200;
                if (!is_table_input_mode) begin
                    is_table_input_mode <= 1;
                    cursor_row <= 0;
                    cursor_col <= 0;
                end
            end
            
            if (is_table_input_mode) begin
                if (input_complete) begin
                    starting_x <= fp_input_value;
                    is_table_input_mode <= 0;
                end
                
                // Mouse position mapping (adjust for new layout)
                if (mouse_xpos >= 72) begin
                    cursor_col <= 3;
                end else if (mouse_xpos >= 50) begin
                    cursor_col <= 2;
                end else if (mouse_xpos >= 26) begin
                    cursor_col <= 1;
                end else begin
                    cursor_col <= 0;
                end
                
                if (mouse_ypos >= 49) begin
                    cursor_row <= 3;
                end else if (mouse_ypos >= 33) begin
                    cursor_row <= 2;
                end else if (mouse_ypos >= 17) begin
                    cursor_row <= 1;
                end else begin
                    cursor_row <= 0;
                end
                
                if (debounced && !mouse_left_prev) begin
                    keypad_btn_pressed <= 1;
                    if (on_upper_button) begin
                        is_dfx_mode <= 1'b0;
                        keypad_selected_value <= 4'd12;
                    end else if (on_lower_button) begin
                        is_dfx_mode <= 1'b1;
                        keypad_selected_value <= 4'd12;
                    end else begin
                        // Number keypad - exact position mapping with proper bit widths
                        case({cursor_row, cursor_col})
                            // Row 0: buttons 1, 2, 3
                            5'b00_000: keypad_selected_value <= 4'd1;
                            5'b00_001: keypad_selected_value <= 4'd2;
                            5'b00_010: keypad_selected_value <= 4'd3;
                            // Row 1: buttons 4, 5, 6
                            5'b01_000: keypad_selected_value <= 4'd4;
                            5'b01_001: keypad_selected_value <= 4'd5;
                            5'b01_010: keypad_selected_value <= 4'd6;
                            // Row 2: buttons 7, 8, 9
                            5'b10_000: keypad_selected_value <= 4'd7;
                            5'b10_001: keypad_selected_value <= 4'd8;
                            5'b10_010: keypad_selected_value <= 4'd9;
                            // Row 3: buttons 0, ., X
                            5'b11_000: keypad_selected_value <= 4'd0;
                            5'b11_001: keypad_selected_value <= 4'd10;
                            5'b11_010: keypad_selected_value <= 4'd11;
                            default: keypad_btn_pressed <= 0;
                        endcase
                    end
                end
            end
            
            prev_btnC <= btnC;
            mouse_left_prev <= debounced;
        end
    end
endmodule
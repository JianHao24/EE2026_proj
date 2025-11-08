`timescale 1ns / 1ps

module polytable_select(
    input clk,
    input clk_100MHz,
    input btnC,
    input btnU,
    input btnD,
    input btnL,
    input btnR,
    input is_table_mode,

    // From input_bcd_to_fp_builder_table
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
    
    // Default to FX mode
    initial begin 
        is_dfx_mode = 1'b0;
    end
    
    // Flag to track if on the checkmark
    wire on_checkmark = (cursor_col == 3'd3 && is_table_input_mode);
   
    always @ (posedge clk) begin
        // Resetting button pressed on each cycle
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
            if (btnC && !prev_btnC && debounce_C == 0) begin
                debounce_C <= 200;

                // Transition to table input mode
                if (!is_table_input_mode) begin
                    is_table_input_mode <= 1;
                    
                    // Resetting cursor positions
                    cursor_row <= 0;
                    cursor_col <= 0;
                end
            end

            // Cursor movement and input selection logic
            if (is_table_input_mode) begin
                
                // Updating starting_x when input is complete
                if (input_complete) begin
                    starting_x <= fp_input_value;
                    is_table_input_mode <= 0;
                end
                
                // Up button
                if (btnU && !prev_btnU && debounce_U == 0) begin
                    debounce_U <= 200;

                    if (!on_checkmark) begin
                        if (cursor_row > 0) begin
                            cursor_row <= cursor_row - 1;
                        end
                        else begin
                            // Wrap around
                            cursor_row <= 3;
                        end
                    end
                end

                // Down button
                if (btnD && !prev_btnD && debounce_D == 0) begin
                    debounce_D <= 200;

                    if (!on_checkmark) begin
                        if (cursor_row < 3) begin
                            cursor_row <= cursor_row + 1;
                        end
                        else begin
                            cursor_row <= 0;
                        end
                    end
                end

                // Left button
                if (btnL && !prev_btnL && debounce_L == 0) begin
                    debounce_L <= 200;

                    if (on_checkmark) begin
                        cursor_col <= 2;
                    end
                    else if (cursor_col > 0) begin
                        cursor_col <= cursor_col - 1;
                    end
                    else begin
                        cursor_col <= on_checkmark ? 2 : 3;
                    end
                end

                // Right button
                if (btnR && !prev_btnR && debounce_R == 0) begin
                    debounce_R <= 200;

                    if (on_checkmark) begin
                        cursor_col <= 0;
                    end
                    else if (cursor_col < 4) begin
                        cursor_col <= cursor_col + 1;
                    end
                end

                // Center button (input selection)
                if (btnC && !prev_btnC && debounce_C == 0) begin
                    debounce_C <= 200;
                    keypad_btn_pressed <= 1;

                    // If center pressed while on the checkmark area, latch the
                    // derivative mode (top half -> FX, bottom half -> DFX).
                    if (on_checkmark) begin
                        is_dfx_mode <= (cursor_row >= 2) ? 1'b1 : 1'b0;
                    end
                    else begin
                        // Determine selected value based on cursor position
                        case ({cursor_row, cursor_col})
                            {2'd0, 3'd0}: keypad_selected_value <= 4'd7; // 7
                            {2'd0, 3'd1}: keypad_selected_value <= 4'd8; // 8
                            {2'd0, 3'd2}: keypad_selected_value <= 4'd9; // 9
                            {2'd1, 3'd0}: keypad_selected_value <= 4'd4; // 4
                            {2'd1, 3'd1}: keypad_selected_value <= 4'd5; // 5
                            {2'd1, 3'd2}: keypad_selected_value <= 4'd6; // 6
                            {2'd2, 3'd0}: keypad_selected_value <= 4'd1; // 1
                            {2'd2, 3'd1}: keypad_selected_value <= 4'd2; // 2
                            {2'd2, 3'd2}: keypad_selected_value <= 4'd3; // 3
                            {2'd3, 3'd0}: keypad_selected_value <= 4'd0; // 0
                            {2'd3, 3'd1}: keypad_selected_value <= 4'd10; // Decimal point
                            {2'd3, 3'd2}: keypad_selected_value <= 4'd11; // Negative sign
                            default: keypad_btn_pressed <= 0; // Invalid position
                        endcase
                    end
                end
            end
            else begin
                // Navigation Mode
                if (btnU && !prev_btnU && debounce_U == 0) begin
                    debounce_U <= 200;
                    starting_x <= starting_x + 32'h00010000; // Add 1.0 in fixed point
                end
                
                if (btnD && !prev_btnD && debounce_D == 0) begin
                    debounce_D <= 200;
                    starting_x <= starting_x - 32'h00010000; // Subtract 1.0 in fixed point
                end
            end
        end
        else begin
            starting_x <= 0;
            is_table_input_mode <= 0;
        end

        // Update previous button states
        prev_btnU <= btnU;
        prev_btnD <= btnD;
        prev_btnL <= btnL;
        prev_btnR <= btnR;
        prev_btnC <= btnC;
    end
endmodule
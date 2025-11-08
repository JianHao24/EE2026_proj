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
    
    // Waiting counter for button press delay
    reg [8:0] wait_counter = 9'd500;
    
    // Flag to track if on the right column
    wire on_right_col = (cursor_col == 3'd3 && is_table_input_mode);
    wire on_upper_button = on_right_col && (cursor_row < 2);
    wire on_lower_button = on_right_col && (cursor_row >= 2);
   
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
                if (btnC && !prev_btnC && debounce_C == 0 || mouse_middle) begin
                    debounce_C <= 200;
                    if (!is_table_input_mode) begin
                        is_table_input_mode <= 1;
                        cursor_row <= 0;
                        cursor_col <= 0;
                    end
                end

            // Switching between table navigation mode and input mode
            if (btnC && !prev_btnC && debounce_C == 0) begin
                debounce_C <= 200;
                if (!is_table_input_mode) begin
                    is_table_input_mode <= 1;
                    cursor_row <= 0;
                    cursor_col <= 0;
                end
            end
            
            if (is_table_input_mode) begin
                
                // Updating starting_x when input is complete
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

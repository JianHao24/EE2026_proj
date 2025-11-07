
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11/06/2025 09:26:25 PM
// Design Name: 
// Module Name: arithmetic_mode
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


`timescale 1ns / 1ps

module arithmetic_module(
    // Clock inputs
    input clk_6p25MHz,
    input clk_1kHz,

    // Button inputs
    input btnC, btnU, btnD, btnL, btnR,

    // Control flags
    input reset,
    input is_arithmetic_mode,

    // Mouse inputs (for future compatibility)
    input [11:0] xpos,
    input [11:0] ypos,
    input use_mouse,
    input mouse_left,
    input mouse_middle,

    // OLED outputs
    input [12:0] one_pixel_index,
    input [12:0] two_pixel_index,
    output [15:0] one_oled_data,
    output [15:0] two_oled_data,

    // Status outputs
    output overflow_flag,
    output div_by_zero_flag
);

    // Cursor controller signals
    wire [1:0] cursor_row_keypad;
    wire [2:0] cursor_col_keypad;
    wire [1:0] cursor_row_operand;
    wire [1:0] cursor_col_operand;
    wire [1:0] cursor_row_trig;
    wire [1:0] cursor_col_trig;
    
    wire keypad_btn_pressed;
    wire [3:0] keypad_selected_value;
    wire operand_btn_pressed;
    wire [1:0] operand_selected_value;
    wire trig_btn_pressed;
    wire [1:0] trig_selected_value;
    
    // Mode control
    reg waiting_trig;
    
    // Input system signals
    wire has_decimal;
    wire has_negative;
    wire [3:0] input_index;
    wire signed [31:0] fp_value;
    wire [31:0] bcd_value;
    wire input_complete;
    wire [3:0] decimal_pos;
    
    // Calculator engine signals - BINARY (basic operations)
    wire signed [31:0] binary_result;
    wire binary_result_valid;
    wire binary_overflow;
    wire div_by_zero;
    wire waiting_operand;
    wire [1:0] current_operation;
    
    // Calculator engine signals - TRIG
    wire signed [31:0] trig_result;
    wire trig_result_valid;
    wire trig_overflow;
    
    // Combined result signals (mux between binary and trig)
    wire signed [31:0] result;
    wire result_valid;
    wire overflow;
    
    reg show_result;
    reg trig_computing;  // Track when trig calculation is in progress
    reg force_operand_mode;  // Force calculator into operand mode when button 12 clicked
    reg pending_input;   // Track if there's an input waiting to be processed
    reg signed [31:0] latched_input;  // Store the input value
    
    // Multiplex between binary and trig results, or show latched input if pending
    assign result = trig_result_valid ? trig_result : 
                    binary_result_valid ? binary_result :
                    pending_input ? latched_input : binary_result;
    assign result_valid = trig_result_valid | binary_result_valid;
    assign overflow = trig_result_valid ? trig_overflow : binary_overflow;
    
    // Assign status outputs
    assign overflow_flag = overflow;
    assign div_by_zero_flag = div_by_zero;
    
    // Mode control logic
    // Track if we should show result (after trig or binary operation)
    
       always @(posedge clk_1kHz) begin
        if (reset || !is_arithmetic_mode) begin
            waiting_trig <= 0;
            show_result <= 0;
            trig_computing <= 0;
            force_operand_mode <= 0;
            pending_input <= 0;
            latched_input <= 0;
        end else begin
            // Latch input when it completes OR when trig button is pressed
            if ((input_complete && !waiting_operand && !waiting_trig) || 
                (keypad_btn_pressed && keypad_selected_value == 4'd13 && !pending_input)) begin
                pending_input <= 1;
                latched_input <= fp_value;
            end
            
            // Toggle between modes based on keypad input
            if (keypad_btn_pressed) begin
                if (keypad_selected_value == 4'd12) begin
                    // User clicked operations button - go to operand mode
                    waiting_trig <= 0;
                    show_result <= 0;
                    trig_computing <= 0;
                    force_operand_mode <= 1;  // Signal calculator to enter operand mode
                    // Keep pending_input so calculator can use it
                end
                else if (keypad_selected_value == 4'd13) begin
                    // User clicked trig button - go to trig mode
                    waiting_trig <= 1;
                    show_result <= 1;  // KEEP SHOWING INPUT VALUE as result until trig selected
                    trig_computing <= 0;
                    force_operand_mode <= 0;
                    // DON'T clear pending_input - trig needs the value
                end
                else if (keypad_selected_value <= 4'd11) begin
                    // User started typing a digit, decimal, or backspace
                    // Clear result display to show new input
                    show_result <= 0;
                    trig_computing <= 0;
                    waiting_trig <= 0;
                    force_operand_mode <= 0;
                    pending_input <= 0;  // Clear pending input if user starts new number
                end
            end
            
            // Clear pending input when it's consumed by calculator
            if (force_operand_mode && pending_input) begin
                pending_input <= 0;
            end
            
            // When trig function is selected, start computing
            if (trig_btn_pressed) begin
                trig_computing <= 1;  // Mark that we're computing
                waiting_trig <= 0;    // EXIT trig mode immediately to show result screen
                show_result <= 1;     // Show result (will update when valid)
            end
            
            // When trig result is ready, keep showing result
            if (trig_result_valid && trig_computing) begin
                show_result <= 1;     // Keep showing the result
                trig_computing <= 0;  // Done computing
                pending_input <= 0;   // Clear pending input after trig operation
            end
            
            // Exit operand mode when operation is selected
            if (operand_btn_pressed) begin
                show_result <= 0;  // Will show result after next number + operation
                force_operand_mode <= 0;  // Clear the force flag
            end
            
            // When binary result is ready, show it
            if (binary_result_valid) begin
                show_result <= 1;
            end
        end
    end

    // ===== CURSOR CONTROLLER =====
    arithmetic_cursor cursor_ctrl(
        .clk(clk_1kHz),
        .reset(reset || !is_arithmetic_mode),
        .btnC(is_arithmetic_mode ? btnC : 1'b0),
        .btnU(is_arithmetic_mode ? btnU : 1'b0),
        .btnD(is_arithmetic_mode ? btnD : 1'b0),
        .btnL(is_arithmetic_mode ? btnL : 1'b0),
        .btnR(is_arithmetic_mode ? btnR : 1'b0),
        .waiting_operand(waiting_operand),
        .waiting_trig(waiting_trig),
        .cursor_row_keypad(cursor_row_keypad),
        .cursor_col_keypad(cursor_col_keypad),
        .cursor_row_operand(cursor_row_operand),
        .cursor_col_operand(cursor_col_operand),
        .cursor_row_trig(cursor_row_trig),
        .cursor_col_trig(cursor_col_trig),
        .keypad_btn_pressed(keypad_btn_pressed),
        .keypad_selected_value(keypad_selected_value),
        .operand_btn_pressed(operand_btn_pressed),
        .operand_selected_value(operand_selected_value),
        .trig_btn_pressed(trig_btn_pressed),
        .trig_selected_value(trig_selected_value)
    );

    // ===== INPUT SYSTEM =====
    bcd_to_fp_input_system #(
        .DIGIT_CAPACITY(8),
        .FIXED_FRAC_BITS(16)
    ) input_builder(
        .clk(clk_1kHz),
        .reset(reset || !is_arithmetic_mode),
        .keypad_btn_pressed(keypad_btn_pressed),
        .selected_keypad_value(keypad_selected_value),
        .is_active_mode(!waiting_operand && !waiting_trig && is_arithmetic_mode),
        .enable_negative(1'b0),
        .enable_backspace(1'b1),
        .has_decimal(has_decimal),
        .has_negative(has_negative),
        .input_index(input_index),
        .fp_value(fp_value),
        .bcd_value(bcd_value),
        .input_complete(input_complete),
        .decimal_pos(decimal_pos)
    );

    // ===== CALCULATOR ENGINE =====
    // Send input to calculator when user explicitly enters operand mode or during ongoing calculation
    wire calc_input_valid = (force_operand_mode && pending_input) || (waiting_operand && input_complete);
    wire signed [31:0] calc_input = pending_input ? latched_input : fp_value;
    
    basic_calculator_engine calc_engine(
        .clk(clk_1kHz),
        .rst(reset || !is_arithmetic_mode),
        .input_valid(calc_input_valid),
        .input_val(calc_input),
        .op_valid(operand_btn_pressed),
        .op_sel(operand_selected_value),
        .result(binary_result),
        .result_valid(binary_result_valid),
        .overflow(binary_overflow),
        .div_by_zero(div_by_zero),
        .is_operand_mode(waiting_operand),
        .current_operation(current_operation)
    );
    
    // ===== TRIG CALCULATOR =====
    // Use latched input if available, otherwise use fp_value
    wire signed [31:0] trig_input = pending_input ? latched_input : fp_value;
    
    trig_calculator #(
        .FIXED_FRAC_BITS(16)
    ) trig_calc(
        .clk(clk_1kHz),
        .rst(reset || !is_arithmetic_mode),
        .trig_valid(trig_btn_pressed),
        .trig_sel(trig_selected_value),
        .input_val(trig_input),
        .result(trig_result),
        .result_valid(trig_result_valid),
        .overflow(trig_overflow)
    );

    // ===== DISPLAY CONTROLLER (First OLED) =====
    arithmetic_display_selector display_selector(
        .clk(clk_6p25MHz),
        .pixel_index(one_pixel_index),
        .cursor_row_keypad(cursor_row_keypad),
        .cursor_col_keypad(cursor_col_keypad),
        .cursor_row_operand(cursor_row_operand),
        .cursor_col_operand(cursor_col_operand),
        .cursor_row_trig(cursor_row_trig),
        .cursor_col_trig(cursor_col_trig),
        .has_decimal(has_decimal),
        .waiting_operand(waiting_operand),
        .waiting_trig(waiting_trig),
        .oled_data(one_oled_data)
    );

    // ===== TEXT DISPLAY (Second OLED) =====
    // Show result when: show_result is high, waiting for operand, or in trig mode
    // This ensures we don't try to show input when bcd_value is cleared during trig selection
arithmetic_text_selector text_selector(
        .clk(clk_6p25MHz),
        .pixel_index(two_pixel_index),
        .computed_result(result),
        .waiting_operand(show_result || waiting_operand),
        .waiting_trig(waiting_trig), 
        .bcd_value(bcd_value),
        .decimal_pos(decimal_pos),
        .input_index(input_index),
        .has_decimal(has_decimal),
        .oled_data(two_oled_data)
    );

endmodule

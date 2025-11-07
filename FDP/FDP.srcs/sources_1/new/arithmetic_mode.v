
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
    
    // -----------------------------
    // Sampled (1-cycle delayed) versions of trig signals
    reg sampled_trig_btn_pressed = 1'b0;
    reg [1:0] sampled_trig_selected_value = 2'd0;
    reg trig_request = 1'b0;
    // -----------------------------
    
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
    
    // Combined result signals
    wire signed [31:0] result;
    wire result_valid;
    wire overflow;
    
    reg show_result;
    reg trig_computing;
    reg force_operand_mode;
    reg pending_input;
    reg signed [31:0] latched_input;
    reg signed [31:0] immediate_trig_result = 32'sd0;
    reg immediate_trig_valid = 1'b0;
    
    reg dbg_sampled_trig_pressed = 1'b0;
    reg [1:0] dbg_sampled_trig_sel = 2'd0;
    
    assign result = immediate_trig_valid ? immediate_trig_result :
                    trig_result_valid ? trig_result :
                    binary_result_valid ? binary_result :
                    pending_input ? latched_input :
                    binary_result;
    
    assign result_valid = immediate_trig_valid | trig_result_valid | binary_result_valid;
    assign overflow = trig_result_valid ? trig_overflow : binary_overflow;
    
    assign overflow_flag = overflow;
    assign div_by_zero_flag = div_by_zero;
    
    always @(posedge clk_1kHz) begin
        sampled_trig_btn_pressed <= trig_btn_pressed;
        sampled_trig_selected_value <= trig_selected_value;
    end
    
    always @(posedge clk_1kHz) begin
        if (reset || !is_arithmetic_mode) begin
            waiting_trig <= 0;
            show_result <= 0;
            trig_computing <= 0;
            force_operand_mode <= 0;
            pending_input <= 0;
            latched_input <= 0;
            trig_request <= 0;
        end else begin
            trig_request <= 1'b0;

            if ((input_complete && !waiting_operand && !waiting_trig) || 
                (keypad_btn_pressed && keypad_selected_value == 4'd13 && !pending_input)) begin
                pending_input <= 1;
                latched_input <= fp_value;
            end
            
            if (keypad_btn_pressed) begin
                if (keypad_selected_value == 4'd12) begin
                    waiting_trig <= 0;
                    show_result <= 0;
                    trig_computing <= 0;
                    force_operand_mode <= 1;
                end
                else if (keypad_selected_value == 4'd13) begin
                    waiting_trig <= 1;
                    show_result <= 1;
                    trig_computing <= 0;
                    force_operand_mode <= 0;
                end
                else if (keypad_selected_value <= 4'd11) begin
                    show_result <= 0;
                    trig_computing <= 0;
                    waiting_trig <= 0;
                    force_operand_mode <= 0;
                    pending_input <= 0;
                end
            end
            
            if (force_operand_mode && pending_input)
                pending_input <= 0;
            
            if (sampled_trig_btn_pressed) begin
                case (sampled_trig_selected_value)
                    2'd0: latched_input <= 32'sd65536;   // sin -> 1.0
                    2'd1: latched_input <= 32'sd131072;  // cos -> 2.0
                    2'd2: latched_input <= 32'sd196608;  // tan -> 3.0
                    default: latched_input <= latched_input;
                endcase
            
                pending_input <= 1;
                trig_request <= 1'b1;
            
                case (sampled_trig_selected_value)
                    2'd0: immediate_trig_result <= 32'sd65536;
                    2'd1: immediate_trig_result <= 32'sd131072;
                    2'd2: immediate_trig_result <= 32'sd196608;
                    default: immediate_trig_result <= 32'sd0;
                endcase
                immediate_trig_valid <= 1'b1;
            
                dbg_sampled_trig_pressed <= 1'b1;
                dbg_sampled_trig_sel <= sampled_trig_selected_value;
            
                waiting_trig <= 0;
                show_result <= 1;
            end else begin
                dbg_sampled_trig_pressed <= 1'b0;
                immediate_trig_valid <= 1'b0;
            end
            
            if (trig_result_valid && trig_computing) begin
                show_result <= 1;
                trig_computing <= 0;
                pending_input <= 0;
            end
            
            if (trig_request)
                trig_computing <= 1;

            if (operand_btn_pressed) begin
                show_result <= 0;
                force_operand_mode <= 0;
            end
            
            if (binary_result_valid)
                show_result <= 1;
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
        // FIX: deactivate input FSM while trig menu is active
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
    wire signed [31:0] trig_input = pending_input ? latched_input : fp_value;
    
    trig_calculator trig_calc(
        .clk(clk_1kHz),
        .rst(reset),
        .trig_valid(trig_request),
        .trig_sel(sampled_trig_selected_value),
        .input_val(latched_input),
        .result(trig_result),
        .result_valid(trig_result_valid),
        .overflow(trig_overflow)
    );

    // ===== DISPLAY CONTROLLER =====
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

    // ===== TEXT DISPLAY =====
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





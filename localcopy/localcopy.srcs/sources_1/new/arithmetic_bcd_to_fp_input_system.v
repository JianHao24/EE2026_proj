`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10/19/2025 06:29:25 PM
// Design Name: 
// Module Name: arithmetic_bcd_to_fp_input_system
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



module arithmetic_bcd_to_fp_input_system #(
    parameter DIGIT_CAPACITY = 8,      // number of input digits supported
    parameter FIXED_FRAC_BITS = 16     // fixed-point fractional precision
)(
    input wire clk,
    input wire reset,
    input wire keypad_btn_pressed,     // keypad press event
    input wire [3:0] selected_keypad_value, // keypad value input
    input wire is_active_mode,         // active mode flag
    input wire enable_negative,        // enable negative input
    input wire enable_backspace,       // enable backspace key
    output wire has_decimal,           // decimal flag output
    output wire has_negative,          // sign flag output
    output wire [3:0] input_index,     // number of entered characters
    output wire [31:0] bcd_value,      // packed BCD output
    output wire [3:0] decimal_pos,     // decimal point position
    output reg signed [31:0] fp_value, // final fixed-point result
    output reg input_complete          // input completion flag
);
    
    wire system_enable = !reset; // active-low reset handling
    
    // Internal key translation signals
    reg [3:0] internal_key_code;  // internal code for processing
    reg internal_key_valid;       // flag to mark valid key press
    
    // External keypad key mappings
    localparam EXT_DECIMAL   = 4'd10;
    localparam EXT_SPECIAL   = 4'd11;
    localparam EXT_CHECKMARK = 4'd12;
    
    // Internal key mappings
    localparam INT_DECIMAL   = 4'd10;
    localparam INT_BACKSPACE = 4'd11;
    localparam INT_ENTER     = 4'd12;
    localparam INT_NEGATIVE  = 4'd13;
    
    // Key remapping logic for keypad input
    always @(*) begin
        internal_key_valid = keypad_btn_pressed;
        internal_key_code  = selected_keypad_value;
        
        if (selected_keypad_value == EXT_SPECIAL) begin
            if (enable_backspace)
                internal_key_code = INT_BACKSPACE; // use as backspace
            else if (enable_negative)
                internal_key_code = INT_NEGATIVE;  // use as negative
            else
                internal_key_valid = 0;            // ignore if both disabled
        end
        else if (selected_keypad_value == EXT_CHECKMARK)
            internal_key_code = INT_ENTER;          // map to enter
        else if (selected_keypad_value == EXT_DECIMAL)
            internal_key_code = INT_DECIMAL;        // map to decimal
        // digits 0-9 remain unchanged
    end
    
    // Event data wires
    wire [DIGIT_CAPACITY*4-1:0] event_digit_data; // packed digits
    wire [3:0] event_char_count;                  // number of characters
    wire event_sign_flag;                         // sign present flag
    wire event_dot_flag;                          // decimal point flag
    wire [3:0] event_dot_pos;                     // decimal index
    wire event_submission;                        // enter key signal
    
    // Evaluation output wires
    wire signed [31:0] eval_result; // fixed-point evaluation result
    wire eval_complete;             // evaluation done flag
    
    // Digit input handler
    digit_manager #(
        .BUFFER_SIZE(DIGIT_CAPACITY)
    ) event_dispatcher (
        .clk(clk),
        .rst_n(system_enable && is_active_mode), // reset if inactive
        .active(is_active_mode),
        .cmd_valid(internal_key_valid),
        .cmd_type(internal_key_code),
        .enable_backspace_key(enable_backspace),
        .enable_negative_key(enable_negative),
        .packed_digits(event_digit_data),
        .total_chars(event_char_count),
        .sign_present(event_sign_flag),
        .dot_present(event_dot_flag),
        .dot_location(event_dot_pos),
        .submit_ready(event_submission)
    );
    
    // Fixed-point evaluator
    horner_fixedpoint_evaluator #(
        .FRAC_WIDTH(FIXED_FRAC_BITS),
        .MAX_VALUE(32767)
    ) event_processor (
        .clk(clk),
        .rst_n(system_enable),
        .trigger(event_submission),
        .digit_stream(event_digit_data),
        .num_chars(event_char_count),
        .has_sign(event_sign_flag),
        .has_dot(event_dot_flag),
        .dot_idx(event_dot_pos),
        .result_fp(eval_result),
        .ready(eval_complete)
    );
    
    // Capture evaluated result
    always @(posedge clk or negedge system_enable) begin
        if (!system_enable) begin
            fp_value <= 0;           // clear output
            input_complete <= 0;     // reset completion flag
        end else begin
            if (eval_complete) begin
                fp_value <= eval_result; // latch final result
                input_complete <= 1;     // mark as complete
            end else begin
                input_complete <= 0;     // not ready yet
            end
        end
    end
    
    // Output wiring
    assign has_decimal  = event_dot_flag;
    assign has_negative = event_sign_flag;
    assign input_index  = event_char_count;
    assign decimal_pos  = event_dot_pos;
    assign bcd_value    = event_digit_data;

endmodule

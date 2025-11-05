`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10/19/2025 06:28:06 PM
// Design Name: 
// Module Name: horner_fixedpoint_evaluator
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

// Converts a packed digit stream (0-9, optional sign/dot) into
// a signed fixed-point Q16.16 value using a Horner-style algorithm.

module horner_fixedpoint_evaluator #(
    parameter FRAC_WIDTH = 16, // fractional precision (Q16.16 default)
    parameter MAX_VALUE = 32767 // max representable integer before saturation
)(
    input  wire clk,  // system clock
    input  wire rst_n,  // active-low asynchronous reset
    input  wire trigger,  // starts evaluation process
    input  wire [31:0] digit_stream, // packed 8 digits (4 bits each)
    input  wire [3:0] num_chars, // total characters (digits + dot + sign)
    input  wire has_sign, // indicates presence of sign
    input  wire has_dot, // indicates presence of decimal point
    input  wire [3:0] dot_idx, // index of decimal point
    output reg  signed [31:0] result_fp, // final fixed-point result
    output reg  ready  // high when result is valid
);
    // FSM states for Horner evaluation
    localparam [1:0]
        WAIT      = 2'd0, 
        EVALUATE  = 2'd1,
        FINALIZE  = 2'd2;

    reg [1:0] phase; // FSM phase tracker
    reg [31:0] value_accum; // running accumulation of fixed-point value
    reg [3:0] position; // current digit position
    reg [3:0] scale_factor;
    reg [31:0] divisor;
    reg signed [31:0] temp_result; // temporary result before sign/saturation

    // Extract current 4-bit digit based on position
    wire [3:0] current_digit = digit_stream[position*4 +: 4];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            phase        <= WAIT;        // reset to wait state
            value_accum  <= 0;           // clear accumulator
            position     <= 0;           // reset index
            scale_factor <= 0;           // clear scaling factor
            divisor      <= 1;           // reset fractional divisor
            result_fp    <= 0;           // clear output
            ready        <= 0;           // clear ready
            temp_result  <= 0;           // clear temp
        end else begin
            case (phase)
                WAIT: begin
                    ready <= 0; // clear ready each cycle
                    if (trigger) begin
                        phase        <= EVALUATE;                 // start evaluating
                        value_accum  <= 0;                        // reset accumulator
                        position     <= has_sign ? 1 : 0;         // skip sign if present
                        scale_factor <= 0;
                        divisor      <= 1;                        // reset fractional divisor
                    end
                end

                EVALUATE: begin
                    if (position < num_chars) begin
                        if (has_dot && position == dot_idx) begin
                            value_accum <= value_accum << FRAC_WIDTH; // shift integer to Q format
                            position    <= position + 1;              // skip decimal point
                            divisor     <= 10;                        // set initial fractional divisor
                        end else if (has_dot && position > dot_idx) begin
                            value_accum <= value_accum + ((current_digit << FRAC_WIDTH) / divisor); // add fractional part
                            divisor     <= divisor * 10;              // increase divisor
                            position    <= position + 1;              // move to next char
                        end else begin
                            value_accum <= value_accum * 10 + current_digit; // accumulate integer part
                            position    <= position + 1;
                        end
                    end else begin
                        if (!has_dot)
                            value_accum <= value_accum << FRAC_WIDTH; // convert integer-only to Q format
                        phase <= FINALIZE; // move to finalize stage
                    end
                end

                FINALIZE: begin
                    temp_result = value_accum; // copy to temp
                    if (temp_result > (MAX_VALUE << FRAC_WIDTH))
                        temp_result = (MAX_VALUE << FRAC_WIDTH); // saturate

                    if (has_sign)
                        result_fp <= -temp_result; // apply negative sign
                    else
                        result_fp <= temp_result;  // keep positive

                    ready <= 1;     // signal done
                    phase <= WAIT;  // return to idle
                end
            endcase
        end
    end
endmodule

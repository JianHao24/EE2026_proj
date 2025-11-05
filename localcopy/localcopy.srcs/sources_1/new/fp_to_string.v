`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 06.11.2025 00:40:43
// Design Name: 
// Module Name: fp_to_string
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


module fp_to_string(
    input clk,
    input start_conversion,
    input signed [31:0] fp_value,
    output reg conversion_done,
    output reg [47:0] result
);
    
    // FSM states
    localparam [2:0] 
        S_IDLE      = 3'd0,
        S_PARSE     = 3'd1,
        S_INT_PROC  = 3'd2,
        S_FRAC_PROC = 3'd3,
        S_BUILD     = 3'd4,
        S_COMPLETE  = 3'd5;
    
    reg [2:0] state;
    reg [15:0] divisor;
    
    // Display encoding
    localparam [5:0] CHAR_NEG = 6'd11, CHAR_DOT = 6'd14, CHAR_SPACE = 6'd63;
    
    // Data path registers
    reg neg_flag;
    reg [15:0] int_val, frac_val;
    reg [15:0] temp_div;
    
    // Digit storage
    reg [3:0] digit_mem [0:7];
    
    // Iteration control
    reg [3:0] pos;              // Current position/index
    reg [2:0] digit_lim;        // Integer digit boundary
    reg [1:0] phase;            // Sub-state within major state
    
    
    always @(posedge clk) begin
        case (state)
            S_IDLE: begin
                conversion_done <= 1'b0;
                if (start_conversion) begin
                    pos <= 4'd0;
                    digit_lim <= 3'd0;
                    phase <= 2'd0;
                    state <= S_PARSE;
                end
            end
            
            S_PARSE: begin
                // Extract components in single cycle
                neg_flag <= fp_value[31];
                
                // Get absolute value and extract integer part
                if (fp_value[31]) begin
                    if (fp_value == 32'h80000000) begin
                        int_val <= 16'h8000;
                        frac_val <= 16'd0;
                    end else begin
                        int_val <= ((-fp_value) >> 16) & 16'hFFFF;
                        frac_val <= (((-fp_value) & 16'hFFFF) * 16'd10000) >> 16;
                    end
                end else begin
                    int_val <= (fp_value >> 16) & 16'hFFFF;
                    frac_val <= ((fp_value & 16'hFFFF) * 16'd10000) >> 16;
                end
                
                state <= S_INT_PROC;
                phase <= 2'd0;
            end
            
            S_INT_PROC: begin
                if (phase == 2'd0) begin
                    // Phase 0: Check for zero
                    if (int_val == 0) begin
                        digit_lim <= 3'd1;
                        digit_mem[0] <= 4'd0;
                        temp_div <= frac_val;
                        pos <= 4'd0;
                        state <= S_FRAC_PROC;
                    end else begin
                        temp_div <= int_val;
                        digit_lim <= 3'd0;
                        phase <= 2'd1;
                    end
                end else if (phase == 2'd1) begin
                    // Phase 1: Count how many digits
                    if (temp_div >= 10) begin
                        temp_div <= temp_div / 10;
                        digit_lim <= digit_lim + 3'd1;
                    end else begin
                        digit_lim <= digit_lim + 3'd1;
                        temp_div <= int_val; // Reset to original for extraction
                        pos <= 4'd0;
                        phase <= 2'd2;
                    end
                end else begin
                    // Phase 2: Extract digits from right to left
                    if (pos < digit_lim) begin
                        // Store in digit_mem[0] (MSB) to digit_mem[digit_lim-1] (LSB)
                        digit_mem[digit_lim - 1 - pos] <= temp_div % 10;
                        temp_div <= temp_div / 10;
                        pos <= pos + 4'd1;
                    end else begin
                        // Move to fractional processing
                        temp_div <= frac_val;
                        pos <= 4'd0;
                        state <= S_FRAC_PROC;
                    end
                end
            end
            
            S_FRAC_PROC: begin
                // Extract 4 fractional digits
                if (pos < 4) begin
                    case (pos)
                        4'd0: divisor = 16'd1000;
                        4'd1: divisor = 16'd100;
                        4'd2: divisor = 16'd10;
                        default: divisor = 16'd1;
                    endcase
                    
                    // The digit is extracted by dividing by the current divisor
                    digit_mem[digit_lim + pos] <= temp_div / divisor;
                    
                    // The remainder is the input for the next digit extraction
                    temp_div <= temp_div % divisor;
                    
                    pos <= pos + 4'd1;
                end else begin
                    pos <= 4'd0;
                    phase <= 2'd0;
                    state <= S_BUILD;
                end
            end
            
            S_BUILD: begin
                // Construct output string
                if (phase == 2'd0) begin
                    // Handle sign
                    if (neg_flag) begin
                        result[47:42] <= CHAR_NEG;
                        pos <= 4'd1; // Start integer digits at output position 1
                    end else begin
                        pos <= 4'd0; // Start integer digits at output position 0
                    end
                    phase <= 2'd1;
                end else if (phase == 2'd1) begin
                    // Integer digits
                    // pos is the output index, digit_lim is the count of integer digits 
                    if ((neg_flag && pos < digit_lim + 4'd1) || (!neg_flag && pos < digit_lim)) begin
                        // digit_mem index: pos - 1 if negative, pos if positive.
                        result[47 - pos*6 -: 6] <= {2'b00, digit_mem[pos - (neg_flag ? 4'd1 : 4'd0)]};
                        pos <= pos + 4'd1;
                    end else begin
                        // Insert DOT
                        result[47 - pos*6 -: 6] <= CHAR_DOT;
                        pos <= pos + 4'd1;
                        phase <= 2'd2;
                    end
                end else if (phase == 2'd2) begin
                    // Fractional digits
                    if (pos < (neg_flag ? digit_lim + 4'd6 : digit_lim + 4'd5)) begin 
                        // pos_of_first_frac_digit = neg_flag ? digit_lim + 2 : digit_lim + 1
                        result[47 - pos*6 -: 6] <= {2'b00, digit_mem[digit_lim + (pos - (neg_flag ? digit_lim + 4'd2 : digit_lim + 4'd1))]}; 
                        pos <= pos + 4'd1;
                    end else begin
                        phase <= 2'd3;
                    end
                end else begin
                    // Fill with spaces
                    if (pos < 8) begin
                        result[47 - pos*6 -: 6] <= CHAR_SPACE;
                        pos <= pos + 4'd1;
                    end else begin
                        state <= S_COMPLETE;
                    end
                end
            end
            
            S_COMPLETE: begin
                conversion_done <= 1'b1;
                state <= S_IDLE;
            end
            
            default: state <= S_IDLE;
        endcase
    end
endmodule
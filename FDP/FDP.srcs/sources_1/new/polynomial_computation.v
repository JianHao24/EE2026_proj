`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 23.03.2025 21:13:22
// Design Name: 
// Module Name: polynomial_computation
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

(* use_dsp = "yes" *)
module poly_calc_engine(
    input  wire clk,
    input  wire requires_computation,
    input  wire signed [31:0] x_value,
    input  wire signed [31:0] coeff_a,
    input  wire signed [31:0] coeff_b,
    input  wire signed [31:0] coeff_c,
    input  wire signed [31:0] coeff_d,
    output reg  signed [47:0] y_value,
    output reg  computation_complete,
    input  wire is_graph
);

    // FSM encoding
    reg [3:0] state = 0;

    // FIXED: Use 32-bit for Q16.16 values, 64-bit only for intermediate multiplication
    reg signed [31:0] x2, x3;
    reg signed [31:0] term_a, term_b, term_c;
    reg signed [31:0] mul_in_a, mul_in_b;
    reg signed [63:0] mul_res;
    reg overflow_detected;
    reg local_overflow;
    
    // Declare sum_check at module level for overflow detection
    reg signed [32:0] sum_check;

    // FIXED: Proper Q16.16 extraction from Q32.32
    function automatic signed [31:0] extract_q16_16;
        input signed [63:0] val;
        begin
            // Extract bits [47:16] and sign-extend to 32 bits
            extract_q16_16 = val[47:16];
        end
    endfunction

    // Overflow detection utility
    function automatic overflow_flag;
        input signed [63:0] val;
        begin
            // Check if value fits in Q16.16 range after shifting
            // Valid range: bits [63:48] should all be copies of bit [47] (sign extension)
            overflow_flag = (val[47] == 1'b0) ? (|val[63:48]) : (&(~val[63:48]));
        end
    endfunction

    always @(posedge clk) begin
        if (requires_computation) begin
            computation_complete <= 0;

            // Fast mode: graph mode skips overflow logic for speed
            if (is_graph) begin
                case (state)
                    0:  begin mul_in_a <= x_value; mul_in_b <= x_value; state <= 1; end
                    1:  begin mul_res <= $signed(mul_in_a) * $signed(mul_in_b); state <= 2; end
                    2:  begin x2 <= extract_q16_16(mul_res); 
                              mul_in_a <= extract_q16_16(mul_res); 
                              mul_in_b <= x_value; state <= 3; end
                    3:  begin mul_res <= $signed(mul_in_a) * $signed(mul_in_b); state <= 4; end
                    4:  begin x3 <= extract_q16_16(mul_res); 
                              mul_in_a <= coeff_a; 
                              mul_in_b <= extract_q16_16(mul_res); state <= 5; end
                    5:  begin mul_res <= $signed(mul_in_a) * $signed(mul_in_b); state <= 6; end
                    6:  begin term_a <= extract_q16_16(mul_res); 
                              mul_in_a <= coeff_b; 
                              mul_in_b <= x2; state <= 7; end
                    7:  begin mul_res <= $signed(mul_in_a) * $signed(mul_in_b); state <= 8; end
                    8:  begin term_b <= extract_q16_16(mul_res); 
                              mul_in_a <= coeff_c; 
                              mul_in_b <= x_value; state <= 9; end
                    9:  begin mul_res <= $signed(mul_in_a) * $signed(mul_in_b); state <= 10; end
                    10: begin term_c <= extract_q16_16(mul_res); state <= 11; end
                    11: begin 
                              // FIXED: Proper 32-bit addition, then extend to 48-bit for output
                              y_value <= {{16{term_a[31]}}, term_a} + 
                                        {{16{term_b[31]}}, term_b} + 
                                        {{16{term_c[31]}}, term_c} + 
                                        {{16{coeff_d[31]}}, coeff_d};
                              computation_complete <= 1; 
                              state <= 0; 
                        end
                endcase
            end 
            else begin
                case (state)
                    // Stage 0: prepare x²
                    0:  begin
                            mul_in_a <= x_value;
                            mul_in_b <= x_value;
                            state <= 1;
                        end
                    // Stage 1: multiply for x²
                    1:  begin
                            mul_res <= $signed(mul_in_a) * $signed(mul_in_b);
                            state <= 2;
                        end
                    // Stage 2: store x² or handle overflow
                    2:  begin
                            local_overflow = overflow_flag(mul_res);
                            if (local_overflow && (coeff_a | coeff_b)) begin
                                overflow_detected <= 1;
                                state <= 14;
                            end else begin
                                x2 <= extract_q16_16(mul_res);
                                mul_in_a <= extract_q16_16(mul_res);
                                mul_in_b <= x_value;
                                state <= 3;
                            end
                        end
                    // Stage 3: compute x³
                    3:  begin mul_res <= $signed(mul_in_a) * $signed(mul_in_b); state <= 4; end
                    // Stage 4: store x³, setup a*x³
                    4:  begin
                            local_overflow = overflow_flag(mul_res);
                            if (local_overflow && coeff_a != 0) begin
                                overflow_detected <= 1;
                                state <= 14;
                            end else begin
                                x3 <= extract_q16_16(mul_res);
                                mul_in_a <= coeff_a;
                                mul_in_b <= extract_q16_16(mul_res);
                                state <= 5;
                            end
                        end
                    // Stage 5: a*x³
                    5:  begin mul_res <= $signed(mul_in_a) * $signed(mul_in_b); state <= 6; end
                    6:  begin
                            local_overflow = overflow_flag(mul_res);
                            if (local_overflow && coeff_a != 0) begin
                                overflow_detected <= 1;
                                state <= 14;
                            end else begin
                                term_a <= extract_q16_16(mul_res);
                                mul_in_a <= coeff_b;
                                mul_in_b <= x2;
                                state <= 7;
                            end
                        end
                    // Stage 7: b*x²
                    7:  begin mul_res <= $signed(mul_in_a) * $signed(mul_in_b); state <= 8; end
                    8:  begin
                            local_overflow = overflow_flag(mul_res);
                            if (local_overflow && coeff_b != 0) begin
                                overflow_detected <= 1;
                                state <= 14;
                            end else begin
                                term_b <= extract_q16_16(mul_res);
                                mul_in_a <= coeff_c;
                                mul_in_b <= x_value;
                                state <= 9;
                            end
                        end
                    // Stage 9: c*x
                    9:  begin mul_res <= $signed(mul_in_a) * $signed(mul_in_b); state <= 10; end
                    10: begin
                            local_overflow = overflow_flag(mul_res);
                            if (local_overflow && coeff_c != 0) begin
                                overflow_detected <= 1;
                                state <= 14;
                            end else begin
                                term_c <= extract_q16_16(mul_res);
                                state <= 11;
                            end
                        end
                    // FIXED: Summation chain with proper 32-bit arithmetic
                    11: begin
                            sum_check = {term_a[31], term_a} + {term_b[31], term_b};
                            if (sum_check[32] != sum_check[31]) begin
                                overflow_detected <= 1;
                                state <= 14;
                            end else begin
                                term_a <= sum_check[31:0];
                                state <= 12;
                            end
                        end
                    12: begin
                            sum_check = {term_a[31], term_a} + {term_c[31], term_c};
                            if (sum_check[32] != sum_check[31]) begin
                                overflow_detected <= 1;
                                state <= 14;
                            end else begin
                                term_a <= sum_check[31:0];
                                state <= 13;
                            end
                        end
                    13: begin
                            sum_check = {term_a[31], term_a} + {coeff_d[31], coeff_d};
                            if (sum_check[32] != sum_check[31]) begin
                                overflow_detected <= 1;
                                // Sign extend to 48-bit
                                y_value <= {{16{sum_check[31]}}, sum_check[31:0]};
                            end else begin
                                // Sign extend to 48-bit
                                y_value <= {{16{sum_check[31]}}, sum_check[31:0]};
                            end
                            state <= 14;
                        end
                    // Finish state
                    14: begin
                            if (overflow_detected) begin
                                y_value <= 0;
                                overflow_detected <= 0;
                            end
                            computation_complete <= 1;
                            state <= 0;
                        end
                endcase
            end
        end else begin
            computation_complete <= 0;
            state <= 0;
        end
    end
endmodule


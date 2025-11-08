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

    // Internal registers
    reg signed [47:0] x2, x3;
    reg signed [47:0] term_a, term_b, term_c, sum_tmp;
    reg signed [47:0] mul_in_a, mul_in_b;
    reg signed [63:0] mul_res;
    reg overflow_detected;
    reg local_overflow;

    // Overflow detection utility
    function automatic overflow_flag;
        input signed [63:0] val;
        begin
            overflow_flag = ((val[63] == 0) && (|val[63:47])) || ((val[63] == 1) && (|(~val[63:47])));
        end
    endfunction

    always @(posedge clk) begin
        if (requires_computation) begin
            computation_complete <= 0;

            // Fast mode: graph mode skips overflow logic for speed
            if (is_graph) begin
                case (state)
                    0:  begin mul_in_a <= x_value; mul_in_b <= x_value;           state <= 1; end
                    1:  begin mul_res <= mul_in_a * mul_in_b;                     state <= 2; end
                    2:  begin x2 <= mul_res >>> 16; mul_in_a <= mul_res >>> 16; mul_in_b <= x_value; state <= 3; end
                    3:  begin mul_res <= mul_in_a * mul_in_b;                     state <= 4; end
                    4:  begin x3 <= mul_res >>> 16; mul_in_a <= coeff_a; mul_in_b <= mul_res >>> 16; state <= 5; end
                    5:  begin mul_res <= mul_in_a * mul_in_b;                     state <= 6; end
                    6:  begin term_a <= mul_res >>> 16; mul_in_a <= coeff_b; mul_in_b <= x2; state <= 7; end
                    7:  begin mul_res <= mul_in_a * mul_in_b;                     state <= 8; end
                    8:  begin term_b <= mul_res >>> 16; mul_in_a <= coeff_c; mul_in_b <= x_value; state <= 9; end
                    9:  begin mul_res <= mul_in_a * mul_in_b;                     state <= 10; end
                    10: begin term_c <= mul_res >>> 16;                           state <= 11; end
                    11: begin y_value <= term_a + term_b + term_c + coeff_d;
                               computation_complete <= 1; state <= 0; end
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
                            mul_res <= mul_in_a * mul_in_b;
                            state <= 2;
                        end
                    // Stage 2: store x² or handle overflow
                    2:  begin
                            local_overflow = overflow_flag(mul_res);
                            if (local_overflow && (coeff_a | coeff_b)) begin
                                overflow_detected <= 1;
                                state <= 14;
                            end else begin
                                x2 <= mul_res >>> 16;
                                mul_in_a <= mul_res >>> 16;
                                mul_in_b <= x_value;
                                state <= 3;
                            end
                        end
                    // Stage 3: compute x³
                    3:  begin mul_res <= mul_in_a * mul_in_b; state <= 4; end
                    // Stage 4: store x³, setup a*x³
                    4:  begin
                            local_overflow = overflow_flag(mul_res);
                            if (local_overflow && coeff_a != 0) begin
                                overflow_detected <= 1;
                                state <= 14;
                            end else begin
                                x3 <= mul_res >>> 16;
                                mul_in_a <= coeff_a;
                                mul_in_b <= mul_res >>> 16;
                                state <= 5;
                            end
                        end
                    // Stage 5: a*x³
                    5:  begin mul_res <= mul_in_a * mul_in_b; state <= 6; end
                    6:  begin
                            local_overflow = overflow_flag(mul_res);
                            if (local_overflow && coeff_a != 0) begin
                                overflow_detected <= 1;
                                state <= 14;
                            end else begin
                                term_a <= mul_res >>> 16;
                                mul_in_a <= coeff_b;
                                mul_in_b <= x2;
                                state <= 7;
                            end
                        end
                    // Stage 7: b*x²
                    7:  begin mul_res <= mul_in_a * mul_in_b; state <= 8; end
                    8:  begin
                            local_overflow = overflow_flag(mul_res);
                            if (local_overflow && coeff_b != 0) begin
                                overflow_detected <= 1;
                                state <= 14;
                            end else begin
                                term_b <= mul_res >>> 16;
                                mul_in_a <= coeff_c;
                                mul_in_b <= x_value;
                                state <= 9;
                            end
                        end
                    // Stage 9: c*x
                    9:  begin mul_res <= mul_in_a * mul_in_b; state <= 10; end
                    10: begin
                            local_overflow = overflow_flag(mul_res);
                            if (local_overflow && coeff_c != 0) begin
                                overflow_detected <= 1;
                                state <= 14;
                            end else begin
                                term_c <= mul_res >>> 16;
                                state <= 11;
                            end
                        end
                    // Summation chain
                    11: begin
                            sum_tmp = term_a + term_b;
                            if (((term_a[31] == term_b[31]) && (sum_tmp[31] != term_a[31]))) begin
                                overflow_detected <= 1;
                                state <= 14;
                            end else begin
                                term_a <= sum_tmp;
                                state <= 12;
                            end
                        end
                    12: begin
                            sum_tmp = term_a + term_c;
                            if (((term_a[31] == term_c[31]) && (sum_tmp[31] != term_a[31]))) begin
                                overflow_detected <= 1;
                                state <= 14;
                            end else begin
                                term_a <= sum_tmp;
                                state <= 13;
                            end
                        end
                    13: begin
                            sum_tmp = term_a + coeff_d;
                            if (((term_a[31] == coeff_d[31]) && (sum_tmp[31] != term_a[31]))) begin
                                overflow_detected <= 1;
                                y_value <= sum_tmp;
                            end else begin
                                y_value <= sum_tmp;
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



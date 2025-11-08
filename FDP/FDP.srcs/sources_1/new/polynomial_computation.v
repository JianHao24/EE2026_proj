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


(* use_dsp = "yes" *) module polynomial_computation(
    input clk,
    input requires_computation,
    input signed [31:0] x_value,
    input signed [31:0] coeff_a,
    input signed [31:0] coeff_b,
    input signed [31:0] coeff_c,
    input signed [31:0] coeff_d,
    output reg signed [47:0] y_value,
    output reg computation_complete,
    input is_graph
    );
    // State machine states
    reg [3:0] calc_state = 0;
    
    // Intermediate calculation values
    reg signed [47:0] x_squared_val;
    reg signed [47:0] x_cubed_val;
    reg signed [47:0] term_a_val;
    reg signed [47:0] term_b_val;
    reg signed [47:0] term_c_val;
    reg signed [47:0] temp_sum;
    
    // Shared multiplier registers
    reg signed [47:0] mult_a, mult_b;
    reg signed [63:0] mult_result;
    reg mult_overflow = 0;
    reg is_overflow = 0;

    // Computation state machine
    always @(posedge clk) begin
        if (requires_computation) begin
            computation_complete <= 0;

            if (is_graph) begin
                case (calc_state)
                    0: begin // Setup x^2 calculation
                        mult_a <= x_value;
                        mult_b <= x_value;
                        calc_state <= 1;
                    end
                
                    1: begin // Perform x^2 calculation
                        mult_result <= mult_a * mult_b;
                        calc_state <= 2;
                    end
                
                    2: begin // Store x^2 result, setup x^3 calculation
                        x_squared_val <= mult_result >>> 16;
                        mult_a <= mult_result >>> 16; // x^2
                        mult_b <= x_value;
                        calc_state <= 3;
                    end
                
                    3: begin // Perform x^3 calculation
                        mult_result <= mult_a * mult_b;
                        calc_state <= 4;
                    end
                
                    4: begin // Store x^3, setup a*x^3 calculation
                        x_cubed_val <= mult_result >>> 16;
                        mult_a <= coeff_a;
                        mult_b <= mult_result >>> 16; 
                        calc_state <= 5;
                    end
                
                    5: begin // Perform a*x^3 calculation
                        mult_result <= mult_a * mult_b;
                        calc_state <= 6;
                    end
                
                    6: begin // Store a*x^3, setup b*x^2
                        term_a_val <= mult_result >>> 16;
                        mult_a <= coeff_b;
                        mult_b <= x_squared_val;
                        calc_state <= 7;
                    end
                
                    7: begin // Perform b*x^2 calculation
                        mult_result <= mult_a * mult_b;
                        calc_state <= 8;
                    end
                
                    8: begin // Store b*x^2, setup c*x
                        term_b_val <= mult_result >>> 16;
                        mult_a <= coeff_c;
                        mult_b <= x_value;
                        calc_state <= 9;
                    end
                
                    9: begin // Perform c*x calculation
                        mult_result <= mult_a * mult_b;
                        calc_state <= 10;
                    end
                
                    10: begin // Store c*x
                        term_c_val <= mult_result >>> 16;
                        calc_state <= 11;
                    end
                
                    11: begin // Compute final result
                        y_value <= term_a_val + term_b_val + term_c_val + coeff_d;
                        computation_complete <= 1;
                        calc_state <= 0; // Reset for next computation
                    end
                endcase
            end
            else begin
                case (calc_state)
                    0: begin // Setup x^2 calculation
                        mult_a <= x_value;
                        mult_b <= x_value;
                        calc_state <= 1;
                    end
                
                    1: begin // Perform x^2 calculation
                        mult_result <= mult_a * mult_b;
                        calc_state <= 2;
                    end
                
                    2: begin // Store x^2 result, setup x^3 calculation
                        // Check for overflow in x^2 calculation
                        // mult_overflow = (mult_result[63:32] != {32{mult_result[31]}});
                        // mult_overflow = |mult_result[63:48];
                        mult_overflow = ((mult_result[63] == 0) && (|mult_result[63:47])) || ((mult_result[63] == 1) && (|(~mult_result[63:47])));

                        if (mult_overflow && (coeff_b != 0 || coeff_a != 0) && !is_graph) begin
                            is_overflow <= 1;
                            // No further computations if overflow
                            calc_state <= 14;
                        end
                        else begin
                            x_squared_val <= mult_result >>> 16;
                            mult_a <= mult_result >>> 16; // x^2
                            mult_b <= x_value;
                            calc_state <= 3;
                        end
                    end
                
                    3: begin // Perform x^3 calculation
                        mult_result <= mult_a * mult_b;
                        calc_state <= 4;
                    end
                
                    4: begin // Store x^3, setup a*x^3 calculation
                        // Check for overflow in x^3
                        // mult_overflow = (mult_result[63:32] != {32{mult_result[31]}});
                        // mult_overflow = ((mult_result[47] == 0) && (|mult_result[63:47])) || ((mult_result[47] == 1) && (|(~mult_result[63:47])));
                        // mult_overflow = |mult_result[63:48];
                        // mult_overflow = ((mult_result[63] == 0) && (|mult_result[63:48])) || ((mult_result[63] == 1) && (|mult_result[62:48]));
                        mult_overflow = ((mult_result[63] == 0) && (|mult_result[63:47])) || ((mult_result[63] == 1) && (|(~mult_result[63:47])));
                    
                        if (mult_overflow && coeff_a != 0 && !is_graph) begin
                            is_overflow <= 1;
                            // No further computations if overflow
                            calc_state <= 14;
                        end
                        else begin
                            x_cubed_val <= mult_result >>> 16;
                            mult_a <= coeff_a;
                            mult_b <= mult_result >>> 16; 
                            calc_state <= 5;
                        end
                    end
                
                    5: begin // Perform a*x^3 calculation
                        mult_result <= mult_a * mult_b;
                        calc_state <= 6;
                    end
                
                    6: begin // Store a*x^3, setup b*x^2
                        // Check for overflow in a*x^3
                        // mult_overflow = (mult_result[63:32] != {32{mult_result[31]}});
                        // mult_overflow = ((mult_result[47] == 0) && (|mult_result[63:48])) || ((mult_result[47] == 1) && (|(~mult_result[63:48])));
                        // mult_overflow = |mult_result[63:48];
                        // mult_overflow = ((mult_result >= 0) && (|mult_result[63:48])) || ((mult_result < 0) && (|(mult_result[63:48] & 16'h8000)));
                        // mult_overflow = ((mult_result[63] == 0) && (|mult_result[63:48])) || ((mult_result[63] == 1) && (|mult_result[62:48]));
                        mult_overflow = ((mult_result[63] == 0) && (|mult_result[63:47])) || ((mult_result[63] == 1) && (|(~mult_result[63:47])));

                        if (mult_overflow && coeff_a != 0 && !is_graph) begin
                            is_overflow <= 1;
                            // No further computations if overflow
                            calc_state <= 14;
                        end
                        else begin
                            term_a_val <= mult_result >>> 16;
                            mult_a <= coeff_b;
                            mult_b <= x_squared_val;
                            calc_state <= 7;
                        end
                    end
                
                    7: begin // Perform b*x^2 calculation
                        mult_result <= mult_a * mult_b;
                        calc_state <= 8;
                    end
                
                    8: begin // Store b*x^2, setup c*x
                        // mult_overflow = (mult_result[63:32] != {32{mult_result[31]}});
                        // mult_overflow = ((mult_result[47] == 0) && (|mult_result[63:48])) || ((mult_result[47] == 1) && (|(~mult_result[63:48])));
                        // mult_overflow = |mult_result[63:48];
                        // mult_overflow = ((mult_result >= 0) && (|mult_result[63:48])) || ((mult_result < 0) && (|(mult_result[63:48] & 16'h8000)));
                        // mult_overflow = ((mult_result[63] == 0) && (|mult_result[63:48])) || ((mult_result[63] == 1) && (|mult_result[62:48]));
                        mult_overflow = ((mult_result[63] == 0) && (|mult_result[63:47])) || ((mult_result[63] == 1) && (|(~mult_result[63:47])));


                        if (mult_overflow && coeff_b != 0 && !is_graph) begin
                            is_overflow <= 1;
                            // No further computations if overflow
                            calc_state <= 14;
                        end
                        else begin
                            term_b_val <= mult_result >>> 16;
                            mult_a <= coeff_c;
                            mult_b <= x_value;
                            calc_state <= 9;
                        end
                    end
                
                    9: begin // Perform c*x calculation
                        mult_result <= mult_a * mult_b;
                        calc_state <= 10;
                    end
                
                    10: begin // Store c*x
                        // mult_overflow = (mult_result[63:32] != {32{mult_result[31]}});
                        // mult_overflow = ((mult_result[47] == 0) && (|mult_result[63:48])) || ((mult_result[47] == 1) && (|(~mult_result[63:48])));
                        // mult_overflow = |mult_result[63:48];
                        // mult_overflow = ((mult_result >= 0) && (|mult_result[63:48])) || ((mult_result < 0) && (|(mult_result[63:48] & 16'h8000)));
                        // mult_overflow = ((mult_result[63] == 0) && (|mult_result[63:48])) || ((mult_result[63] == 1) && (|mult_result[62:48]));
                        mult_overflow = ((mult_result[63] == 0) && (|mult_result[63:47])) || ((mult_result[63] == 1) && (|(~mult_result[63:47])));


                        if (mult_overflow && coeff_c != 0 && !is_graph) begin
                            is_overflow <= 1;
                            // No further computations if overflow
                            calc_state <= 14;
                        end
                        else begin
                            term_c_val <= mult_result >>> 16;
                            calc_state <= 11;
                        end
                    end
                
                    11: begin // Compute final result
                        // First addition
                        temp_sum = term_a_val + term_b_val;
                        
                        // Check for overflow
                        if ((term_a_val[31] == 0 && term_b_val[31] == 0 && temp_sum[31] == 1) || 
                            (term_a_val[31] == 1 && term_b_val[31] == 1 && temp_sum[31] == 0) && !is_graph) begin
                            is_overflow <= 1;
                            calc_state <= 14;
                        end
                        else begin
                            term_a_val <= temp_sum;
                            calc_state <= 12;
                        end
                    end

                    12: begin
                        // Second addition
                        temp_sum = term_a_val + term_c_val;

                        // Check for overflow
                        if ((term_a_val[31] == 0 && term_c_val[31] == 0 && temp_sum[31] == 1) || 
                            (term_a_val[31] == 1 && term_c_val[31] == 1 && temp_sum[31] == 0) && !is_graph) begin
                            is_overflow <= 1;
                            calc_state <= 14;
                        end
                        else begin
                            // Store intermediate result and proceed
                            term_a_val <= temp_sum; // Reuse term_a_val again
                            calc_state <= 13;
                        end
                    end

                    13: begin
                        // Final addition
                        // Need to sign-extend coeff_d to match the 48-bit width
                        temp_sum = term_a_val + coeff_d;
                    
                        // Check for overflow
                        if ((term_a_val[31] == 0 && coeff_d[31] == 0 && temp_sum[31] == 1) || 
                            (term_a_val[31] == 1 && coeff_d[31] == 1 && temp_sum[31] == 0) && !is_graph) begin
                            is_overflow <= 1;
                            y_value <= temp_sum;
                        end
                        else begin
                            y_value <= temp_sum;
                        end
                        calc_state <= 14;
                    end

                    14: begin
                        if (is_overflow) begin
                            y_value <= 0;
                            is_overflow <= 0;
                        end
                        calc_state <= 0;
                        computation_complete <= 1;
                    end
                endcase
            end
        end
        else begin
            // Reset when not computing
            computation_complete <= 0;
            calc_state <= 0;
        end
    end
endmodule

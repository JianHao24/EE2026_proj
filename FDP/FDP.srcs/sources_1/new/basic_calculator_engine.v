`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10/22/2025 03:54:43 PM
// Design Name: 
// Module Name: basic_calculator_engine
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

module basic_calculator_engine(
    input wire clk,
    input wire rst,
    input wire input_valid,
    input wire signed [31:0] input_val,
    input wire op_valid,
    input wire [1:0] op_sel,
    output reg signed [31:0] result,
    output reg result_valid,
    output reg overflow,
    output reg div_by_zero,
    output reg waiting_operand,
    output reg [1:0] current_operation
);

    localparam [1:0] OP_ADD = 2'b00;
    localparam [1:0] OP_SUB = 2'b01;
    localparam [1:0] OP_MUL = 2'b10;
    localparam [1:0] OP_DIV = 2'b11;
    
    // State definitions
    localparam STATE_INPUT = 1'b0;
    localparam STATE_OP = 1'b1;
    
    reg state;
    reg next_state;
    reg signed [31:0] accumulator;
    reg new_calculation;
    reg calculation_pending;
    reg [1:0] pending_op;
    
    // Calculation units
    reg signed [31:0] add_result;
    reg add_overflow;
    
    reg signed [31:0] sub_result;
    reg sub_overflow;
    
    reg signed [63:0] mul_product;
    reg signed [31:0] mul_result;
    reg mul_overflow;
    
    reg signed [63:0] div_numerator;
    reg signed [31:0] div_result;
    reg div_overflow;

    // State transition
    always @(posedge clk) begin
        if (rst) begin
            state <= STATE_INPUT;
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            STATE_INPUT: begin
                if (input_valid && !new_calculation) begin
                    next_state = STATE_OP;
                end
            end
            STATE_OP: begin
                if (op_valid) begin
                    next_state = STATE_INPUT;
                end
            end
        endcase
    end

    // Output mode assignment
    always @(*) begin
        waiting_operand = (state == STATE_OP);
    end

    // Main calculation pipeline
    always @(posedge clk) begin
        result_valid <= 1'b0;
        overflow <= 1'b0;
        div_by_zero <= 1'b0;

        if (rst) begin
            accumulator <= 32'sd0;
            result <= 32'sd0;
            current_operation <= OP_ADD;
            new_calculation <= 1'b1;
            calculation_pending <= 1'b0;
            pending_op <= OP_ADD;
        end else begin
            // Store operation when selected
            if (op_valid) begin
                pending_op <= op_sel;
                current_operation <= op_sel;
                calculation_pending <= 1'b1;
            end

            // Process input when received
            if (input_valid) begin
                if (new_calculation) begin
                    // First input - just store
                    accumulator <= input_val;
                    result <= input_val;
                    new_calculation <= 1'b0;
                    result_valid <= 1'b1;
                end else if (calculation_pending) begin
                    // Execute pending calculation
                    case (pending_op)
                        OP_ADD: begin
                            add_result = accumulator + input_val;
                            add_overflow = (accumulator[31] == input_val[31]) && 
                                         (add_result[31] != accumulator[31]);
                            if (!add_overflow) begin
                                accumulator <= add_result;
                                result <= add_result;
                            end else begin
                                accumulator <= 32'sd0;
                                result <= 32'sd0;
                                overflow <= 1'b1;
                            end
                        end
                        
                        OP_SUB: begin
                            sub_result = accumulator - input_val;
                            sub_overflow = (accumulator[31] != input_val[31]) && 
                                         (sub_result[31] != accumulator[31]);
                            if (!sub_overflow) begin
                                accumulator <= sub_result;
                                result <= sub_result;
                            end else begin
                                accumulator <= 32'sd0;
                                result <= 32'sd0;
                                overflow <= 1'b1;
                            end
                        end
                        
                        OP_MUL: begin
                            mul_product = $signed(accumulator) * $signed(input_val);
                            mul_result = mul_product >>> 16;
                            mul_overflow = (mul_product[63] == 0) ? (|mul_product[63:47]) : 
                                         (|(~mul_product[63:47]));
                            if (!mul_overflow) begin
                                accumulator <= mul_result;
                                result <= mul_result;
                            end else begin
                                accumulator <= 32'sd0;
                                result <= 32'sd0;
                                overflow <= 1'b1;
                            end
                        end
                        
                        OP_DIV: begin
                            if (input_val == 0) begin
                                accumulator <= 32'sd0;
                                result <= 32'sd0;
                                div_by_zero <= 1'b1;
                            end else begin
                                div_numerator = {{32{accumulator[31]}}, accumulator} << 16;
                                div_result = div_numerator / $signed(input_val);
                                div_overflow = ((div_result[31] == 0) && (div_numerator[63] == 1) && (input_val[31] == 0)) ||
                                             ((div_result[31] == 1) && (div_numerator[63] == 0) && (input_val[31] == 0)) ||
                                             ((div_result[31] == 0) && (div_numerator[63] == 0) && (input_val[31] == 1)) ||
                                             ((div_result[31] == 1) && (div_numerator[63] == 1) && (input_val[31] == 1));
                                if (!div_overflow) begin
                                    accumulator <= div_result;
                                    result <= div_result;
                                end else begin
                                    accumulator <= 32'sd0;
                                    result <= 32'sd0;
                                    overflow <= 1'b1;
                                end
                            end
                        end
                    endcase
                    
                    calculation_pending <= 1'b0;
                    result_valid <= 1'b1;
                end
            end
        end
    end
endmodule


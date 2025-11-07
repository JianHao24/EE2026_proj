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
    
    // Input interface
    input wire input_valid,              // Pulse when new number ready
    input wire signed [31:0] input_val,  // Q16.16 input value
    
    // Operation interface  
    input wire op_valid,                 // Pulse when operation selected
    input wire [1:0] op_sel,             // 0=ADD, 1=SUB, 2=MUL, 3=DIV
    
    // Output interface
    output reg signed [31:0] result,     // Q16.16 result
    output reg result_valid,             // Pulse when result ready
    output reg overflow,                 // High if overflow occurred
    output reg div_by_zero,              // High if divide by zero
    
    // Status flags
    output reg is_operand_mode,          // 0=Input Mode, 1=Operand Mode
    output reg [1:0] current_operation   // Current pending operation
);

    // Operation encoding
    localparam [1:0] OP_ADD = 2'b00;
    localparam [1:0] OP_SUB = 2'b01;
    localparam [1:0] OP_MUL = 2'b10;
    localparam [1:0] OP_DIV = 2'b11;
    
    // Internal registers
    reg signed [31:0] accumulator;       // Holds running result
    reg awaiting_first_value;            // True until first number entered
    reg signed [63:0] wide_temp;         // For multiplication/division
    reg signed [31:0] calc_result;       // Temporary calculation result
    reg overflow_detected;               // Internal overflow flag
    reg signed [63:0] scaled_dividend;   // For division scaling

    always @(posedge clk) begin
        // Clear single-cycle flags
        result_valid <= 1'b0;
        overflow_detected <= 1'b0;
        overflow <= 1'b0;
        div_by_zero <= 1'b0;
        
        if (rst) begin
            is_operand_mode <= 1'b0;
            result <= 32'sd0;
            current_operation <= OP_ADD;
            awaiting_first_value <= 1'b1;
            accumulator <= 32'sd0;
        end else begin
            
            // MODE 0: Input/Keypad Mode - waiting for number entry
            if (!is_operand_mode) begin
                if (input_valid) begin
                    // Number has been entered, switch to operand selection mode
                    is_operand_mode <= 1'b1;
                    
                    if (awaiting_first_value) begin
                        // First value: just store it
                        accumulator <= input_val;
                        result <= input_val;
                        awaiting_first_value <= 1'b0;
                    end else begin
                        // Subsequent value: execute pending operation
                        case (current_operation)
                            OP_ADD: begin
                                calc_result = accumulator + input_val;
                                // Overflow: same signs in, different sign out
                                overflow_detected = (accumulator[31] == input_val[31]) && 
                                                   (calc_result[31] != accumulator[31]);
                                accumulator <= overflow_detected ? 32'sd0 : calc_result;
                                result <= overflow_detected ? 32'sd0 : calc_result;
                                overflow <= overflow_detected;
                            end
                            
                            OP_SUB: begin
                                calc_result = accumulator - input_val;
                                // Overflow: different signs in, unexpected sign out
                                overflow_detected = (accumulator[31] != input_val[31]) && 
                                                   (calc_result[31] != accumulator[31]);
                                accumulator <= overflow_detected ? 32'sd0 : calc_result;
                                result <= overflow_detected ? 32'sd0 : calc_result;
                                overflow <= overflow_detected;
                            end
                            
                            OP_MUL: begin
                                // Q16.16 multiply: shiftresult right by 16
                                                            wide_temp = $signed(accumulator) * $signed(input_val);
                                                            calc_result = wide_temp >>> 16;
                                                            // Check if upper bits are proper sign extension
                                                            overflow_detected = (wide_temp[63] == 1'b0) ? (|wide_temp[63:47]) : 
                                                                               (|(~wide_temp[63:47]));
                                                            accumulator <= overflow_detected ? 32'sd0 : calc_result;
                                                            result <= overflow_detected ? 32'sd0 : calc_result;
                                                            overflow <= overflow_detected;
                                                        end
                                                        
                                                        OP_DIV: begin
                                                            if (input_val == 32'sd0) begin
                                                                // Division by zero
                                                                accumulator <= 32'sd0;
                                                                result <= 32'sd0;
                                                                div_by_zero <= 1'b1;
                                                            end else begin
                                                                // Q16.16 divide: shift dividend left by 16
                                                                scaled_dividend = {{32{accumulator[31]}}, accumulator} << 16;
                                                                calc_result = scaled_dividend / $signed(input_val);
                                                                
                                                                // Overflow check for division
                                                                overflow_detected = ((calc_result[31] == 1'b0) && (scaled_dividend[63] == 1'b1) && (input_val[31] == 1'b0)) ||
                                                                                   ((calc_result[31] == 1'b1) && (scaled_dividend[63] == 1'b0) && (input_val[31] == 1'b0)) ||
                                                                                   ((calc_result[31] == 1'b0) && (scaled_dividend[63] == 1'b0) && (input_val[31] == 1'b1)) ||
                                                                                   ((calc_result[31] == 1'b1) && (scaled_dividend[63] == 1'b1) && (input_val[31] == 1'b1));
                                                                
                                                                accumulator <= overflow_detected ? 32'sd0 : calc_result;
                                                                result <= overflow_detected ? 32'sd0 : calc_result;
                                                                overflow <= overflow_detected;
                                                            end
                                                        end
                                                    endcase
                                                end
                                                
                                                result_valid <= 1'b1;
                                            end
                                        end 
                                        // MODE 1: Operand Selection Mode - waiting for operation choice
                                        else begin
                                            if (op_valid) begin
                                                // Operation selected, store it and return to input mode
                                                current_operation <= op_sel;
                                                is_operand_mode <= 1'b0;
                                            end
                                        end
                                    end
                                end
                            endmodule


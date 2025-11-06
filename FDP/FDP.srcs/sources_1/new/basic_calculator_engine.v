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

`timescale 1ns / 1ps

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

    // State encoding
    localparam [1:0] ST_IDLE    = 2'b00;
    localparam [1:0] ST_COMPUTE = 2'b01;
    localparam [1:0] ST_DONE    = 2'b10;
    
    reg [1:0] state, next_state;
    
    // Operation encoding
    localparam [1:0] OP_ADD = 2'b00;
    localparam [1:0] OP_SUB = 2'b01;
    localparam [1:0] OP_MUL = 2'b10;
    localparam [1:0] OP_DIV = 2'b11;
    
    // Internal registers
    reg signed [31:0] accumulator;       // Holds running result
    reg [1:0] pending_op;                // Operation to perform
    reg first_input;                     // Flag for first number
    reg signed [63:0] temp_wide;         // For MUL/DIV intermediate
    reg signed [31:0] temp_result;       // For computation result

    always @(posedge clk) begin
        if (rst) begin
            state <= ST_IDLE;
        end else begin
            state <= next_state;
        end
    end
    
    always @(*) begin
        case (state)
            ST_IDLE:    next_state = input_valid ? ST_COMPUTE : ST_IDLE;
            ST_COMPUTE: next_state = ST_DONE;
            ST_DONE:    next_state = ST_IDLE;
            default:    next_state = ST_IDLE;
        endcase
    end
    
    always @(posedge clk) begin
        if (rst) begin
            accumulator <= 32'sd0;
            result <= 32'sd0;
            pending_op <= OP_ADD;
            first_input <= 1'b1;
            result_valid <= 1'b0;
            overflow <= 1'b0;
            div_by_zero <= 1'b0;
            is_operand_mode <= 1'b0;
            current_operation <= OP_ADD;
        end else begin
            // Default control resets
            result_valid <= 1'b0;

            case (state)
                ST_IDLE: begin
                    // Capture operation - stay in input mode after operation selection
                    if (op_valid) begin
                        pending_op <= op_sel;
                        current_operation <= op_sel;
                        is_operand_mode <= 1'b0;  // Go back to input mode for second number
                        overflow <= 1'b0;
                        div_by_zero <= 1'b0;
                    end
                end

                ST_COMPUTE: begin
                    if (first_input) begin
                        // First number: store it and go to operand selection
                        accumulator <= input_val;
                        result <= input_val;
                        first_input <= 1'b0;
                        is_operand_mode <= 1'b1;  // Switch to operand mode
                    end else begin
                        // Second number: perform the operation
                        
                        case (pending_op)
                            OP_ADD: begin
                                temp_result = accumulator + input_val;
                                if ((accumulator[31] == input_val[31]) && 
                                    (temp_result[31] != accumulator[31])) begin
                                    overflow <= 1'b1;
                                    result <= accumulator;
                                end else begin
                                    accumulator <= temp_result;
                                    result <= temp_result;
                                end
                            end
                            
                            OP_SUB: begin
                                temp_result = accumulator - input_val;
                                if ((accumulator[31] != input_val[31]) && 
                                    (temp_result[31] != accumulator[31])) begin
                                    overflow <= 1'b1;
                                    result <= accumulator;
                                end else begin
                                    accumulator <= temp_result;
                                    result <= temp_result;
                                end
                            end
                            
                            OP_MUL: begin
                                temp_wide = $signed(accumulator) * $signed(input_val);
                                temp_result = temp_wide[47:16];
                                if (temp_result[31]) begin
                                    if (temp_wide[63:48] != 16'hFFFF) begin
                                        overflow <= 1'b1;
                                        result <= accumulator;
                                    end else begin
                                        accumulator <= temp_result;
                                        result <= temp_result;
                                    end
                                end else begin
                                    if (temp_wide[63:48] != 16'h0000) begin
                                        overflow <= 1'b1;
                                        result <= accumulator;
                                    end else begin
                                        accumulator <= temp_result;
                                        result <= temp_result;
                                    end
                                end
                            end
                            
                            OP_DIV: begin
                                if (input_val == 32'sd0) begin
                                    div_by_zero <= 1'b1;
                                    result <= accumulator;
                                end else begin
                                    temp_wide = $signed(accumulator) <<< 16;
                                    temp_result = temp_wide / $signed(input_val);
                                    accumulator <= temp_result;
                                    result <= temp_result;
                                end
                            end
                        endcase
                        
                        // After computing, go back to operand mode to allow chaining
                        is_operand_mode <= 1'b1;
                    end
                end

                ST_DONE: begin
                    result_valid <= 1'b1;
                end
            endcase
        end
    end
endmodule




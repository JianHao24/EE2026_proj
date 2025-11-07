`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11/07/2025 10:19:32 PM
// Design Name: 
// Module Name: trig_calculator
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



module trig_calculator #(
    parameter FIXED_FRAC_BITS = 16
)(
    input wire clk,
    input wire rst,
    input wire trig_valid,              // trigger calculation
    input wire [1:0] trig_sel,          // 00: sin, 01: cos, 10: tan
    input wire signed [31:0] input_val, // input value (ignored in placeholder)
    output reg signed [31:0] result,
    output reg result_valid,
    output reg overflow
);

    // Fixed-point constants (Q16.16 format)
    // 1.0 = 0x00010000 (65536)
    // 2.0 = 0x00020000 (131072)
    // 3.0 = 0x00030000 (196608)
    localparam signed [31:0] FP_ONE   = 32'h00010000;  // 1.0
    localparam signed [31:0] FP_TWO   = 32'h00020000;  // 2.0
    localparam signed [31:0] FP_THREE = 32'h00030000;  // 3.0

    // Simple state machine
    localparam IDLE = 1'b0;
    localparam COMPUTE = 1'b1;
    
    reg state;

    always @(posedge clk) begin
        if (rst) begin
            state <= IDLE;
            result <= 32'd0;
            result_valid <= 1'b0;
            overflow <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    result_valid <= 1'b0;
                    overflow <= 1'b0;
                    
                    if (trig_valid) begin
                        // Immediately calculate based on trig_sel
                        case (trig_sel)
                            2'b00: result <= FP_ONE;    // sin -> 1.0
                            2'b01: result <= FP_TWO;    // cos -> 2.0
                            2'b10: result <= FP_THREE;  // tan -> 3.0
                            default: result <= 32'd0;
                        endcase
                        
                        state <= COMPUTE;
                    end
                end
                
                COMPUTE: begin
                    // One cycle delay to mimic real calculation
                    result_valid <= 1'b1;
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule
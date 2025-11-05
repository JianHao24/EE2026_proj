`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 29.09.2025 14:50:24
// Design Name: 
// Module Name: clock_divider
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


module clock_divisor (
    input CLOCK,
    input [22:0] DIVISOR, 
    output reg SLOW_CLOCK = 1'b1
);
    reg [23:0] COUNT = 6'd0;

    always @(posedge CLOCK) begin
        if (COUNT >= DIVISOR) begin
            COUNT <= 6'd0;
            SLOW_CLOCK <= ~SLOW_CLOCK;
        end else begin
            COUNT <= COUNT + 1;
        end
    end
endmodule
   
    

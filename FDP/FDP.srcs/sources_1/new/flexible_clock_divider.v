`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 06.11.2025 22:54:25
// Design Name: 
// Module Name: flexible_clock_divider
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


module clock_divider(
    input main_clock,
    input[31:0] ticks,
    output reg output_clock
    );
    reg [31:0]COUNT;
    
    initial begin
        output_clock = 0;
        COUNT = 32'b0;
    end
    
    always @ (posedge main_clock)
    begin
        COUNT <= (COUNT == ticks) ? 32'b0 : COUNT + 1;
        output_clock <= (COUNT == 32'b0) ? ~output_clock : output_clock;
    end
endmodule
`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02.10.2025 23:38:18
// Design Name: 
// Module Name: FSM
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


module FSM(input btn, clk, flag, output reg[15:0] oled_colour = 16'b00000_000000_00000);   
     
     localparam state_1 = 1'b0, state_2 = 1'b1; 
     reg state = state_1;
     always @(posedge btn) begin
     state = state + 1;
     end
     always @(posedge clk) begin
     case(state)
     state_1: oled_colour <= flag? 16'b11111_000000_00000 : 16'b00000_111111_00000;
     state_2: oled_colour <= 16'b00000_000000_00000;
     endcase
     end
     
endmodule

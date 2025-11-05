`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02.10.2025 00:27:41
// Design Name: 
// Module Name: Debouncer
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


module debouncer(
    input pb, clk,
    output sig
);
    wire clk_4hz;

    clock_divisor clk_div_inst (
        .CLOCK(clk),
        .DIVISOR(24'd1249999),
        .SLOW_CLOCK(clk_4hz)
    );

    wire Q1, Q2, Qbar1, Qbar2;

    DFF dff1( .D(pb),  .clk(clk_4hz), .Q(Q1), .Qbar(Qbar1) );
    DFF dff2( .D(Q1),  .clk(clk_4hz), .Q(Q2), .Qbar(Qbar2) );

    assign sig = Q1 & Qbar2;

endmodule
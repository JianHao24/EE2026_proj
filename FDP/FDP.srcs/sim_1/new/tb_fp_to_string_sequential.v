`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10/21/2025 05:03:27 PM
// Design Name: 
// Module Name: tb_fp_to_string
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


module tb_fp_to_string;

    reg clk;
    reg start_conversion;
    reg signed [31:0] fp_value;
    wire conversion_done;
    wire [47:0] result;
    
    // Instantiate the module under test
    fp_to_string uut (
        .clk(clk),
        .start_conversion(start_conversion),
        .fp_value(fp_value),
        .conversion_done(conversion_done),
        .result(result)
    );
    
    // Clock generation - 10ns period
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end
    
    // Function to decode 6-bit character to ASCII for display
    function [7:0] decode_char;
        input [5:0] char_code;
        begin
            case (char_code)
                6'd0:  decode_char = "0";
                6'd1:  decode_char = "1";
                6'd2:  decode_char = "2";
                6'd3:  decode_char = "3";
                6'd4:  decode_char = "4";
                6'd5:  decode_char = "5";
                6'd6:  decode_char = "6";
                6'd7:  decode_char = "7";
                6'd8:  decode_char = "8";
                6'd9:  decode_char = "9";
                6'd11: decode_char = "-";
                6'd14: decode_char = ".";
                6'd63: decode_char = " ";
                default: decode_char = "?";
            endcase
        end
    endfunction
    
    // Task to display result string
    task display_result;
        integer i;
        reg [7:0] char;
        begin
            $write("Result: \"");
            for (i = 0; i < 8; i = i + 1) begin
                char = decode_char(result[47 - i*6 -: 6]);
                $write("%c", char);
            end
            $write("\"\n");
        end
    endtask
    
    // Task to run a single test
    task run_test;
        input signed [31:0] test_value;
        input [127:0] description;
        begin
            $display("\n--- Test: %s ---", description);
            $display("Input Q16.16: 0x%08h (%f)", test_value, $itor(test_value) / 65536.0);
            
            start_conversion = 1;
            fp_value = test_value;
            @(posedge clk);
            start_conversion = 0;
            
            // Wait for conversion to complete
            wait(conversion_done);
            @(posedge clk);
            
            display_result();
        end
    endtask
    
    // Test stimulus
    initial begin
        $display("=== FP to String Sequential Testbench ===");
        
        // Initialize
        start_conversion = 0;
        fp_value = 0;
        
        // Wait a few cycles
        repeat(5) @(posedge clk);
        
        // Test cases
        run_test(32'h00000000, "Zero");
        run_test(32'h00010000, "One (1.0)");
        run_test(32'h00050000, "Five (5.0)");
        run_test(32'h000A0000, "Ten (10.0)");
        run_test(32'h007B0000, "123 (123.0)");
        run_test(32'h00018000, "1.5");
        run_test(32'h00024000, "2.25");
        run_test(32'h0003CCCD, "3.8 (approx)");
        run_test(32'h7FFFFFFF, "Max positive");
        run_test(32'hFFFF0000, "Negative one (-1.0)");
        run_test(32'hFFFB0000, "Negative five (-5.0)");
        run_test(32'hFFFE8000, "Negative 1.5 (-1.5)");
        run_test(32'h80000000, "Min negative");
        run_test(32'h00001999, "Small fraction (0.1)");
        run_test(32'h0000028F, "Tiny fraction (0.01)");
        
        // Wait a bit and finish
        repeat(10) @(posedge clk);
        $display("\n=== Testbench Complete ===");
        $finish;
    end
    
    // Timeout watchdog
    initial begin
        #100000;
        $display("ERROR: Testbench timeout!");
        $finish;
    end

endmodule


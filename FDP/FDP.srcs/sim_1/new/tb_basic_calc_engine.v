`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10/22/2025 03:56:29 PM
// Design Name: 
// Module Name: tb_basic_calc_engine
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

module tb_basic_calc_engine;

    // Clock and reset
    reg clk;
    reg rst;
    
    // Inputs
    reg input_valid;
    reg signed [31:0] input_val;
    reg op_valid;
    reg [1:0] op_sel;
    
    // Outputs
    wire signed [31:0] result;
    wire result_valid;
    wire overflow;
    wire div_by_zero;
    
    // Test tracking
    integer test_num;
    integer pass_count;
    integer fail_count;
    
    // Operation constants
    localparam OP_ADD = 2'b00;
    localparam OP_SUB = 2'b01;
    localparam OP_MUL = 2'b10;
    localparam OP_DIV = 2'b11;
    
    // DUT instantiation
    basic_calculator_engine dut (
        .clk(clk),
        .rst(rst),
        .input_valid(input_valid),
        .input_val(input_val),
        .op_valid(op_valid),
        .op_sel(op_sel),
        .result(result),
        .result_valid(result_valid),
        .overflow(overflow),
        .div_by_zero(div_by_zero)
    );
    
    // Clock generation (100MHz)
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end
    
    //=========================================================================
    // HELPER FUNCTIONS
    //=========================================================================
    
    // Convert Q16.16 to real
    function real fp_to_real;
        input signed [31:0] fp_val;
        begin
            fp_to_real = $itor(fp_val) / 65536.0;
        end
    endfunction
    
    // Convert real to Q16.16
    function signed [31:0] real_to_fp;
        input real val;
        begin
            real_to_fp = $rtoi(val * 65536.0);
        end
    endfunction
    
    //=========================================================================
    // TEST TASKS
    //=========================================================================
    
    // Task to input a number
    task input_number;
        input signed [31:0] value;
        begin
            @(posedge clk);
            input_valid = 1'b1;
            input_val = value;
            @(posedge clk);
            input_valid = 1'b0;
            
            // Wait for result_valid
            wait(result_valid);
            @(posedge clk);
        end
    endtask
    
    // Task to select operation
    task select_operation;
        input [1:0] operation;
        begin
            @(posedge clk);
            op_valid = 1'b1;
            op_sel = operation;
            @(posedge clk);
            op_valid = 1'b0;
            @(posedge clk);
        end
    endtask
    
    // Task to check result
    task check_result;
        input real expected;
        input real tolerance;
        input [255:0] test_name;
        real actual;
        real error;
        begin
            actual = fp_to_real(result);
            error = (actual - expected);
            if (error < 0) error = -error;
            
            $display("  Test: %s", test_name);
            $display("    Expected: %.4f (0x%08h)", expected, real_to_fp(expected));
            $display("    Actual:   %.4f (0x%08h)", actual, result);
            $display("    Error:    %.6f", error);
            
            if (overflow) $display("    [!] OVERFLOW detected");
            if (div_by_zero) $display("    [!] DIVIDE BY ZERO detected");
            
            if (error <= tolerance && !overflow) begin
                $display("    ? PASS");
                pass_count = pass_count + 1;
            end else begin
                $display("    ? FAIL");
                fail_count = fail_count + 1;
            end
            $display("");
        end
    endtask
    
    //=========================================================================
    // MAIN TEST SEQUENCE
    //=========================================================================
    
    initial begin
        $display("=================================================================");
        $display("Arithmetic Backend Optimized Testbench");
        $display("=================================================================\n");
        
        // Initialize
        test_num = 0;
        pass_count = 0;
        fail_count = 0;
        
        rst = 1;
        input_valid = 0;
        input_val = 0;
        op_valid = 0;
        op_sel = 0;
        
        // Reset sequence
        repeat(5) @(posedge clk);
        rst = 0;
        repeat(5) @(posedge clk);
        
        //=====================================================================
        // TEST 1: Simple Addition (10.5 + 5.25 = 15.75)
        //=====================================================================
        test_num = test_num + 1;
        $display("TEST %0d: Addition - 10.5 + 5.25", test_num);
        $display("-----------------------------------------------------------------");
        
        input_number(real_to_fp(10.5));
        select_operation(OP_ADD);
        input_number(real_to_fp(5.25));
        check_result(15.75, 0.01, "10.5 + 5.25 = 15.75");
        
        //=====================================================================
        // TEST 2: Subtraction (20.0 - 7.5 = 12.5)
        //=====================================================================
        test_num = test_num + 1;
        $display("TEST %0d: Subtraction - 20.0 - 7.5", test_num);
        $display("-----------------------------------------------------------------");
        
        input_number(real_to_fp(20.0));
        select_operation(OP_SUB);
        input_number(real_to_fp(7.5));
        check_result(12.5, 0.01, "20.0 - 7.5 = 12.5");
        
        //=====================================================================
        // TEST 3: Multiplication (4.0 * 2.5 = 10.0)
        //=====================================================================
        test_num = test_num + 1;
        $display("TEST %0d: Multiplication - 4.0 * 2.5", test_num);
        $display("-----------------------------------------------------------------");
        
        input_number(real_to_fp(4.0));
        select_operation(OP_MUL);
        input_number(real_to_fp(2.5));
        check_result(10.0, 0.01, "4.0 * 2.5 = 10.0");
        
        //=====================================================================
        // TEST 4: Division (10.0 / 2.0 = 5.0)
        //=====================================================================
        test_num = test_num + 1;
        $display("TEST %0d: Division - 10.0 / 2.0", test_num);
        $display("-----------------------------------------------------------------");
        
        input_number(real_to_fp(10.0));
        select_operation(OP_DIV);
        input_number(real_to_fp(2.0));
        check_result(5.0, 0.01, "10.0 / 2.0 = 5.0");
        
        //=====================================================================
        // TEST 5: Chain calculation (5 + 3 - 2 = 6)
        //=====================================================================
        test_num = test_num + 1;
        $display("TEST %0d: Chain calculation - 5 + 3 - 2", test_num);
        $display("-----------------------------------------------------------------");
        
        input_number(real_to_fp(5.0));
        select_operation(OP_ADD);
        input_number(real_to_fp(3.0));
        select_operation(OP_SUB);
        input_number(real_to_fp(2.0));
        check_result(6.0, 0.01, "(5 + 3) - 2 = 6");
        
        //=====================================================================
        // TEST 6: Negative numbers (-5.5 + 3.2 = -2.3)
        //=====================================================================
        test_num = test_num + 1;
        $display("TEST %0d: Negative addition - (-5.5) + 3.2", test_num);
        $display("-----------------------------------------------------------------");
        
        input_number(real_to_fp(-5.5));
        select_operation(OP_ADD);
        input_number(real_to_fp(3.2));
        check_result(-2.3, 0.01, "-5.5 + 3.2 = -2.3");
        
        //=====================================================================
        // TEST 7: Decimal precision (0.1 + 0.2 ? 0.3)
        //=====================================================================
        test_num = test_num + 1;
        $display("TEST %0d: Decimal precision - 0.1 + 0.2", test_num);
        $display("-----------------------------------------------------------------");
        
        input_number(real_to_fp(0.1));
        select_operation(OP_ADD);
        input_number(real_to_fp(0.2));
        check_result(0.3, 0.001, "0.1 + 0.2 ? 0.3");
        
        //=====================================================================
        // TEST 8: Fractional multiplication (1.5 * 1.5 = 2.25)
        //=====================================================================
        test_num = test_num + 1;
        $display("TEST %0d: Fractional multiply - 1.5 * 1.5", test_num);
        $display("-----------------------------------------------------------------");
        
        input_number(real_to_fp(1.5));
        select_operation(OP_MUL);
        input_number(real_to_fp(1.5));
        check_result(2.25, 0.01, "1.5 * 1.5 = 2.25");
        
        //=====================================================================
        // TEST 9: Fractional division (7.5 / 2.5 = 3.0)
        //=====================================================================
        test_num = test_num + 1;
        $display("TEST %0d: Fractional divide - 7.5 / 2.5", test_num);
        $display("-----------------------------------------------------------------");
        
        input_number(real_to_fp(7.5));
        select_operation(OP_DIV);
        input_number(real_to_fp(2.5));
        check_result(3.0, 0.01, "7.5 / 2.5 = 3.0");
        
        //=====================================================================
        // TEST 10: Division by zero
        //=====================================================================
        test_num = test_num + 1;
        $display("TEST %0d: Division by zero - 10.0 / 0.0", test_num);
        $display("-----------------------------------------------------------------");
        
        input_number(real_to_fp(10.0));
        select_operation(OP_DIV);
        input_number(real_to_fp(0.0));
        @(posedge clk);
        
        if (div_by_zero) begin
            $display("  ? PASS - Divide by zero detected correctly\n");
            pass_count = pass_count + 1;
        end else begin
            $display("  ? FAIL - Divide by zero not detected\n");
            fail_count = fail_count + 1;
        end
        
        //=====================================================================
        // TEST 11: Large numbers (1000.0 + 500.5 = 1500.5)
        //=====================================================================
        test_num = test_num + 1;
        $display("TEST %0d: Large numbers - 1000.0 + 500.5", test_num);
        $display("-----------------------------------------------------------------");
        
        input_number(real_to_fp(1000.0));
        select_operation(OP_ADD);
        input_number(real_to_fp(500.5));
        check_result(1500.5, 0.01, "1000.0 + 500.5 = 1500.5");
        
        //=====================================================================
        // TEST 12: Zero handling (0.0 + 5.0 = 5.0)
        //=====================================================================
        test_num = test_num + 1;
        $display("TEST %0d: Zero addition - 0.0 + 5.0", test_num);
        $display("-----------------------------------------------------------------");
        
        input_number(real_to_fp(0.0));
        select_operation(OP_ADD);
        input_number(real_to_fp(5.0));
        check_result(5.0, 0.01, "0.0 + 5.0 = 5.0");
        
        //=====================================================================
        // TEST 13: Multiply by zero (10.0 * 0.0 = 0.0)
        //=====================================================================
        test_num = test_num + 1;
        $display("TEST %0d: Multiply by zero - 10.0 * 0.0", test_num);
        $display("-----------------------------------------------------------------");
        
        input_number(real_to_fp(10.0));
        select_operation(OP_MUL);
        input_number(real_to_fp(0.0));
        check_result(0.0, 0.01, "10.0 * 0.0 = 0.0");
        
        //=====================================================================
        // TEST 14: Negative multiplication (-2.0 * 3.0 = -6.0)
        //=====================================================================
        test_num = test_num + 1;
        $display("TEST %0d: Negative multiply - (-2.0) * 3.0", test_num);
        $display("-----------------------------------------------------------------");
        
        input_number(real_to_fp(-2.0));
        select_operation(OP_MUL);
        input_number(real_to_fp(3.0));
        check_result(-6.0, 0.01, "-2.0 * 3.0 = -6.0");
        
        //=====================================================================
        // TEST 15: Negative division (-10.0 / 2.0 = -5.0)
        //=====================================================================
        test_num = test_num + 1;
        $display("TEST %0d: Negative divide - (-10.0) / 2.0", test_num);
        $display("-----------------------------------------------------------------");
        
        input_number(real_to_fp(-10.0));
        select_operation(OP_DIV);
        input_number(real_to_fp(2.0));
        check_result(-5.0, 0.01, "-10.0 / 2.0 = -5.0");
        
        //=====================================================================
        // TEST 16: Small decimals (0.25 + 0.75 = 1.0)
        //=====================================================================
        test_num = test_num + 1;
        $display("TEST %0d: Small decimals - 0.25 + 0.75", test_num);
        $display("-----------------------------------------------------------------");
        
        input_number(real_to_fp(0.25));
        select_operation(OP_ADD);
        input_number(real_to_fp(0.75));
        check_result(1.0, 0.01, "0.25 + 0.75 = 1.0");
        
        //=====================================================================
        // TEST 17: Complex chain (10 * 2 / 4 + 5 = 10)
        //=====================================================================
        test_num = test_num + 1;
        $display("TEST %0d: Complex chain - 10 * 2 / 4 + 5", test_num);
        $display("-----------------------------------------------------------------");
        
        input_number(real_to_fp(10.0));
        select_operation(OP_MUL);
        input_number(real_to_fp(2.0));
        select_operation(OP_DIV);
        input_number(real_to_fp(4.0));
        select_operation(OP_ADD);
        input_number(real_to_fp(5.0));
        check_result(10.0, 0.01, "((10 * 2) / 4) + 5 = 10");
        
        //=====================================================================
        // SUMMARY
        //=====================================================================
        repeat(10) @(posedge clk);
        
        $display("=================================================================");
        $display("TEST SUMMARY");
        $display("=================================================================");
        $display("Total Tests: %0d", pass_count + fail_count);
        $display("Passed:      %0d", pass_count);
        $display("Failed:      %0d", fail_count);
        
        if (fail_count == 0) begin
            $display("");
            $display("??? ALL TESTS PASSED! ???");
        end else begin
            $display("");
            $display("??? SOME TESTS FAILED ???");
        end
        $display("=================================================================");
        
        $finish;
    end
    
    // Timeout watchdog
    initial begin
        #1000000; // 1ms timeout
        $display("ERROR: Simulation timeout!");
        $finish;
    end
    
    // Optional: Waveform dump
    initial begin
        $dumpfile("basic_calculator_engine.vcd");
        $dumpvars(0, basic_calculator_engine);
    end

endmodule

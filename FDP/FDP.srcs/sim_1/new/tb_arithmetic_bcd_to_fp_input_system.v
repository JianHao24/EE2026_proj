`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10/19/2025 06:32:37 PM
// Design Name: 
// Module Name: tb_arithmetic_bcd_to_fp_input_system
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


module tb_arithmetic_bcd_to_fp_input_system;

    // Clock and reset
    reg clk;
    reg reset;
    
    // Inputs
    reg keypad_btn_pressed;
    reg [3:0] selected_keypad_value;
    reg is_active_mode;
    reg enable_negative;
    reg enable_backspace;
    
    // Outputs
    wire has_decimal;
    wire has_negative;
    wire [3:0] input_index;
    wire [31:0] bcd_value;
    wire [3:0] decimal_pos;
    wire signed [31:0] fp_value;
    wire input_complete;
    
    // Key definitions
    localparam KEY_0 = 4'd0;
    localparam KEY_1 = 4'd1;
    localparam KEY_2 = 4'd2;
    localparam KEY_3 = 4'd3;
    localparam KEY_4 = 4'd4;
    localparam KEY_5 = 4'd5;
    localparam KEY_6 = 4'd6;
    localparam KEY_7 = 4'd7;
    localparam KEY_8 = 4'd8;
    localparam KEY_9 = 4'd9;
    localparam KEY_DECIMAL = 4'd10;
    localparam KEY_SPECIAL = 4'd11;
    localparam KEY_ENTER = 4'd12;
    
    // Test tracking
    integer test_num;
    integer pass_count;
    integer fail_count;
    
    // DUT Instantiation
    bcd_to_fp_input_system #(
        .DIGIT_CAPACITY(8),
        .FIXED_FRAC_BITS(16)
    ) dut (
        .clk(clk),
        .reset(reset),
        .keypad_btn_pressed(keypad_btn_pressed),
        .selected_keypad_value(selected_keypad_value),
        .is_active_mode(is_active_mode),
        .enable_negative(enable_negative),
        .enable_backspace(enable_backspace),
        .has_decimal(has_decimal),
        .has_negative(has_negative),
        .input_index(input_index),
        .bcd_value(bcd_value),
        .decimal_pos(decimal_pos),
        .fp_value(fp_value),
        .input_complete(input_complete)
    );
    
    // Clock generation (10ns period = 100MHz)
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end
    
    // Helper task to press a key
    task press_key(input [3:0] key);
        begin
            @(posedge clk);
            keypad_btn_pressed = 1;
            selected_keypad_value = key;
            @(posedge clk);
            keypad_btn_pressed = 0;
            @(posedge clk);
        end
    endtask
    
    // Helper task to wait for conversion complete
    task wait_for_complete;
        integer i;
        begin
            for (i = 0; i < 50; i = i + 1) begin
                @(posedge clk);
                if (input_complete) begin
                    $display("  ? Conversion completed at time %0t", $time);
                    i = 50; // Exit loop
                end
            end
            if (!input_complete)
                $display("  ? ERROR: Conversion timeout!");
        end
    endtask
    
    // Helper function to convert fp_value to real
    function real fp_to_real(input signed [31:0] fp_val);
        real result;
        begin
            result = $itor(fp_val) / 65536.0;
            fp_to_real = result;
        end
    endfunction
    
    // Helper task to check result
    task check_result(input real expected, input real tolerance);
        real actual;
        real error;
        begin
            actual = fp_to_real(fp_value);
            error = (actual - expected);
            if (error < 0) error = -error;
            
            $display("  Expected: %f", expected);
            $display("  Actual:   %f", actual);
            $display("  FP Value: 0x%08h (%0d)", fp_value, fp_value);
            
            if (error <= tolerance) begin
                $display("  ? PASS - Within tolerance");
                pass_count = pass_count + 1;
            end else begin
                $display("  ? FAIL - Error: %f (tolerance: %f)", error, tolerance);
                fail_count = fail_count + 1;
            end
            $display("");
        end
    endtask
    
    // Main test procedure
    initial begin
        // Initialize
        test_num = 0;
        pass_count = 0;
        fail_count = 0;
        
        reset = 1;
        keypad_btn_pressed = 0;
        selected_keypad_value = 0;
        is_active_mode = 1;
        enable_negative = 0;
        enable_backspace = 0;
        
        $display("=================================================================");
        $display("Testbench for arithmetic_bcd_to_fp_input_system");
        $display("=================================================================");
        $display("");
        
        // Release reset
        repeat(5) @(posedge clk);
        reset = 0;
        repeat(5) @(posedge clk);
        
        // =====================================================================
        // TEST 1: Simple integer (12)
        // =====================================================================
        test_num = test_num + 1;
        $display("TEST %0d: Enter integer 12", test_num);
        $display("-----------------------------------------------------------------");
        
        press_key(KEY_1);
        press_key(KEY_2);
        press_key(KEY_ENTER);
        wait_for_complete();
        check_result(12.0, 0.01);
        
        // Reset for next test
        reset = 1;
        repeat(5) @(posedge clk);
        reset = 0;
        repeat(5) @(posedge clk);
        
        // =====================================================================
        // TEST 2: Decimal number (3.14)
        // =====================================================================
        test_num = test_num + 1;
        $display("TEST %0d: Enter decimal 3.14", test_num);
        $display("-----------------------------------------------------------------");
        
        press_key(KEY_3);
        press_key(KEY_DECIMAL);
        press_key(KEY_1);
        press_key(KEY_4);
        press_key(KEY_ENTER);
        wait_for_complete();
        check_result(3.14, 0.01);
        
        reset = 1;
        repeat(5) @(posedge clk);
        reset = 0;
        repeat(5) @(posedge clk);
        
        // =====================================================================
        // TEST 3: Negative number with enable_negative (-5)
        // =====================================================================
        test_num = test_num + 1;
        enable_negative = 1;
        $display("TEST %0d: Enter negative number -5", test_num);
        $display("-----------------------------------------------------------------");
        
        press_key(KEY_SPECIAL);  // Negative sign
        press_key(KEY_5);
        press_key(KEY_ENTER);
        wait_for_complete();
        check_result(-5.0, 0.01);
        
        enable_negative = 0;
        reset = 1;
        repeat(5) @(posedge clk);
        reset = 0;
        repeat(5) @(posedge clk);
        
        // =====================================================================
        // TEST 4: Negative decimal (-12.5)
        // =====================================================================
        test_num = test_num + 1;
        enable_negative = 1;
        $display("TEST %0d: Enter negative decimal -12.5", test_num);
        $display("-----------------------------------------------------------------");
        
        press_key(KEY_SPECIAL);  // Negative sign
        press_key(KEY_1);
        press_key(KEY_2);
        press_key(KEY_DECIMAL);
        press_key(KEY_5);
        press_key(KEY_ENTER);
        wait_for_complete();
        check_result(-12.5, 0.01);
        
        enable_negative = 0;
        reset = 1;
        repeat(5) @(posedge clk);
        reset = 0;
        repeat(5) @(posedge clk);
        
        // =====================================================================
        // TEST 5: Backspace functionality (123 -> 12)
        // =====================================================================
        test_num = test_num + 1;
        enable_backspace = 1;
        $display("TEST %0d: Test backspace (123 -> backspace -> 12)", test_num);
        $display("-----------------------------------------------------------------");
        
        press_key(KEY_1);
        press_key(KEY_2);
        press_key(KEY_3);
        $display("  Entered 123, now pressing backspace...");
        press_key(KEY_SPECIAL);  // Backspace
        press_key(KEY_ENTER);
        wait_for_complete();
        check_result(12.0, 0.01);
        
        enable_backspace = 0;
        reset = 1;
        repeat(5) @(posedge clk);
        reset = 0;
        repeat(5) @(posedge clk);
        
        // =====================================================================
        // TEST 6: Zero with decimal (0.5)
        // =====================================================================
        test_num = test_num + 1;
        $display("TEST %0d: Enter 0.5", test_num);
        $display("-----------------------------------------------------------------");
        
        press_key(KEY_0);
        press_key(KEY_DECIMAL);
        press_key(KEY_5);
        press_key(KEY_ENTER);
        wait_for_complete();
        check_result(0.5, 0.01);
        
        reset = 1;
        repeat(5) @(posedge clk);
        reset = 0;
        repeat(5) @(posedge clk);
        
        // =====================================================================
        // TEST 7: Large number (9999)
        // =====================================================================
        test_num = test_num + 1;
        $display("TEST %0d: Enter large number 9999", test_num);
        $display("-----------------------------------------------------------------");
        
        press_key(KEY_9);
        press_key(KEY_9);
        press_key(KEY_9);
        press_key(KEY_9);
        press_key(KEY_ENTER);
        wait_for_complete();
        check_result(9999.0, 0.01);
        
        reset = 1;
        repeat(5) @(posedge clk);
        reset = 0;
        repeat(5) @(posedge clk);
        
        // =====================================================================
        // TEST 8: Multiple decimal places (1.234)
        // =====================================================================
        test_num = test_num + 1;
        $display("TEST %0d: Enter 1.234", test_num);
        $display("-----------------------------------------------------------------");
        
        press_key(KEY_1);
        press_key(KEY_DECIMAL);
        press_key(KEY_2);
        press_key(KEY_3);
        press_key(KEY_4);
        press_key(KEY_ENTER);
        wait_for_complete();
        check_result(1.234, 0.01);
        
        reset = 1;
        repeat(5) @(posedge clk);
        reset = 0;
        repeat(5) @(posedge clk);
        
        // =====================================================================
        // TEST 9: Leading decimal (.75)
        // =====================================================================
        test_num = test_num + 1;
        $display("TEST %0d: Enter .75 (leading decimal)", test_num);
        $display("-----------------------------------------------------------------");
        
        press_key(KEY_DECIMAL);
        press_key(KEY_7);
        press_key(KEY_5);
        press_key(KEY_ENTER);
        wait_for_complete();
        check_result(0.75, 0.01);
        
        reset = 1;
        repeat(5) @(posedge clk);
        reset = 0;
        repeat(5) @(posedge clk);
        
        // =====================================================================
        // TEST 10: Check has_decimal flag
        // =====================================================================
        test_num = test_num + 1;
        $display("TEST %0d: Verify has_decimal flag", test_num);
        $display("-----------------------------------------------------------------");
        
        press_key(KEY_5);
        @(posedge clk);
        if (has_decimal == 0) begin
            $display("  ? has_decimal correctly 0 after digit");
            pass_count = pass_count + 1;
        end else begin
            $display("  ? has_decimal should be 0");
            fail_count = fail_count + 1;
        end
        
        press_key(KEY_DECIMAL);
        @(posedge clk);
        if (has_decimal == 1) begin
            $display("  ? has_decimal correctly 1 after decimal");
            pass_count = pass_count + 1;
        end else begin
            $display("  ? has_decimal should be 1");
            fail_count = fail_count + 1;
        end
        $display("");
        
        // =====================================================================
        // SUMMARY
        // =====================================================================
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
    
    // Optional: Waveform dump for viewing
    initial begin
        $dumpfile("arithmetic_bcd_to_fp_tb.vcd");
        $dumpvars(0, tb_arithmetic_bcd_to_fp_input_system);
    end

endmodule
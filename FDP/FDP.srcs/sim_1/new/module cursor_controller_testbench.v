`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11/06/2025 09:42:10 PM
// Design Name: 
// Module Name: module cursor_controller_testbench
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


module cursor_controller_testbench;

    reg clk = 0;
    reg reset = 0;
    reg btnC = 0, btnU = 0, btnD = 0, btnL = 0, btnR = 0;
    reg is_operand_mode = 0;
    
    // Outputs for original module
    wire [1:0] cursor_row_keypad_orig, cursor_row_operand_orig;
    wire [2:0] cursor_col_keypad_orig;
    wire [1:0] cursor_col_operand_orig;
    wire keypad_btn_pressed_orig, operand_btn_pressed_orig;
    wire [3:0] keypad_selected_value_orig;
    wire [1:0] operand_selected_value_orig;
    
    // Outputs for refactored module
    wire [1:0] cursor_row_keypad_new, cursor_row_operand_new;
    wire [2:0] cursor_col_keypad_new;
    wire [1:0] cursor_col_operand_new;
    wire keypad_btn_pressed_new, operand_btn_pressed_new;
    wire [3:0] keypad_selected_value_new;
    wire [1:0] operand_selected_value_new;
    
    // Instantiate original module
    arithmetic_cursor_controller_original orig (
        .clk(clk),
        .reset(reset),
        .btnC(btnC), .btnU(btnU), .btnD(btnD), .btnL(btnL), .btnR(btnR),
        .is_operand_mode(is_operand_mode),
        .cursor_row_keypad(cursor_row_keypad_orig),
        .cursor_col_keypad(cursor_col_keypad_orig),
        .cursor_row_operand(cursor_row_operand_orig),
        .cursor_col_operand(cursor_col_operand_orig),
        .keypad_btn_pressed(keypad_btn_pressed_orig),
        .keypad_selected_value(keypad_selected_value_orig),
        .operand_btn_pressed(operand_btn_pressed_orig),
        .operand_selected_value(operand_selected_value_orig)
    );
    
    // Instantiate refactored module
    arithmetic_cursor new (
        .clk(clk),
        .reset(reset),
        .btnC(btnC), .btnU(btnU), .btnD(btnD), .btnL(btnL), .btnR(btnR),
        .waiting_operand(is_operand_mode),
        .cursor_row_keypad(cursor_row_keypad_new),
        .cursor_col_keypad(cursor_col_keypad_new),
        .cursor_row_operand(cursor_row_operand_new),
        .cursor_col_operand(cursor_col_operand_new),
        .keypad_btn_pressed(keypad_btn_pressed_new),
        .keypad_selected_value(keypad_selected_value_new),
        .operand_btn_pressed(operand_btn_pressed_new),
        .operand_selected_value(operand_selected_value_new)
    );
    
    // Clock generation
    always #5 clk = ~clk;
    
    // Error checking
    integer errors = 0;
    always @(posedge clk) begin
        if (!reset) begin
            if (cursor_row_keypad_orig !== cursor_row_keypad_new) begin
                $display("ERROR at %0t: cursor_row_keypad mismatch! orig=%0d new=%0d", 
                         $time, cursor_row_keypad_orig, cursor_row_keypad_new);
                errors = errors + 1;
            end
            if (cursor_col_keypad_orig !== cursor_col_keypad_new) begin
                $display("ERROR at %0t: cursor_col_keypad mismatch! orig=%0d new=%0d", 
                         $time, cursor_col_keypad_orig, cursor_col_keypad_new);
                errors = errors + 1;
            end
            if (cursor_row_operand_orig !== cursor_row_operand_new) begin
                $display("ERROR at %0t: cursor_row_operand mismatch! orig=%0d new=%0d", 
                         $time, cursor_row_operand_orig, cursor_row_operand_new);
                errors = errors + 1;
            end
            if (cursor_col_operand_orig !== cursor_col_operand_new) begin
                $display("ERROR at %0t: cursor_col_operand mismatch! orig=%0d new=%0d", 
                         $time, cursor_col_operand_orig, cursor_col_operand_new);
                errors = errors + 1;
            end
            if (keypad_btn_pressed_orig !== keypad_btn_pressed_new) begin
                $display("ERROR at %0t: keypad_btn_pressed mismatch! orig=%0d new=%0d", 
                         $time, keypad_btn_pressed_orig, keypad_btn_pressed_new);
                errors = errors + 1;
            end
            if (keypad_selected_value_orig !== keypad_selected_value_new) begin
                $display("ERROR at %0t: keypad_selected_value mismatch! orig=%0d new=%0d", 
                         $time, keypad_selected_value_orig, keypad_selected_value_new);
                errors = errors + 1;
            end
            if (operand_btn_pressed_orig !== operand_btn_pressed_new) begin
                $display("ERROR at %0t: operand_btn_pressed mismatch! orig=%0d new=%0d", 
                         $time, operand_btn_pressed_orig, operand_btn_pressed_new);
                errors = errors + 1;
            end
            if (operand_selected_value_orig !== operand_selected_value_new) begin
                $display("ERROR at %0t: operand_selected_value mismatch! orig=%0d new=%0d", 
                         $time, operand_selected_value_orig, operand_selected_value_new);
                errors = errors + 1;
            end
        end
    end
    
    // Test stimulus
    task press_button;
        input [4:0] button; // {C, U, D, L, R}
        input integer cycles;
        begin
            {btnC, btnU, btnD, btnL, btnR} = button;
            repeat(cycles) @(posedge clk);
            {btnC, btnU, btnD, btnL, btnR} = 5'b00000;
            repeat(5) @(posedge clk);
        end
    endtask
    
    initial begin
        $display("=== Starting Cursor Controller Comparison Test ===");
        
        // Test 1: Reset
        $display("\nTest 1: Reset functionality");
        reset = 1;
        repeat(10) @(posedge clk);
        reset = 0;
        repeat(10) @(posedge clk);
        
        // Test 2: Keypad navigation
        $display("\nTest 2: Keypad mode navigation");
        is_operand_mode = 0;
        
        // Move down
        $display("  - Moving down in keypad");
        press_button(5'b00100, 10); // btnD
        repeat(210) @(posedge clk);
        
        // Move right
        $display("  - Moving right in keypad");
        press_button(5'b00001, 10); // btnR
        repeat(210) @(posedge clk);
        
        // Move up
        $display("  - Moving up in keypad");
        press_button(5'b01000, 10); // btnU
        repeat(210) @(posedge clk);
        
        // Move left
        $display("  - Moving left in keypad");
        press_button(5'b00010, 10); // btnL
        repeat(210) @(posedge clk);
        
        // Test 3: Keypad selection
        $display("\nTest 3: Keypad selection");
        repeat(510) @(posedge clk); // Wait for counter
        press_button(5'b10000, 10); // btnC
        repeat(10) @(posedge clk);
        
        // Test 4: Navigate to checkmark
        $display("\nTest 4: Navigate to checkmark");
        repeat(510) @(posedge clk);
        press_button(5'b00001, 10); // btnR
        repeat(210) @(posedge clk);
        press_button(5'b00001, 10); // btnR
        repeat(210) @(posedge clk);
        press_button(5'b00001, 10); // btnR (should go to checkmark)
        repeat(210) @(posedge clk);
        
        // Select checkmark
        $display("  - Selecting checkmark");
        press_button(5'b10000, 10); // btnC
        repeat(10) @(posedge clk);
        
        // Test 5: Navigate back from checkmark
        $display("\nTest 5: Navigate back from checkmark");
        repeat(510) @(posedge clk);
        press_button(5'b00010, 10); // btnL (should return to col 2)
        repeat(210) @(posedge clk);
        
        // Test 6: Switch to operand mode
        $display("\nTest 6: Operand mode navigation");
        is_operand_mode = 1;
        repeat(10) @(posedge clk);
        
        // Navigate in operand mode
        press_button(5'b00100, 10); // btnD
        repeat(210) @(posedge clk);
        press_button(5'b00001, 10); // btnR
        repeat(210) @(posedge clk);
        
        // Test 7: Operand selection
        $display("\nTest 7: Operand selection");
        press_button(5'b10000, 10); // btnC
        repeat(10) @(posedge clk);
        
        // Test 8: More operand navigation
        press_button(5'b01000, 10); // btnU
        repeat(210) @(posedge clk);
        press_button(5'b00010, 10); // btnL
        repeat(210) @(posedge clk);
        press_button(5'b10000, 10); // btnC
        repeat(10) @(posedge clk);
        
        // Test 9: Boundary conditions in keypad mode
        $display("\nTest 9: Keypad boundary conditions");
        is_operand_mode = 0;
        reset = 1;
        repeat(10) @(posedge clk);
        reset = 0;
        repeat(510) @(posedge clk);
        
        // Try to move up from top
        press_button(5'b01000, 10); // btnU (should not move)
        repeat(210) @(posedge clk);
        
        // Try to move left from leftmost
        press_button(5'b00010, 10); // btnL (should not move)
        repeat(210) @(posedge clk);
        
        // Move to bottom-right corner
        repeat(3) begin
            press_button(5'b00100, 10); // btnD
            repeat(210) @(posedge clk);
        end
        repeat(2) begin
            press_button(5'b00001, 10); // btnR
            repeat(210) @(posedge clk);
        end
        
        // Try to move beyond boundaries
        press_button(5'b00100, 10); // btnD (should not move)
        repeat(210) @(posedge clk);
        
        // Test 10: Rapid button presses (debouncing test)
        $display("\nTest 10: Debouncing test");
        repeat(5) begin
            press_button(5'b01000, 3); // Quick presses
        end
        repeat(300) @(posedge clk);
        
        // Final report
        repeat(50) @(posedge clk);
        $display("\n=== Test Complete ===");
        if (errors == 0) begin
            $display("SUCCESS: All tests passed! Modules are functionally identical.");
        end else begin
            $display("FAILURE: Found %0d mismatches between modules.", errors);
        end
        
        $finish;
    end
    
    // Timeout
    initial begin
        #100000;
        $display("\nERROR: Testbench timeout!");
        $finish;
    end

endmodule

// Original module (paste your original code here with module name changed)
module arithmetic_cursor_controller_original(
    input clk,
    input reset,
    input btnC,
    input btnU,
    input btnD,
    input btnL,
    input btnR,
    input is_operand_mode,
    output reg [1:0]cursor_row_keypad = 0,
    output reg [2:0]cursor_col_keypad = 0,
    output reg [1:0]cursor_row_operand = 0,
    output reg [1:0]cursor_col_operand = 0,
    output reg keypad_btn_pressed = 0,
    output reg [3:0]keypad_selected_value = 0,
    output reg operand_btn_pressed = 0,
    output reg [1:0]operand_selected_value = 0
    );

    reg prev_btnC = 0;
    reg prev_btnU = 0;
    reg prev_btnD = 0;
    reg prev_btnL = 0;
    reg prev_btnR = 0;

    reg [7:0] debounce_C = 0;
    reg [7:0] debounce_U = 0;
    reg [7:0] debounce_D = 0;
    reg [7:0] debounce_L = 0;
    reg [7:0] debounce_R = 0;

    reg [8:0] counter = 9'd500;

    wire on_checkmark = (cursor_col_keypad == 3'd3 && !is_operand_mode);

    always @ (posedge clk) begin
        if (reset) begin
            cursor_row_keypad <= 0;
            cursor_col_keypad <= 0;
            cursor_row_operand <= 0;
            cursor_col_operand <= 0;
            keypad_btn_pressed <= 0;
            keypad_selected_value <= 0;
            operand_btn_pressed <= 0;
            operand_selected_value <= 0;
            prev_btnC <= 0;
            prev_btnU <= 0;
            prev_btnD <= 0;
            prev_btnL <= 0;
            prev_btnR <= 0;
            debounce_C <= 0;
            debounce_U <= 0;
            debounce_D <= 0;
            debounce_L <= 0;
            debounce_R <= 0;
            counter <= 500;
        end
        else begin
            keypad_btn_pressed <= 0;
            operand_btn_pressed <= 0;
        
            if (debounce_U > 0) debounce_U <= debounce_U - 1;
            if (debounce_D > 0) debounce_D <= debounce_D - 1;
            if (debounce_L > 0) debounce_L <= debounce_L - 1;
            if (debounce_R > 0) debounce_R <= debounce_R - 1;
            if (debounce_C > 0) debounce_C <= debounce_C - 1;

            if (!is_operand_mode) begin
                if (counter == 0) begin
                    if (btnU && !prev_btnU && debounce_U == 0) begin
                        if (cursor_row_keypad > 0 && !on_checkmark) begin
                            cursor_row_keypad <= cursor_row_keypad - 1;
                        end
                        debounce_U <= 200;
                    end

                    if (btnD && !prev_btnD && debounce_D == 0) begin
                        if (cursor_row_keypad < 3 && !on_checkmark) begin
                            cursor_row_keypad <= cursor_row_keypad + 1;
                        end
                        debounce_D <= 200;
                    end

                    if (btnL && !prev_btnL && debounce_L == 0) begin
                        if (on_checkmark) begin
                            cursor_col_keypad <= 3'd2;
                        end else if (cursor_col_keypad > 0) begin
                            cursor_col_keypad <= cursor_col_keypad - 1;
                        end
                        debounce_L <= 200;
                    end

                    if (btnR && !prev_btnR && debounce_R == 0) begin
                        if (!on_checkmark && cursor_col_keypad < 2) begin
                            cursor_col_keypad <= cursor_col_keypad + 1;
                        end else if (!on_checkmark && cursor_col_keypad == 2) begin
                            cursor_col_keypad <= 3'd3;
                        end
                        debounce_R <= 200;
                    end

                    if (btnC && !prev_btnC && debounce_C == 0) begin
                        keypad_btn_pressed <= 1;
                        counter <= 500;
                        if (on_checkmark) begin
                            keypad_selected_value <= 4'd12;
                        end else begin
                            case(cursor_row_keypad)
                                2'd0: keypad_selected_value <= cursor_col_keypad + 4'd7;
                                2'd1: keypad_selected_value <= cursor_col_keypad + 4'd4;
                                2'd2: keypad_selected_value <= cursor_col_keypad + 4'd1;
                                2'd3: begin
                                    case(cursor_col_keypad)
                                        2'd0: keypad_selected_value <= 4'd0;
                                        2'd1: keypad_selected_value <= 4'd10;
                                        2'd2: keypad_selected_value <= 4'd11;
                                    endcase
                                end
                            endcase
                        end
                        debounce_C <= 200;
                    end
                end
                else begin
                    counter <= counter -1;
                end
            end
            else begin
                if (btnU && !prev_btnU && debounce_U == 0) begin
                    if (cursor_row_operand > 0) begin
                        cursor_row_operand <= cursor_row_operand - 1;
                    end
                    debounce_U <= 200;
                end
            
                if (btnD && !prev_btnD && debounce_D == 0) begin
                    if (cursor_row_operand < 1) begin  
                        cursor_row_operand <= cursor_row_operand + 1;
                    end
                    debounce_D <= 200;
                end
            
                if (btnL && !prev_btnL && debounce_L == 0) begin
                    if (cursor_col_operand > 0) begin
                        cursor_col_operand <= cursor_col_operand - 1;
                    end
                    debounce_L <= 200;
                end
            
                if (btnR && !prev_btnR && debounce_R == 0) begin
                    if (cursor_col_operand < 1) begin  
                        cursor_col_operand <= cursor_col_operand + 1;
                    end
                    debounce_R <= 200;
                end
            
                if (btnC && !prev_btnC && debounce_C == 0) begin
                    operand_btn_pressed <= 1;
                    case({cursor_row_operand, cursor_col_operand})
                        4'b00_00: operand_selected_value <= 2'd0;
                        4'b00_01: operand_selected_value <= 2'd1;
                        4'b01_00: operand_selected_value <= 2'd2;
                        4'b01_01: operand_selected_value <= 2'd3;
                    endcase
                    debounce_C <= 200;
                end
            end

            prev_btnU <= btnU;
            prev_btnD <= btnD;
            prev_btnL <= btnL;
            prev_btnR <= btnR;
            prev_btnC <= btnC;
        end
    end
endmodule

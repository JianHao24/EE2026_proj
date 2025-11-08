`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 20.03.2025 11:22:53
// Design Name: 
// Module Name: polynomial_table_cursor_controller
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

/*
This module is responsible for controlling cursor movement when the table mode is active.
In is_table_input_mode, the cursor will interface with polynomial_table_keypad_display to gather user input which is sent over to input_bcd_to_fp_builder_table.
The updated input value will subsequently used in computations.

In regular is_table_mode, only the up-down buttons will be active which in theory, should allow the user to scroll through input values.
*/
module polynomial_table_cursor_controller(
    input [6:0] mouse_xpos,
    input [6:0] mouse_ypos,
    input mouse_left,        //used to click
    input mouse_middle,     //used only in table mode, want to switch back to the keypad
    input clk,
    input clk_100MHz,
    input btnC,
    input btnU,
    input btnD,
    input btnL,
    input btnR,
    input is_table_mode,
    input use_mouse,        //flip sw[0] if want to use mouse

    // From input_bcd_to_fp_builder_table
    input input_complete,
    input signed [31:0] fp_input_value,

    output reg is_table_input_mode = 0,
    output reg [1:0] cursor_row = 0,
    output reg [2:0] cursor_col = 0,
    output reg keypad_btn_pressed = 0,
    output reg [3:0] keypad_selected_value = 0,
    output reg signed [31:0] starting_x = 0
    );

    // Previous button states for debouncing
    reg prev_btnC = 0;
    reg prev_btnU = 0;
    reg prev_btnD = 0;
    reg prev_btnL = 0;
    reg prev_btnR = 0;

    // Debouncing counters
    reg [7:0] debounce_C = 0;
    reg [7:0] debounce_U = 0;
    reg [7:0] debounce_D = 0;
    reg [7:0] debounce_L = 0;
    reg [7:0] debounce_R = 0;
    
    //debouncing for left mouse button
    parameter DEBOUNCE_DELAY = 2000000;
    reg [21:0] counter;    // Counter for debounce delay (needs enough bits)
    reg debounced;         // Stores the debounced state
    initial begin
        counter   = 0;
        debounced = 1'b0;
    end
    always @(posedge clk_100MHz) begin
            if (mouse_left == debounced) 
                counter <= 0;
            else begin
                counter <= counter + 1;
                if (counter >= DEBOUNCE_DELAY) debounced <= mouse_left;
            
            end
    end
    reg mouse_left_prev;
    initial begin mouse_left_prev = 1'b0; end
    
    // Flag to track if on the checkmark
    wire on_checkmark = (cursor_col == 3'd3 && is_table_input_mode);
   
    
    
    always @ (posedge clk) begin
      if (!use_mouse) begin
        // Resetting button pressed on each cycle
        keypad_btn_pressed <= 0;

        // Decrement debounce counters
        if (debounce_U > 0) debounce_U <= debounce_U - 1;
        if (debounce_D > 0) debounce_D <= debounce_D - 1;
        if (debounce_L > 0) debounce_L <= debounce_L - 1;
        if (debounce_R > 0) debounce_R <= debounce_R - 1;
        if (debounce_C > 0) debounce_C <= debounce_C - 1;

        // Only processing buttons if in table mode
        if (is_table_mode) begin

            // Switching between table navigation mode and input mode
            if (btnC && !prev_btnC && debounce_C == 0 || mouse_middle) begin
            //it will also switch if you press the scroll wheel btn
                debounce_C <= 200;

                // Transition to table input mode
                if (!is_table_input_mode) begin
                    is_table_input_mode <= 1;
                    
                    // Resetting cursor positions
                    cursor_row <= 0;
                    cursor_col <= 0;
                end

                // Switching from input mode to table navigation mode requires checkmark input
            end

            // Cursor movement and input selection logic
            if (is_table_input_mode) begin
                
                // Updating starting_x when input is complete (to check)
                if (input_complete) begin
                    starting_x <= fp_input_value;
                    is_table_input_mode <= 0;
                end
                
                // Up button
                if (btnU && !prev_btnU && debounce_U == 0) begin
                    debounce_U <= 200;

                    if (!on_checkmark) begin
                        if (cursor_row > 0) begin
                            cursor_row <= cursor_row - 1;
                        end
                        else begin
                            // Wrap around
                            cursor_row <= 3;
                        end
                    end
                end

                // Down button
                if (btnD && !prev_btnD && debounce_D == 0) begin
                    debounce_D <= 200;

                    if (!on_checkmark) begin
                        if (cursor_row < 3) begin
                            cursor_row <= cursor_row + 1;
                        end
                        else begin
                            cursor_row <= 0;
                        end
                    end
                end

                // Left button
                if (btnL && !prev_btnL && debounce_L == 0) begin
                    debounce_L <= 200;

                    if (on_checkmark) begin
                        cursor_col <= 2;
                    end
                    else if (cursor_col > 0) begin
                        cursor_col <= cursor_col - 1;
                    end
                    else begin
                        cursor_col <= on_checkmark ? 2 : 3;
                    end
                end

                // Right button
                if (btnR && !prev_btnR && debounce_R == 0) begin
                    debounce_R <= 200;

                    if (on_checkmark) begin
                        cursor_col <= 0;
                    end
                    else if (cursor_col < 4) begin
                        cursor_col <= cursor_col + 1;
                    end
                end

                // Center button (input selection)
                if (btnC && !prev_btnC && debounce_C == 0) begin
                    debounce_C <= 200;
                    keypad_btn_pressed <= 1;

                    // Transition out of input mode
                    if (on_checkmark) begin
                        // is_table_input_mode <= 0;
                        keypad_selected_value <= 4'd12;
                    end
                    else begin
                        // Determine selected value based on cursor position
                        case ({cursor_row, cursor_col})
                            {2'd0, 3'd0}: keypad_selected_value <= 4'd7; // 7
                            {2'd0, 3'd1}: keypad_selected_value <= 4'd8; // 8
                            {2'd0, 3'd2}: keypad_selected_value <= 4'd9; // 9
                            {2'd1, 3'd0}: keypad_selected_value <= 4'd4; // 4
                            {2'd1, 3'd1}: keypad_selected_value <= 4'd5; // 5
                            {2'd1, 3'd2}: keypad_selected_value <= 4'd6; // 6
                            {2'd2, 3'd0}: keypad_selected_value <= 4'd1; // 1
                            {2'd2, 3'd1}: keypad_selected_value <= 4'd2; // 2
                            {2'd2, 3'd2}: keypad_selected_value <= 4'd3; // 3
                            {2'd3, 3'd0}: keypad_selected_value <= 4'd0; // 0
                            {2'd3, 3'd1}: keypad_selected_value <= 4'd10; // Decimal point
                            {2'd3, 3'd2}: keypad_selected_value <= 4'd11; // Negative sign
                            default: keypad_btn_pressed <= 0; // Invalid position
                        endcase
                    end
                end
            end
            else begin
                

                // Navigation Mode
                if (btnU && !prev_btnU && debounce_U == 0) begin
                    debounce_U <= 200;
                    starting_x <= starting_x + 32'h00010000; // Add 1.0 in fixed point
                end
                
                if (btnD && !prev_btnD && debounce_D == 0) begin
                    debounce_D <= 200;
                    starting_x <= starting_x - 32'h00010000; // Subtract 1.0 in fixed point
                end
            end
        end
        else begin
            starting_x <= 0;
            is_table_input_mode <= 0;
        end

        // Update previous button states
        prev_btnU <= btnU;
        prev_btnD <= btnD;
        prev_btnL <= btnL;
        prev_btnR <= btnR;
        prev_btnC <= btnC;
        end
      else if (use_mouse) begin
      
      keypad_btn_pressed <= 0;
      if (debounce_C > 0) debounce_C <= debounce_C - 1;
      if (btnC && !prev_btnC && debounce_C == 0 || mouse_middle) begin
                  //it will also switch if you press the scroll wheel btn
                      debounce_C <= 200;
      
                      // Transition to table input mode
                      if (!is_table_input_mode) begin
                          is_table_input_mode <= 1;
                          
                          // Resetting cursor positions
                          cursor_row <= 0;
                          cursor_col <= 0;
                      end
      
                      // Switching from input mode to table navigation mode requires checkmark input
                  end
         if (is_table_input_mode) begin
            if (input_complete) begin
                starting_x <= fp_input_value;
                is_table_input_mode <= 0;
            end
            if (mouse_xpos >= 0 && mouse_xpos <= 23 && mouse_ypos >= 0 && mouse_ypos <= 15) begin
                cursor_row <= 0;
                cursor_col <= 0;
            end
            else if (mouse_xpos >= 0 && mouse_xpos <= 23 && mouse_ypos >= 16 && mouse_ypos <= 31) begin
                cursor_row <= 1;
                cursor_col <= 0;
            end
            else if (mouse_xpos >= 0 && mouse_xpos <= 23 && mouse_ypos >= 32 && mouse_ypos <= 47) begin
                cursor_row <= 2;
                cursor_col <= 0;
            end
            else if (mouse_xpos >= 0 && mouse_xpos <= 23 && mouse_ypos >= 48 && mouse_ypos <= 63) begin
                cursor_row <= 3;
                cursor_col <= 0;
            end
            else if (mouse_xpos >= 24 && mouse_xpos <= 47 && mouse_ypos >= 0 && mouse_ypos <= 15) begin
                cursor_row <= 0;
                cursor_col <= 1;
            end
            else if (mouse_xpos >= 24 && mouse_xpos <= 47 && mouse_ypos >= 16 && mouse_ypos <= 31) begin
                cursor_row <= 1;
                cursor_col <= 1;
            end
            else if (mouse_xpos >= 24 && mouse_xpos <= 47 && mouse_ypos >= 32 && mouse_ypos <= 47) begin
                cursor_row <= 2;
                cursor_col <= 1;
            end
            else if (mouse_xpos >= 24 && mouse_xpos <= 47 && mouse_ypos >= 48 && mouse_ypos <= 63) begin
                cursor_row <= 3;
                cursor_col <= 1;
            end
            else if (mouse_xpos >= 48 && mouse_xpos <= 71 && mouse_ypos >= 0 && mouse_ypos <= 15) begin
                cursor_row <= 0;
                cursor_col <= 2;
            end
            else if (mouse_xpos >= 48 && mouse_xpos <= 71 && mouse_ypos >= 16 && mouse_ypos <= 31) begin
                cursor_row <= 1;
                cursor_col <= 2;
            end
            else if (mouse_xpos >= 48 && mouse_xpos <= 71 && mouse_ypos >= 32 && mouse_ypos <= 47) begin
                cursor_row <= 2;
                cursor_col <= 2;
            end
            else if (mouse_xpos >= 48 && mouse_xpos <= 71 && mouse_ypos >= 48 && mouse_ypos <= 63) begin
                cursor_row <= 3;
                cursor_col <= 2;
            end
          else begin //this is the checkmark side
                cursor_col <= 3;
          end
          if (debounced && !mouse_left_prev) begin
            keypad_btn_pressed <= 1;
            if (on_checkmark) begin
                // is_table_input_mode <= 0;                   
                keypad_selected_value <= 4'd12;
            end
            else begin
                // Determine selected value based on cursor position
                    case ({cursor_row, cursor_col})
                        {2'd0, 3'd0}: keypad_selected_value <= 4'd7; // 7
                        {2'd0, 3'd1}: keypad_selected_value <= 4'd8; // 8
                        {2'd0, 3'd2}: keypad_selected_value <= 4'd9; // 9
                        {2'd1, 3'd0}: keypad_selected_value <= 4'd4; // 4
                        {2'd1, 3'd1}: keypad_selected_value <= 4'd5; // 5
                        {2'd1, 3'd2}: keypad_selected_value <= 4'd6; // 6
                        {2'd2, 3'd0}: keypad_selected_value <= 4'd1; // 1
                        {2'd2, 3'd1}: keypad_selected_value <= 4'd2; // 2
                        {2'd2, 3'd2}: keypad_selected_value <= 4'd3; // 3
                        {2'd3, 3'd0}: keypad_selected_value <= 4'd0; // 0
                        {2'd3, 3'd1}: keypad_selected_value <= 4'd10; // Decimal point
                        {2'd3, 3'd2}: keypad_selected_value <= 4'd11; // Negative sign
                        default: keypad_btn_pressed <= 0; // Invalid position
                    endcase
            end
          end
          end //this end is for table input mode
         else begin
                //fill this up later when figured how to use the scroll wheel, navigating the polynomial table
         end
         prev_btnC <= btnC;
         mouse_left_prev <= debounced;
      end //this end is for use mouse
       
    end //this end is for the always block
endmodule

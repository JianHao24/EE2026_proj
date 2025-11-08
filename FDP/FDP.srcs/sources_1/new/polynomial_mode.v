`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 
// Design Name: 
// Module Name: polynomial_mode
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: Polynomial evaluation mode - takes polynomial coefficients and x value,
//              evaluates f(x) or f'(x) using diff_core and deriv_coeff_gen
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

`include "diff_params.vh"

module polynomial_mode(
    // Clock inputs
    input clk_6p25MHz,
    input clk_1kHz,

    // Button inputs
    input btnC, btnU, btnD, btnL, btnR,

    // Control flags
    input reset,
    input is_polynomial_mode,

    // Mouse inputs (for future compatibility)
    input [11:0] xpos,
    input [11:0] ypos,
    input use_mouse,
    input mouse_left,
    input mouse_middle,

    // OLED outputs
    input [12:0] one_pixel_index,
    input [12:0] two_pixel_index,
    output [15:0] one_oled_data,
    output [15:0] two_oled_data,

    // Status outputs
    output overflow_flag,
    output div_by_zero_flag
);

    // Cursor controller signals
    wire [1:0] cursor_row_keypad;
    wire [2:0] cursor_col_keypad;
    wire [1:0] cursor_row_coeff;
    wire [1:0] cursor_col_coeff;
    wire [1:0] cursor_row_mode;
    wire [1:0] cursor_col_mode;
    
    wire keypad_btn_pressed;
    wire [3:0] keypad_selected_value;
    wire coeff_btn_pressed;
    wire [2:0] coeff_selected_index;  // 0..4 for a0..a4, 5 for x input
    wire mode_btn_pressed;
    wire mode_selected_value;  // 0: f(x), 1: f'(x)
    
    // Mode control
    reg [2:0] current_coeff_index = 3'd0;  // Which coefficient is being edited (0..4, 5 for x)
    reg waiting_coeff_selection;
    reg waiting_mode_selection;
    reg [2:0] polynomial_degree = 3'd4;  // Default degree 4
    // Input FSM state (sequence coefficients then x)
    reg [2:0] input_state = 3'd0;
    localparam IN_A = 3'd0;
    localparam IN_B = 3'd1;
    localparam IN_C = 3'd2;
    localparam IN_D = 3'd3;
    localparam IN_X = 3'd5; // use 5 to match existing code which treats 3'd5 as X
    
    // Input system signals
    wire has_decimal;
    wire has_negative;
    wire [3:0] input_index;
    wire signed [31:0] fp_value;
    wire [31:0] bcd_value;
    wire input_complete;
    wire [3:0] decimal_pos;
    
    // Coefficient storage (a0..a4) and x value
    reg signed [31:0] coeffs [0:4];
    reg signed [31:0] x_value = 32'd0;
    
    // Coefficient loading signals
    reg [31:0] coeff_bus;
    reg [2:0] coeff_idx;
    reg coeff_we;
    reg coeff_load_start;
    reg coeff_load_request = 0;  // Request signal from mode control
    
    // diff_core signals
    wire signed [31:0] eval_result;
    wire eval_valid;
    wire eval_busy;
    reg eval_start;
    reg eval_mode;  // 0: f(x), 1: f'(x)
    
    // Combined result signals
    wire signed [31:0] result;
    wire result_valid;
    reg show_result;
    reg computing;
    
    // Coefficient loading state machine
    reg [2:0] load_state = 3'd0;
    reg [2:0] load_index = 3'd0;
    localparam LOAD_IDLE = 3'd0;
    localparam LOAD_COEFF = 3'd1;
    localparam LOAD_WAIT = 3'd2;
    localparam LOAD_DONE = 3'd3;
    
    // Status
    assign overflow_flag = 1'b0;  // diff_core doesn't provide overflow flag
    assign div_by_zero_flag = 1'b0;
    
    assign result = eval_result;
    assign result_valid = eval_valid;
    
    // Initialize coefficients to zero - done in mode control logic below
    integer i;
    
    // Mode control logic -> input FSM
    always @(posedge clk_1kHz) begin
        if (reset || !is_polynomial_mode) begin
            // Reset all control flags and FSM
            waiting_coeff_selection <= 0;
            waiting_mode_selection <= 0;
            show_result <= 0;
            computing <= 0;
            input_state <= IN_A;
            current_coeff_index <= IN_A;
            polynomial_degree <= 3'd4;
            x_value <= 32'd0;
            coeff_load_request <= 0;
            // Initialize coefficients to zero
            for (i = 0; i < 5; i = i + 1) begin
                coeffs[i] <= 32'd0;
            end
        end else begin
            // Default: clear transient load/start strobes if load machine has started
            if (load_state != LOAD_IDLE) begin
                coeff_load_request <= 0;
            end

            // Handle keypad button presses (entering selection modes)
            if (keypad_btn_pressed) begin
                if (keypad_selected_value == 4'd12) begin
                    // Operations button - go to coefficient selection mode
                    waiting_coeff_selection <= 1;
                    waiting_mode_selection <= 0;
                    show_result <= 0;
                end else if (keypad_selected_value == 4'd13) begin
                    // Mode button - go to f(x)/f'(x) selection
                    waiting_mode_selection <= 1;
                    waiting_coeff_selection <= 0;
                    show_result <= 0;
                end else if (keypad_selected_value <= 4'd11) begin
                    // User started typing - clear result display and resume input FSM
                    show_result <= 0;
                    waiting_coeff_selection <= 0;
                    waiting_mode_selection <= 0;
                end
            end

            // Handle coefficient selection: user explicitly picked which coeff (or x)
            if (coeff_btn_pressed) begin
                // Map selected index directly into input_state/current_coeff_index
                input_state <= coeff_selected_index;
                current_coeff_index <= coeff_selected_index;
                waiting_coeff_selection <= 0;
                show_result <= 0;
            end

            // Handle mode selection (f(x) or f'(x))
            if (mode_btn_pressed) begin
                eval_mode <= mode_selected_value;
                waiting_mode_selection <= 0;
                // If x value is already set, trigger evaluation immediately
                if (x_value != 32'd0 && load_state == LOAD_IDLE) begin
                    coeff_load_request <= 1;
                    computing <= 1;
                    show_result <= 1;
                end
            end

            // Input FSM: react to completed numeric input when not in selection modes
            if (input_complete && !waiting_coeff_selection && !waiting_mode_selection) begin
                case (input_state)
                    IN_A: begin
                        // Store A
                        coeffs[0] <= fp_value;
                        if (fp_value != 32'd0 && input_state > polynomial_degree) polynomial_degree <= input_state;
                        // Advance to B
                        input_state <= IN_B;
                        current_coeff_index <= IN_B;
                    end
                    IN_B: begin
                        // Store B
                        coeffs[1] <= fp_value;
                        if (fp_value != 32'd0 && input_state > polynomial_degree) polynomial_degree <= input_state;
                        // Advance to C
                        input_state <= IN_C;
                        current_coeff_index <= IN_C;
                    end
                    IN_C: begin
                        // Store C
                        coeffs[2] <= fp_value;
                        if (fp_value != 32'd0 && input_state > polynomial_degree) polynomial_degree <= input_state;
                        // Advance to D
                        input_state <= IN_D;
                        current_coeff_index <= IN_D;
                    end
                    IN_D: begin
                        // Store D
                        coeffs[3] <= fp_value;
                        if (fp_value != 32'd0 && input_state > polynomial_degree) polynomial_degree <= input_state;
                        // After D, move to X input
                        input_state <= IN_X;
                        current_coeff_index <= IN_X; // 3'd5 used previously to indicate X
                    end
                    IN_X: begin
                        // Store x value and trigger evaluation
                        x_value <= fp_value;
                        if (load_state == LOAD_IDLE) begin
                            coeff_load_request <= 1;
                            computing <= 1;
                            show_result <= 1;
                        end
                    end
                    default: begin
                        // For any other value, return to A
                        input_state <= IN_A;
                        current_coeff_index <= IN_A;
                    end
                endcase
            end

            // When evaluation result is ready
            if (eval_valid && computing) begin
                show_result <= 1;
                computing <= 0;
                // Reset FSM to allow new polynomial input
                input_state <= IN_A;
                current_coeff_index <= IN_A;
            end
        end
    end
    
    always @(posedge clk_1kHz) begin
        if (reset || !is_polynomial_mode) begin
            load_state <= LOAD_IDLE;
            load_index <= 3'd0;
            coeff_we <= 0;
            eval_start <= 0;
        end else begin
            coeff_we <= 0;
            eval_start <= 0;
            
            case (load_state)
                LOAD_IDLE: begin
                    if (coeff_load_request) begin
                        load_state <= LOAD_COEFF;
                        load_index <= 3'd0;
                    end
                end
                LOAD_COEFF: begin
                    coeff_bus <= coeffs[load_index];
                    coeff_idx <= load_index;
                    coeff_we <= 1;
                    load_state <= LOAD_WAIT;
                end
                LOAD_WAIT: begin
                    coeff_we <= 0;
                    // Load coefficients from 0 to polynomial_degree (inclusive)
                    if (load_index < polynomial_degree) begin
                        load_index <= load_index + 1;
                        load_state <= LOAD_COEFF;
                    end else begin
                        // Loaded all coefficients (0 to degree), trigger evaluation
                        load_state <= LOAD_DONE;
                    end
                end
                LOAD_DONE: begin
                    // Trigger evaluation
                    eval_start <= 1;
                    load_state <= LOAD_IDLE;
                end
            endcase
        end
    end

    // ===== CURSOR CONTROLLER =====
    polynomial_cursor cursor_ctrl(
        .clk(clk_1kHz),
        .reset(reset || !is_polynomial_mode),
        .btnC(is_polynomial_mode ? btnC : 1'b0),
        .btnU(is_polynomial_mode ? btnU : 1'b0),
        .btnD(is_polynomial_mode ? btnD : 1'b0),
        .btnL(is_polynomial_mode ? btnL : 1'b0),
        .btnR(is_polynomial_mode ? btnR : 1'b0),
        .waiting_coeff_selection(waiting_coeff_selection),
        .waiting_mode_selection(waiting_mode_selection),
        .cursor_row_keypad(cursor_row_keypad),
        .cursor_col_keypad(cursor_col_keypad),
        .cursor_row_coeff(cursor_row_coeff),
        .cursor_col_coeff(cursor_col_coeff),
        .cursor_row_mode(cursor_row_mode),
        .cursor_col_mode(cursor_col_mode),
        .keypad_btn_pressed(keypad_btn_pressed),
        .keypad_selected_value(keypad_selected_value),
        .coeff_btn_pressed(coeff_btn_pressed),
        .coeff_selected_index(coeff_selected_index),
        .mode_btn_pressed(mode_btn_pressed),
        .mode_selected_value(mode_selected_value)
    );

    // ===== INPUT SYSTEM =====
    bcd_to_fp_input_system #(
        .DIGIT_CAPACITY(8),
        .FIXED_FRAC_BITS(16)
    ) input_builder(
        .clk(clk_1kHz),
        .reset(reset || !is_polynomial_mode),
        .keypad_btn_pressed(keypad_btn_pressed),
        .selected_keypad_value(keypad_selected_value),
    .is_active_mode(!waiting_coeff_selection && !waiting_mode_selection && is_polynomial_mode),
    .enable_negative(1'b1),  // Allow negative coefficients
    .enable_backspace(1'b0), // Disable backspace here so EXT_SPECIAL maps to negative
        .has_decimal(has_decimal),
        .has_negative(has_negative),
        .input_index(input_index),
        .fp_value(fp_value),
        .bcd_value(bcd_value),
        .input_complete(input_complete),
        .decimal_pos(decimal_pos)
    );

    // ===== DIFF CORE =====
    diff_core_1st #(
        .DATA_W(32),
        .COEFF_W(32),
        .FRAC(16)
    ) diff_core_inst(
        .clk(clk_1kHz),
        .rst_n(!(reset || !is_polynomial_mode)),
        .a_bus(coeff_bus),
        .a_idx(coeff_idx),
        .a_we(coeff_we),
        .cfg_start(eval_start),
        .mode(eval_mode),
        .deg_n(polynomial_degree),
        .x_cursor(x_value),
        .fp1(eval_result),
        .busy(eval_busy),
        .valid(eval_valid)
    );

    // ===== DISPLAY CONTROLLER (First OLED) =====
    polynomial_display_selector display_selector(
        .clk(clk_6p25MHz),
        .pixel_index(one_pixel_index),
        .cursor_row_keypad(cursor_row_keypad),
        .cursor_col_keypad(cursor_col_keypad),
        .cursor_row_coeff(cursor_row_coeff),
        .cursor_col_coeff(cursor_col_coeff),
        .cursor_row_mode(cursor_row_mode),
        .cursor_col_mode(cursor_col_mode),
        .has_decimal(has_decimal),
        .waiting_coeff_selection(waiting_coeff_selection),
        .waiting_mode_selection(waiting_mode_selection),
        .current_coeff_index(current_coeff_index),
        .oled_data(one_oled_data)
    );

    // ===== TEXT DISPLAY (Second OLED) =====
    polynomial_text_selector text_selector(
        .clk(clk_6p25MHz),
        .pixel_index(two_pixel_index),
        .computed_result(result),
        .waiting_coeff_selection(show_result || waiting_coeff_selection),
        .waiting_mode_selection(waiting_mode_selection),
        .bcd_value(bcd_value),
        .decimal_pos(decimal_pos),
        .input_index(input_index),
        .has_decimal(has_decimal),
        .has_negative(has_negative),
        .current_coeff_index(current_coeff_index),
        .show_result(show_result),
        .coeffs({coeffs[4], coeffs[3], coeffs[2], coeffs[1], coeffs[0]}),  // Packed for display
        .x_value(x_value),
        .polynomial_degree(polynomial_degree),
        .eval_mode(eval_mode),
        .oled_data(two_oled_data)
    );

endmodule


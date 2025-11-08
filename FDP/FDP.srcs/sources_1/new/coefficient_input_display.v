`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 08.04.2025 14:07:06
// Design Name: 
// Module Name: coefficient_input_display
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
Structure/style of this code largely follows that of integral_input_display
only with more Input labels.
*/
module coefficient_input_display(
    input clk,
    input [12:0] pixel_index,
    input [31:0] bcd_value,
    input [3:0] decimal_pos,
    input [3:0] input_index,
    input has_decimal,
    input has_negative,
    input [2:0] coeff_state,
    output reg [15:0] oled_data
);
    // === OLED dimensions ===
    parameter WIDTH  = 96;
    parameter HEIGHT = 64;

    // === Coordinates ===
    wire [6:0] x = pixel_index % WIDTH;
    wire [5:0] y = pixel_index / WIDTH;

    // === Colors ===
    parameter WHITE = 16'hFFFF;
    parameter BLACK = 16'h0000;
    parameter BLUE = 16'h001F;  // Changed from GREEN to BLUE

    // === Display positions ===
    parameter TEXT_START_X = 8;
    parameter TEXT_START_Y = 48;  // Moved to bottom (was 24)
    parameter LABEL_Y      = 8;   // Keep label at top

    // === Split BCD digits ===
    wire [3:0] digits[0:7];
    assign digits[0] = bcd_value[3:0];
    assign digits[1] = bcd_value[7:4];
    assign digits[2] = bcd_value[11:8];
    assign digits[3] = bcd_value[15:12];
    assign digits[4] = bcd_value[19:16];
    assign digits[5] = bcd_value[23:20];
    assign digits[6] = bcd_value[27:24];
    assign digits[7] = bcd_value[31:28];

    // === Display string and label buffers ===
    reg [47:0] display_string;
    reg [47:0] current_label;

    // Labels: Changed from "INPUT A/B/C/D" to "COEFF A/B/C/D"
    // Character codes: C=17, O=29, E=19, F=20, A=15, B=16, C=17, D=18
    parameter [47:0] LABEL_A = {6'd17,6'd29,6'd19,6'd20,6'd20,6'd32,6'd15,6'd32}; // "COEFF A"
    parameter [47:0] LABEL_B = {6'd17,6'd29,6'd19,6'd20,6'd20,6'd32,6'd16,6'd32}; // "COEFF B"
    parameter [47:0] LABEL_C = {6'd17,6'd29,6'd19,6'd20,6'd20,6'd32,6'd17,6'd32}; // "COEFF C"
    parameter [47:0] LABEL_D = {6'd17,6'd29,6'd19,6'd20,6'd20,6'd32,6'd18,6'd32}; // "COEFF D"
    parameter [47:0] LABEL_X = {6'd17,6'd29,6'd19,6'd20,6'd20,6'd32,6'd38,6'd32}; // "COEFF X"

    // === FSM state parameters ===
    parameter IDLE = 2'd0;
    parameter START_UPDATE = 2'd1;
    parameter PROCESS_DIGIT = 2'd2;
    parameter RENDER = 2'd3;

    reg [1:0] state = IDLE;

    // === Previous-state tracking ===
    reg [3:0] prev_input_index = 0;
    reg prev_has_decimal = 0;
    reg prev_has_negative = 0;
    reg [3:0] prev_decimal_pos = 0;
    reg [31:0] prev_bcd_value = 0;

    // === Processing vars ===
    reg [3:0] i = 0;
    reg [3:0] bcd_pos = 0;

    // === Cursor blink ===
    reg [6:0] cursor_x;
    reg [3:0] blink_counter = 0;
    reg cursor_visible = 1'b1;

    wire cursor_active = (x >= cursor_x && x < cursor_x + 8 &&
                          y >= TEXT_START_Y + 10 && y < TEXT_START_Y + 12);

    // === String renderers ===
    wire [15:0] string_data, label_data;
    wire string_active, label_active;

    string_renderer renderer (
        .clk(clk),
        .word(display_string),
        .start_x(TEXT_START_X),
        .start_y(TEXT_START_Y),
        .pixel_index(pixel_index),
        .colour(BLACK),
        .oled_data(string_data),
        .active_pixel(string_active)
    );

    string_renderer label_renderer (
        .clk(clk),
        .word(current_label),
        .start_x(TEXT_START_X),
        .start_y(LABEL_Y),
        .pixel_index(pixel_index),
        .colour(BLUE),  // Changed from GREEN to BLUE
        .oled_data(label_data),
        .active_pixel(label_active)
    );

    // === Label selection ===
    always @(*) begin
        case (coeff_state)
            3'd0: current_label = LABEL_A;
            3'd1: current_label = LABEL_B;
            3'd2: current_label = LABEL_C;
            3'd3: current_label = LABEL_D;
            default: current_label = LABEL_X;
        endcase
    end

    // === Main FSM ===
    always @(posedge clk) begin
        // Cursor blink
        cursor_x <= TEXT_START_X + input_index * 8;
        blink_counter <= blink_counter + 1;
        if (blink_counter == 4'd15) begin
            cursor_visible <= ~cursor_visible;
            blink_counter <= 0;
        end

        // Detect changes
        if (input_index    != prev_input_index ||
            has_decimal    != prev_has_decimal ||
            has_negative   != prev_has_negative ||
            decimal_pos    != prev_decimal_pos ||
            bcd_value      != prev_bcd_value) begin
            state <= START_UPDATE;
            prev_input_index <= input_index;
            prev_has_decimal <= has_decimal;
            prev_has_negative <= has_negative;
            prev_decimal_pos <= decimal_pos;
            prev_bcd_value <= bcd_value;
        end

        // FSM flow
        case (state)
            IDLE: ; // wait for input change

            START_UPDATE: begin
                i <= 0;
                bcd_pos <= 0;
                display_string <= 48'hFFFFFFFFFFFF; // spaces

                if (input_index == 0)
                    state <= RENDER;
                else begin
                    if (has_negative) begin
                        display_string[47:42] <= 6'd11; // '-'
                        i <= 1;
                    end
                    state <= PROCESS_DIGIT;
                end
            end

            PROCESS_DIGIT: begin
                if (i < input_index && i < 8) begin
                    if (has_decimal && i == decimal_pos)
                        display_string[47 - i*6 -: 6] <= 6'd14; // '.'
                    else begin
                        display_string[47 - i*6 -: 6] <= digits[bcd_pos];
                        bcd_pos <= bcd_pos + 1;
                    end
                    i <= i + 1;
                end
                else
                    state <= RENDER;
            end

            RENDER: state <= IDLE;
        endcase
    end

    // === Output priority ===
    always @(*) begin
        oled_data = WHITE;
        if (label_active)
            oled_data = label_data;
        if (string_active)
            oled_data = string_data;
        if (cursor_active && cursor_visible)
            oled_data = BLACK;
    end
endmodule


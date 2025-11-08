`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 20.03.2025 14:34:43
// Design Name: 
// Module Name: polynomial_table_keypad_display
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


module polytable_keypad_display(
    input clk,
    input [12:0] pixel_index,
    input [1:0] cursor_row,
    input [2:0] cursor_col,
    input has_decimal,
    input has_negative,
    input [3:0] input_index,
    output reg [15:0] oled_data,
    input is_dfx_mode    // Input indicating if DFX mode is latched (from controller)
    );

    // OLED dimensions
    parameter WIDTH = 96;
    parameter HEIGHT = 64;

    // Obtain x and y coordinates
    wire [6:0] x = pixel_index % WIDTH;
    wire [6:0] y = pixel_index / WIDTH;

    // Keypad layout constants
    parameter BUTTON_WIDTH = 24;
    parameter BUTTON_HEIGHT = 16;
    // this is the size of the button
    parameter KEYPAD_START_X = 0;
    parameter KEYPAD_START_Y = 0;
    parameter CHECKMARK_X = 72;

    // Colors
    parameter WHITE = 16'hFFFF;
    parameter BLACK = 16'h0000;
    parameter RED = 16'hF800;

    // Variables to track which button the pixel is currently at
    reg inside_button;
    reg inside_checkmark;
    reg [1:0] current_button_row;
    reg [1:0] current_button_col;
    reg [5:0] button_char;

    // Determine if negative sign is disabled (not at start or already used)
    wire is_negative_disabled = (input_index > 0 || has_negative);

    // Calculate button background color based on selection
    wire is_selected = (current_button_row == cursor_row && current_button_col == cursor_col);
    wire is_selected_checkmark = (inside_checkmark && cursor_col == 3'd3);
    wire is_decimal_disabled = (current_button_row == 3 && current_button_col == 1 && has_decimal);
    wire is_neg_disabled = (current_button_row == 3 && current_button_col == 2 && is_negative_disabled);

    // Character data outputs from sprite renderers
    wire [15:0] char_data;
    wire char_active;

    // Character to draw at current position
    reg [5:0] current_char;
    reg [6:0] char_x;
    reg [5:0] char_y;

    reg [6:0] rel_x;
    reg [6:0] rel_y;
    // temporary column indices for label rendering
    reg [2:0] colf;
    reg [2:0] colx;
    reg [2:0] cold;
    reg [2:0] colf2;
    reg [2:0] colx2;

    // Mode selection wires (computed from cursor position)
    wire in_top_button = (y < HEIGHT/2);
    // Hover-selected (cursor) definitions: top half = rows 0..1, bottom half = rows 2..3
    wire selected_fx = (cursor_col == 3'd3 && cursor_row < 2);
    wire selected_dfx = (cursor_col == 3'd3 && cursor_row >= 2);

    // Display active flags combine latched mode and hover selection
    wire top_active_display = (~is_dfx_mode) || selected_fx; // FX active if latched FX or hovered
    wire bottom_active_display = (is_dfx_mode) || selected_dfx; // DFX active if latched DFX or hovered

    // Sprite renderer for characters
    // We will use the sprite ROM directly for FX/DFX labels to avoid
    // timing issues with the clocked char_renderer. Instantiate ROM outputs
    // for the characters we need: 'F'(20), 'X'(38), 'D'(18).
    wire [7:0] pixels_top_F;
    wire [7:0] pixels_top_X;
    wire [7:0] pixels_bot_D;
    wire [7:0] pixels_bot_F;
    wire [7:0] pixels_bot_X;

    // row wires for each (driven when in range)
    wire [3:0] row_top = (y >= 8 && y < 24) ? (y - 8) : 4'd0;
    wire [3:0] row_bot = (y >= 40 && y < 56) ? (y - 40) : 4'd0;

    sprite_library_optimized rom_topF(.character(6'd20), .row(row_top), .pixels(pixels_top_F));
    sprite_library_optimized rom_topX(.character(6'd38), .row(row_top), .pixels(pixels_top_X));
    sprite_library_optimized rom_botD(.character(6'd18), .row(row_bot), .pixels(pixels_bot_D));
    sprite_library_optimized rom_botF(.character(6'd20), .row(row_bot), .pixels(pixels_bot_F));
    sprite_library_optimized rom_botX(.character(6'd38), .row(row_bot), .pixels(pixels_bot_X));

    // Clocked char renderer used for the main keypad symbols (0-9, ., -)
    char_renderer char_renderer_inst(
        .clk(clk),
        .pixel_index(pixel_index),
        .char(current_char),
        .start_x(char_x),
        .start_y(char_y),
        .colour(BLACK),
        .oled_data(char_data),
        .active_pixel(char_active)
    );

    // Loop to determine if pixel is within button and what button that is
    always @ (*) begin
        // Resetting values
        inside_button = 0;
        inside_checkmark = 0;
        current_button_row = 2'b11;
        current_button_col = 2'b11;
        button_char = 6'd0;
        current_char = 6'd0;
        char_x = 0;
        char_y = 0;

        // Check if pixel is in regular keypad area
        if (x < CHECKMARK_X) begin
            // Calculate the button position that pixel is currently in
            current_button_row = y / BUTTON_HEIGHT;
            current_button_col = x / BUTTON_WIDTH;

            // Validate coordinates (main keypad)
            if (current_button_row < 4 && current_button_col < 3) begin
                inside_button = 1;

                // Assign character to render based on position
                case({current_button_row, current_button_col})
                    {2'd0, 2'd0}: button_char = 6'd7;  // 7 (ASCII offset)
                    {2'd0, 2'd1}: button_char = 6'd8;  // 8
                    {2'd0, 2'd2}: button_char = 6'd9;  // 9
                    {2'd1, 2'd0}: button_char = 6'd4;  // 4
                    {2'd1, 2'd1}: button_char = 6'd5;  // 5
                    {2'd1, 2'd2}: button_char = 6'd6;  // 6
                    {2'd2, 2'd0}: button_char = 6'd1;  // 1
                    {2'd2, 2'd1}: button_char = 6'd2;  // 2
                    {2'd2, 2'd2}: button_char = 6'd3;  // 3
                    {2'd3, 2'd0}: button_char = 6'd0;  // 0
                    {2'd3, 2'd1}: button_char = 6'd14; // . (decimal point)
                    {2'd3, 2'd2}: button_char = 6'd11; // - (negative sign)
                endcase

                // Calculate position within button
                rel_x = x % BUTTON_WIDTH;
                rel_y = y % BUTTON_HEIGHT;

                // Draw button border
                if (rel_x == 0 || rel_x == BUTTON_WIDTH - 1 || rel_y == 0 || rel_y ==  BUTTON_HEIGHT - 1) begin
                    oled_data = BLACK;
                end
                // Draw button background
                else begin
                    if (is_selected) begin
                        if (is_decimal_disabled || is_neg_disabled)  begin
                            oled_data = RED; // Disabled button
                        end
                        else begin
                            oled_data = BLACK; // Selected button
                        end
                    end
                    else begin
                        oled_data = WHITE; // Normal button
                    end

                    // Currently using sprite_renderer as a means of checking if the pixel is directly on the symbol
                    current_char = button_char;
                    char_x = (current_button_col * BUTTON_WIDTH) + (BUTTON_WIDTH/2) - 4;
                    char_y = (current_button_row * BUTTON_HEIGHT) + (BUTTON_HEIGHT/2) - 6;

                    // char_active implies that the pixel is directly on the pixel
                    if (char_active) begin
                        oled_data = is_selected ? WHITE : BLACK;
                    end
                end
            end
        end
        // Check if pixel is in the mode selection area on the right
        else if (x >= CHECKMARK_X) begin
            inside_checkmark = 1;
            rel_x = x - CHECKMARK_X;
            
            // Split into two buttons vertically (wires declared at module scope)

            // Border for both buttons
            if (rel_x == 0 || rel_x == BUTTON_WIDTH - 1 || 
                y == 0 || y == HEIGHT - 1 || y == HEIGHT/2) begin
                oled_data = BLACK;
            end
            else begin
                // Background colors based on latched mode or hover
                if (in_top_button) begin
                    oled_data = top_active_display ? BLACK : WHITE;
                    // Draw "FX"
                    if (y >= 8 && y < 24) begin
                        // Draw 'F' at CHECKMARK_X+4
                        if (x >= CHECKMARK_X+4 && x < CHECKMARK_X+12) begin
                            // column within character
                            colf = x - (CHECKMARK_X+4);
                            if (pixels_top_F[7-colf]) oled_data = top_active_display ? WHITE : BLACK;
                        end

                        // Draw 'X' at CHECKMARK_X+12
                        if (x >= CHECKMARK_X+12 && x < CHECKMARK_X+20) begin
                            colx = x - (CHECKMARK_X+12);
                            if (pixels_top_X[7-colx]) oled_data = top_active_display ? WHITE : BLACK;
                        end
                    end
                end else begin
                    oled_data = bottom_active_display ? BLACK : WHITE;
                    // Draw "DFX"
                    if (y >= 40 && y < 56) begin
                        // Draw 'D' at CHECKMARK_X+2
                        if (x >= CHECKMARK_X+2 && x < CHECKMARK_X+10) begin
                            cold = x - (CHECKMARK_X+2);
                            if (pixels_bot_D[7-cold]) oled_data = bottom_active_display ? WHITE : BLACK;
                        end

                        // Draw 'F' at CHECKMARK_X+8
                        if (x >= CHECKMARK_X+8 && x < CHECKMARK_X+16) begin
                            colf2 = x - (CHECKMARK_X+8);
                            if (pixels_bot_F[7-colf2]) oled_data = bottom_active_display ? WHITE : BLACK;
                        end

                        // Draw 'X' at CHECKMARK_X+14
                        if (x >= CHECKMARK_X+14 && x < CHECKMARK_X+22) begin
                            colx2 = x - (CHECKMARK_X+14);
                            if (pixels_bot_X[7-colx2]) oled_data = bottom_active_display ? WHITE : BLACK;
                        end
                    end
                end
            end
        end
    end
endmodule

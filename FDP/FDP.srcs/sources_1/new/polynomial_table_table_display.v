`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 22.03.2025 08:30:30
// Design Name: 
// Module Name: polynomial_table_table_display
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


module polynomial_table_table_display(
    input clk,
    input [12:0] pixel_index,
    input is_table_mode,
    
    // From polynomial_table_cursor_controller
    input signed [31:0] starting_x,

    // From some other module (likely wayne's)
    input signed [31:0] coeff_a,
    input signed [31:0] coeff_b,
    input signed [31:0] coeff_c,
    input signed [31:0] coeff_d,

    output reg [15:0] oled_data
    );

    // OLED dimensions
    parameter WIDTH = 96;
    parameter HEIGHT = 64;
    parameter ROW_HEIGHT = 12;
    parameter COL_WIDTH = 48;
    parameter HEADER_HEIGHT = 12;
    parameter TABLE_ROWS = 5;
    parameter WHITE = 16'hFFFF;
    parameter BLACK = 16'h0000;

    // Extract pixel coordinates
    wire [6:0] x = pixel_index % WIDTH;
    wire [5:0] y = pixel_index / WIDTH;
    
    // Row detection
    wire [2:0] current_row = (y - HEADER_HEIGHT) / ROW_HEIGHT;
    wire in_header = (y < HEADER_HEIGHT);
    wire in_table_body = (y >= HEADER_HEIGHT && current_row < TABLE_ROWS);
    
    // Table data storage
    reg signed [31:0] x_values[0:TABLE_ROWS-1];
    reg signed [47:0] y_values[0:TABLE_ROWS-1];
    reg [47:0] x_string_cache[0:TABLE_ROWS-1];
    reg [47:0] y_string_cache[0:TABLE_ROWS-1];
    
    // Control signals
    reg is_full_computation = 0;
    reg is_full_conversion = 0;
    reg [31:0] prev_starting_x = 1;
    
    // Computation controller
    reg requires_computation = 0;
    reg [2:0] comp_row = 0;
    wire signed [47:0] computed_y;
    wire computation_complete;
    
    // Conversion controller
    reg require_conversion = 0;
    reg [2:0] conv_row = 0;
    reg is_y_conversion = 0;
    wire conversion_complete;
    wire [47:0] converted_string;
    reg [31:0] value_to_convert;
    
    // Computation module instance
    polynomial_computation compute(
        .clk(clk),
        .requires_computation(requires_computation),
        .x_value(x_values[comp_row]),
        .coeff_a(coeff_a),
        .coeff_b(coeff_b),
        .coeff_c(coeff_c),
        .coeff_d(coeff_d),
        .y_value(computed_y),
        .computation_complete(computation_complete),
        .is_graph(0)
    );
    
    fp_to_string converter_inst(
        .clk(clk),
        .start_conversion(require_conversion),
        .fp_value(value_to_convert),
        .conversion_done(conversion_complete),
        .result(converted_string)
    );
    
    // For display rendering
    reg [47:0] x_text;
    reg [47:0] y_text;
    wire [15:0] x_string_data;
    wire x_active;
    wire [15:0] y_string_data;
    wire y_active;
    
    // String renderers
    string_renderer_optimized x_renderer(
        .clk(clk),
        .word(x_text),
        .start_x(4),
        .start_y(in_header ? 1 : HEADER_HEIGHT + current_row * ROW_HEIGHT + 1),
        .pixel_index(pixel_index),
        .colour(BLACK),
        .oled_data(x_string_data),
        .active_pixel(x_active)
    );

    string_renderer_optimized y_renderer(
        .clk(clk),
        .word(y_text),
        .start_x(COL_WIDTH + 4),
        .start_y(in_header ? 1 : HEADER_HEIGHT + current_row * ROW_HEIGHT + 1),
        .pixel_index(pixel_index),
        .colour(BLACK),
        .oled_data(y_string_data),
        .active_pixel(y_active)
    );
    
    // Master state machine
    reg [2:0] master_state = 0;
    
    // Master controller - manages computation and conversion sequence
    always @(posedge clk) begin
        // Default - clear control signals
        requires_computation <= 0;
        require_conversion <= 0;
        
        // Detect changes in starting_x
        if (starting_x != prev_starting_x && is_table_mode) begin
            prev_starting_x <= starting_x;
            is_full_computation <= 0;
            is_full_conversion <= 0;
            master_state <= 1; // Start computation phase
            comp_row <= 0;
        end
        else if (!is_table_mode) begin
            prev_starting_x <= 1;
        end
        
        // Main state machine
        case (master_state)
            0: begin // Idle state - everything computed and converted
                // Do nothing, wait for starting_x change
            end
            
            1: begin // Computation Phase - Initialize x values
                if (!is_full_computation) begin
                    // Fill x_values array
                    x_values[comp_row] <= starting_x + (comp_row << 16);
                    
                    // Start computation for this row
                    requires_computation <= 1;
                    master_state <= 2;
                end
                else begin
                    // Move to conversion phase
                    master_state <= 3;
                    conv_row <= 0;
                    is_y_conversion <= 0;
                end
            end
            
            2: begin // Wait for computation to complete
                if (computation_complete) begin
                    // Store computed y value
                    if (computed_y > 48'sh00007FFF0000|| computed_y < -48'sh000080000000) begin
                        y_values[comp_row] <= (computed_y < 0) ? 32'h80000000 : 32'h7FFF0000;
                    end
                    else begin
                        y_values[comp_row] <= computed_y;
                    end
                    
                    // Move to next row or finish computation
                    if (comp_row < TABLE_ROWS-1) begin
                        comp_row <= comp_row + 1;
                        master_state <= 1; // Next row
                    end
                    else begin
                        is_full_computation <= 1;
                        master_state <= 3; // Move to conversion phase
                        conv_row <= 0;
                        is_y_conversion <= 0;
                    end
                end
                else begin
                    // Keep computation signal high while waiting
                    requires_computation <= 1;
                end
            end
            
            3: begin // Conversion Phase - setup
                if (!is_full_conversion) begin
                    // Determine what to convert (x or y value)
                    value_to_convert <= is_y_conversion ? y_values[conv_row] : x_values[conv_row];
                    
                    // Start conversion
                    require_conversion <= 1;
                    master_state <= 4;
                end
                else begin
                    // All converted, go to idle
                    master_state <= 0;
                end
            end
            
            4: begin // Wait for conversion to complete
                if (conversion_complete) begin
                    // Store converted string
                    if (is_y_conversion) begin
                        y_string_cache[conv_row] <= converted_string;
                        
                        // Move to next row or finish if all Y values are done
                        if (conv_row < TABLE_ROWS-1) begin
                            conv_row <= conv_row + 1;
                            is_y_conversion <= 0;
                            master_state <= 3; // Next row, still converting Y values
                        end
                        else begin
                            // All values converted
                            is_full_conversion <= 1;
                            master_state <= 0; // Go to idle
                        end
                    end
                    else begin
                        // Store X string and switch to Y conversion
                        x_string_cache[conv_row] <= converted_string;
                        is_y_conversion <= 1;
                        master_state <= 3; // Convert Y value for same row
                    end
                end
            end
        endcase
    end
    
    // Display logic
    always @ (posedge clk) begin
        if (is_table_mode) begin
            // Default white background
            oled_data = WHITE;

            // Table grid
            if (x == 0 || x == WIDTH - 1 || x == COL_WIDTH ||
                y == 0 || y == HEIGHT - 1 || y == HEADER_HEIGHT ||
                (y > HEADER_HEIGHT && (y - HEADER_HEIGHT) % ROW_HEIGHT == 0 && y < HEADER_HEIGHT + TABLE_ROWS * ROW_HEIGHT)
            ) begin
                oled_data = BLACK;
            end
            else begin
                // Table content
                if (in_header) begin
                    // Set Header text
                    if (x < COL_WIDTH) begin
                        // X header
                        x_text = {6'b100110, 6'b111111, 6'b111111, 6'b111111, 6'b111111, 6'b111111, 6'b111111, 6'b111111};
                        if (x_active) begin
                            oled_data = x_string_data;
                        end
                    end
                    else begin
                        // Y Header
                        y_text = {6'b100111, 6'b111111, 6'b111111, 6'b111111, 6'b111111, 6'b111111, 6'b111111, 6'b111111};
                        if (y_active) begin
                            oled_data = y_string_data;
                        end
                    end
                end
                else if (in_table_body && is_full_computation && is_full_conversion) begin
                    // Data rows - only display when computation and conversion are complete
                    if (x < COL_WIDTH) begin
                        // X value column
                        x_text = x_string_cache[current_row];
                        if (x_active) begin
                            oled_data = x_string_data;
                        end
                    end
                    else begin
                        // Y value column
                        y_text = y_string_cache[current_row];
                        if (y_active) begin
                            oled_data = y_string_data;
                        end
                    end
                end
            end
        end
        else begin
            oled_data = WHITE;
        end
    end
    
    // Initialize values
    integer i;
    initial begin
        for (i = 0; i < TABLE_ROWS; i = i + 1) begin
            x_values[i] = 0;
            y_values[i] = 0;
            x_string_cache[i] = 48'h303030303030; // Default to "000000"
            y_string_cache[i] = 48'h303030303030;
        end
        is_full_computation = 0;
        is_full_conversion = 0;
    end
endmodule

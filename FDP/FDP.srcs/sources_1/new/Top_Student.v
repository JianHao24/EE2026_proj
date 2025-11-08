module Top_Student (
    input basys_clock, 
    input [15:0] sw, 
    output [15:0] led,
    input btnC, btnU, btnD, btnL, btnR,
    output [7:0] JB, // First OLED
    output [7:0] JA, // Second OLED
    output [7:0] seg,
    output [3:0] an
);

    // ========= CLOCK DIVIDERS =========
    wire clk_6p25MHz;
    clock_divider clk_6p25MHz_gen(
        .main_clock(basys_clock),
        .ticks(7),
        .output_clock(clk_6p25MHz)
    ); 

    wire clk_1kHz;
    clock_divider clk_1kHz_gen(
        .main_clock(basys_clock),
        .ticks(49999),
        .output_clock(clk_1kHz)
    );

    // ========= OLED SIGNALS =========
    wire one_frame_begin, one_sample_pixel, one_sending_pixels;
    wire [12:0] JB_pixel_index;
    wire [15:0] JB_oled_data;

    wire two_frame_begin, two_sample_pixel, two_sending_pixels;
    wire [12:0] JA_pixel_index;
    wire [15:0] JA_oled_data;

    // ========= OLED DISPLAY MODULES =========
    Oled_Display first_display(
        .clk(clk_6p25MHz),
        .reset(0),
        .frame_begin(one_frame_begin),
        .sending_pixels(one_sending_pixels),
        .sample_pixel(one_sample_pixel),
        .pixel_index(JB_pixel_index),
        .pixel_data(JB_oled_data),
        .cs(JB[0]), 
        .sdin(JB[1]), 
        .sclk(JB[3]), 
        .d_cn(JB[4]), 
        .resn(JB[5]), 
        .vccen(JB[6]),
        .pmoden(JB[7])
    );

    Oled_Display second_display(
        .clk(clk_6p25MHz),
        .reset(0),
        .frame_begin(two_frame_begin),
        .sending_pixels(two_sending_pixels),
        .sample_pixel(two_sample_pixel),
        .pixel_index(JA_pixel_index),
        .pixel_data(JA_oled_data),
        .cs(JA[0]), 
        .sdin(JA[1]), 
        .sclk(JA[3]), 
        .d_cn(JA[4]), 
        .resn(JA[5]), 
        .vccen(JA[6]),
        .pmoden(JA[7])
    );

    reg [1:0] state;
    always @(*) begin
        if (sw[3]) state = 2'd3; // sin-cos graphing mode
        else if (sw[2]) state = 2'd2;      // Coefficient input mode
        else if (sw[1]) state = 2'd1; // Table mode
        else if (sw[0]) state = 2'd0; // Arithmetic mode
        else state = 2'd0;            // Default arithmetic
    end

    wire is_arithmetic_selected = (state == 2'd0);
    wire is_table_selected      = (state == 2'd1);
    wire is_coeff_input_selected = (state == 2'd2);
    wire is_sin_cos_graphing_selected = (state == 2'd3);

    
    // ========= ARITHMETIC MODULE =========
    wire [15:0] arithmetic_one_oled_data, arithmetic_two_oled_data;
    arithmetic_mode my_calculator(
        .clk_6p25MHz(clk_6p25MHz),
        .clk_1kHz(clk_1kHz),
        .btnC(is_arithmetic_selected ? btnC : 1'b0),
        .btnU(is_arithmetic_selected ? btnU : 1'b0),
        .btnD(is_arithmetic_selected ? btnD : 1'b0),
        .btnL(is_arithmetic_selected ? btnL : 1'b0),
        .btnR(is_arithmetic_selected ? btnR : 1'b0),
        .reset(~is_arithmetic_selected),
        .is_arithmetic_mode(is_arithmetic_selected),
        // OLED connections
        .one_pixel_index(JB_pixel_index),
        .two_pixel_index(JA_pixel_index),
        .one_oled_data(arithmetic_one_oled_data),
        .two_oled_data(arithmetic_two_oled_data),
        // LED indicators
        .overflow_flag(led[0])
    );

    wire signed [31:0] input_coeff_a, input_coeff_b, input_coeff_c, input_coeff_d;
    wire coeffs_ready;
    wire [15:0] coeff_input_one_oled_data, coeff_input_two_oled_data;

    coefficient_input_wrapper coeff_input(
        .clk_6p25MHz(clk_6p25MHz),
        .clk_1kHz(clk_1kHz),
        .btnC(is_coeff_input_selected ? btnC : 1'b0),
        .btnU(is_coeff_input_selected ? btnU : 1'b0),
        .btnD(is_coeff_input_selected ? btnD : 1'b0),
        .btnL(is_coeff_input_selected ? btnL : 1'b0),
        .btnR(is_coeff_input_selected ? btnR : 1'b0),
        .reset(~is_coeff_input_selected),
        .one_pixel_index(JB_pixel_index),
        .two_pixel_index(JA_pixel_index),
        .one_oled_data(coeff_input_one_oled_data),
        .two_oled_data(coeff_input_two_oled_data),
        .coeff_a(input_coeff_a),
        .coeff_b(input_coeff_b),
        .coeff_c(input_coeff_c),
        .coeff_d(input_coeff_d),
        .coefficients_ready(coeffs_ready)
    );

    wire [15:0] table_one_oled_data, table_two_oled_data;
    wire is_table_input_mode_outgoing;

    polytable_mode table_module(
        .clk_6p25MHz(clk_6p25MHz),
        .clk_1kHz(clk_1kHz),
        .clk_100MHz(basys_clock),
        .btnC(is_table_selected ? btnC : 1'b0),
        .btnU(is_table_selected ? btnU : 1'b0),
        .btnD(is_table_selected ? btnD : 1'b0),
        .btnL(is_table_selected ? btnL : 1'b0),
        .btnR(is_table_selected ? btnR : 1'b0),
        // Mouse input disabled
        // Table control - use coefficients from input wrapper
        .is_table_mode(is_table_selected && coeffs_ready),
        .coeff_a(input_coeff_a),
        .coeff_b(input_coeff_b),
        .coeff_c(input_coeff_c),
        .coeff_d(input_coeff_d),
        // OLED connections
        .one_pixel_index(JB_pixel_index),
        .two_pixel_index(JA_pixel_index),
        .one_oled_data(table_one_oled_data),
        .two_oled_data(table_two_oled_data),
        // Output flag
        .is_table_input_mode_outgoing(is_table_input_mode_outgoing)
    );

    assign JB_oled_data = 
        (is_coeff_input_selected) ? coeff_input_one_oled_data :
        (is_arithmetic_selected)  ? arithmetic_one_oled_data :
        (is_table_selected)       ? table_one_oled_data :
                                    16'h0000;  // blank

    assign JA_oled_data = 
        (is_coeff_input_selected) ? coeff_input_two_oled_data :
        (is_arithmetic_selected)  ? arithmetic_two_oled_data :
        (is_table_selected)       ? table_two_oled_data :
                                    16'h0000;

    assign led[15:14] = state;
    assign led[13] = coeffs_ready;  // Shows when coefficients are ready
    assign led[2] = is_table_input_mode_outgoing;  // Shows when in table input mode


    assign seg = 8'hFF;  // All segments off for now
    assign an = 4'hF;    // All anodes off for now

endmodule


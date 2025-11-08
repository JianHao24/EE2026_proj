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
    flexible_clock_divider clk_6p25MHz_gen(
        .main_clock(basys_clock),
        .ticks(7),
        .output_clock(clk_6p25MHz)
    ); 

    wire clk_1kHz;
    flexible_clock_divider clk_1kHz_gen(
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

    // ========= FSM MODE SELECTION (2 MODES) =========
    reg [1:0] state;
    always @(*) begin
        if (sw[1]) state = 2'd1;   // Table mode
        else if (sw[0]) state = 2'd0; // Arithmetic mode
        else state = 2'd0; // Default arithmetic
    end

    wire is_arithmetic_selected = (state == 2'd0);
    wire is_table_selected      = (state == 2'd1);

    // ========= ARITHMETIC MODULE =========
    wire [15:0] arithmetic_one_oled_data, arithmetic_two_oled_data;
    arithmetic_module my_calculator(
        .clk_6p25MHz(clk_6p25MHz),
        .clk_1kHz(clk_1kHz),
        .btnC(btnC),
        .btnU(btnU),
        .btnD(btnD),
        .btnL(btnL),
        .btnR(btnR),
        .reset(~is_arithmetic_selected),
        .is_arithmetic_mode(is_arithmetic_selected),
        // Mouse input disabled
        .xpos(12'd0),
        .ypos(12'd0),
        .use_mouse(1'b0),
        .mouse_left(1'b0),
        .mouse_middle(1'b0),
        // OLED connections
        .one_pixel_index(JB_pixel_index),
        .two_pixel_index(JA_pixel_index),
        .one_oled_data(arithmetic_one_oled_data),
        .two_oled_data(arithmetic_two_oled_data),
        // LED indicators
        .overflow_flag(led[0]),
        .div_by_zero_flag(led[1])
    );

    // ========= TABLE MODULE =========
    wire [15:0] table_one_oled_data, table_two_oled_data;
    wire is_table_input_mode_outgoing;
    wire signed [31:0] coeff_a, coeff_b, coeff_c, coeff_d;

    polynomial_table_module table_module(
        .clk_6p25MHz(clk_6p25MHz),
        .clk_1kHz(clk_1kHz),
        .clk_100MHz(basys_clock),
        .btnC(btnC),
        .btnU(btnU),
        .btnD(btnD),
        .btnL(btnL),
        .btnR(btnR),
        // Mouse input disabled
        .xpos(12'd0),
        .ypos(12'd0),
        .use_mouse(1'b0),
        .mouse_left(1'b0),
        .mouse_middle(1'b0),
        // Table control
        .is_table_mode(is_table_selected),
        .coeff_a(coeff_a),
        .coeff_b(coeff_b),
        .coeff_c(coeff_c),
        .coeff_d(coeff_d),
        // OLED connections
        .one_pixel_index(JB_pixel_index),
        .two_pixel_index(JA_pixel_index),
        .one_oled_data(table_one_oled_data),
        .two_oled_data(table_two_oled_data),
        // Output flag
        .is_table_input_mode_outgoing(is_table_input_mode_outgoing)
    );

    // ========= OLED OUTPUT MUX =========
    assign JB_oled_data = 
        (is_arithmetic_selected) ? arithmetic_one_oled_data :
        (is_table_selected)      ? table_one_oled_data :
                                   16'h0000;  // blank

    assign JA_oled_data = 
        (is_arithmetic_selected) ? arithmetic_two_oled_data :
        (is_table_selected)      ? table_two_oled_data :
                                   16'h0000;

    // ========= LED DEBUG OUTPUT =========
    assign led[15:14] = state;

endmodule


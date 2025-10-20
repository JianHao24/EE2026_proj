`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
//
//  FILL IN THE FOLLOWING INFORMATION:
//  STUDENT A NAME: 
//  STUDENT B NAME:
//  STUDENT C NAME: 
//  STUDENT D NAME:  
//
//////////////////////////////////////////////////////////////////////////////////


module Top_Student (input basys_clock, L, R, output [7:0] JC);

    reg [15:0] oled_colour = 16'b0000010110000000;
    wire clk_6p25MHZ;
    wire clk_25MHZ;
    wire clk_10HZ;
    wire fb;
    wire send_pix;
    wire sample_pix;
    wire [12:0] pixel_index;
    wire [6:0] x;
    wire[5:0] y;
    wire L_signal;
    wire R_signal;
    wire [15:0] oled_L, oled_R;
    
    debouncer LD (.pb(L),.clk(basys_clock),.sig(L_signal));
    debouncer RD (.pb(R),.clk(basys_clock),.sig(R_signal));
    clock_divisor unit_6p25MHZ(.CLOCK(basys_clock),.DIVISOR(7),.SLOW_CLOCK(clk_6p25MHZ));
    clock_divisor unit_25MHZ(.CLOCK(basys_clock),.DIVISOR(4),.SLOW_CLOCK(clk_25MHZ));
    clock_divisor unit_10HZ(.CLOCK(basys_clock),.DIVISOR(4999999),.SLOW_CLOCK(clk_10HZ));
    Oled_Display unit_display(
    .clk(clk_6p25MHZ), 
    .reset(0), 
    .frame_begin(fb), 
    .sending_pixels(send_pix),
    .sample_pixel(sample_pix),
    .pixel_index(pixel_index), 
    .pixel_data(oled_colour), 
    .cs(JC[0]), 
    .sdin(JC[1]), 
    .sclk(JC[3]), 
    .d_cn(JC[4]), 
    .resn(JC[5]), 
    .vccen(JC[6]),
    .pmoden(JC[7]));
    FSM FSM_L(.btn(L_signal),.clk(clk_25MHZ),.flag(1),.oled_colour(oled_L));
    FSM FSM_R(.btn(R_signal),.clk(clk_25MHZ),.flag(0),.oled_colour(oled_R));
    
    assign x = pixel_index % 96;
    assign y = pixel_index / 96;
    
    
       always @ (posedge clk_25MHZ)
       begin
            if ( (x >= 3 && x <= 15) && (y >= 3 && y <= 15) && (((x-9)*(x-9) + (y-9)*(y-9)) <= 36 )) begin
                oled_colour = (L | R)? 16'b11111_010001_11101 : 16'b11111_111111_11111; 
            end else if(((x >= 20) && (x <= 48) && (y >= 7) && (y <= 14))||((x >= 20) && (x <= 27) && (y >= 15) && (y <= 49))||((x >= 41) && (x <= 48) && (y >= 15) && (y <= 49))||((x >= 20) && (x <= 48) && (y >= 50) && (y <= 57)))
            begin 
                oled_colour <= oled_L;
            end else if (((x >= 52) && (x <= 59) && (y >= 7) && (y <= 27))||((x >= 52) && (x <= 73) && (y >= 28) && (y <= 36))||((x >= 73) && (x <= 80) && (y >= 7) && (y <= 57)))
            begin 
                oled_colour <= oled_R;
            end else begin
                oled_colour <= 16'b00000_000000_00000;
            end
        
        end
            


endmodule
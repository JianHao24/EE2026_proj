`timescale 1ns / 1ps

module trig_calculator #(
    parameter FIXED_FRAC_BITS = 16
)(
    input wire clk,
    input wire rst,
    
    // Trig function selection
    input wire trig_valid,
    input wire [1:0] trig_sel,  // 0=sin, 1=cos, 2=tan, 3=log2
    input wire signed [31:0] input_val,  // Q16.16 input
    
    // Output
    output reg signed [31:0] result,
    output reg result_valid,
    output reg overflow
);

    // Trig function codes
    localparam [1:0] TRIG_SIN = 2'b00;
    localparam [1:0] TRIG_COS = 2'b01;
    localparam [1:0] TRIG_TAN = 2'b10;
    localparam [1:0] TRIG_LOG = 2'b11;
    
    // State machine
    localparam [1:0] ST_IDLE = 2'b00;
    localparam [1:0] ST_COMPUTE = 2'b01;
    localparam [1:0] ST_WAIT = 2'b10;
    localparam [1:0] ST_DONE = 2'b11;
    
    reg [1:0] state;
    reg [3:0] wait_counter;
    
    // CORDIC signals
    reg signed [15:0] cordic_angle;
    wire signed [15:0] cordic_sin, cordic_cos;
    
    // Instantiate CORDIC
    cordic_sin_cos #(
        .WIDTH(16),
        .ITER(15)
    ) cordic_inst (
        .angle(cordic_angle),
        .sin_out(cordic_sin),
        .cos_out(cordic_cos)
    );
    
    // Intermediate values for tan
    reg signed [63:0] tan_temp;
    
    // Log2 intermediate values
    reg signed [31:0] input_magnitude;
    reg signed [31:0] temp_val;
    reg [5:0] bit_pos;
    reg signed [31:0] fractional_part;
    reg signed [31:0] mantissa;
    reg signed [6:0] signed_bit_pos;
    integer i;
    
    always @(posedge clk) begin
        if (rst) begin
            state <= ST_IDLE;
            result <= 32'sd0;
            result_valid <= 1'b0;
            overflow <= 1'b0;
            wait_counter <= 4'd0;
            cordic_angle <= 16'sd0;
        end else begin
            result_valid <= 1'b0;
            overflow <= 1'b0;
            
            case (state)
                ST_IDLE: begin
                    if (trig_valid) begin
                        state <= ST_COMPUTE;
                        wait_counter <= 4'd0;
                    end
                end
                
                ST_COMPUTE: begin
                    case (trig_sel)
                        TRIG_SIN: begin
                            // Convert Q16.16 to Q6.10 for CORDIC
                            cordic_angle <= input_val[31:6];
                            state <= ST_WAIT;
                        end
                        
                        TRIG_COS: begin
                            cordic_angle <= input_val[31:6];
                            state <= ST_WAIT;
                        end
                        
                        TRIG_TAN: begin
                            cordic_angle <= input_val[31:6];
                            state <= ST_WAIT;
                        end
                        
                        2'd3: begin // log2
                            if (input_val <= 0) begin
                                result <= 32'sh80000000; // Return minimum value for log(0) or log(negative)
                                overflow <= 1;
                                result_valid <= 1;
                                state <= ST_IDLE;
                            end
                            else begin
                                input_magnitude = (input_val[31]) ? -input_val : input_val;
                                
                                // Find the position of the most significant bit (integer part of log2)
                                bit_pos = 0;
                                temp_val = input_magnitude; // Use full Q16.16 value, not shifted
                                
                                // Find MSB position
                                for (i = 31; i >= 0; i = i - 1) begin
                                    if (temp_val[i] && bit_pos == 0) begin
                                        bit_pos = i;
                                    end
                                end
                                
                                // Adjust bit position for Q16.16 format (bit 16 represents 2^0)
                                signed_bit_pos = bit_pos - 16;
                                
                                // Calculate fractional part using linear interpolation
                                if (bit_pos > 0) begin
                                    // Get mantissa (normalized to [1, 2) range)
                                    mantissa = (input_magnitude << (31 - bit_pos)) >> 15; // Now in Q16.16
                                    
                                    // Linear interpolation: frac ? (mantissa - 1.0)
                                    fractional_part = mantissa - 32'h00010000; // Subtract 1.0 in Q16.16
                                end
                                else begin
                                    fractional_part = 0;
                                end
                                
                                // Combine integer and fractional parts
                                result <= (signed_bit_pos << 16) + fractional_part;
                                overflow <= 0;
                                result_valid <= 1;
                                state <= ST_IDLE;
                            end
                        end
                    endcase
                end
                
                ST_WAIT: begin
                    wait_counter <= wait_counter + 1;
                    
                    if (wait_counter >= 4'd5) begin
                        state <= ST_DONE;
                    end
                end
                
                ST_DONE: begin
                    case (trig_sel)
                        TRIG_SIN: begin
                            result <= {{16{cordic_sin[15]}}, cordic_sin};
                        end
                        
                        TRIG_COS: begin
                            result <= {{16{cordic_cos[15]}}, cordic_cos};
                        end
                        
                        TRIG_TAN: begin
                            if (cordic_cos == 16'sd0) begin
                                result <= 32'sh7FFF0000;
                                overflow <= 1'b1;
                            end else begin
                                tan_temp = ($signed(cordic_sin) << 31) / $signed(cordic_cos);
                                
                                if (tan_temp > 64'sh00007FFF0000 || tan_temp < -64'sh00008000000) begin
                                    result <= (tan_temp[63]) ? 32'sh80000000 : 32'sh7FFF0000;
                                    overflow <= 1'b1;
                                end else begin
                                    result <= tan_temp[31:0];
                                    overflow <= 1'b0;
                                end
                            end
                        end
                    endcase
                    
                    result_valid <= 1'b1;
                    state <= ST_IDLE;
                end
            endcase
        end
    end
endmodule
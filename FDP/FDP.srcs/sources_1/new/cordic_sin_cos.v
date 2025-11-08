
module cordic_sin_cos #(
    parameter WIDTH = 16,
    parameter ITER = 15
)(
    input  wire signed [WIDTH-1:0] angle,   // Q6.10 format
    output reg  signed [WIDTH-1:0] sin_out, // Q1.15 format
    output reg  signed [WIDTH-1:0] cos_out  // Q1.15 format
);

    // Atan lookup table in Q2.14
    reg signed [WIDTH-1:0] atan_lut [0:ITER-1];
    initial begin
        atan_lut[00] = 16'd6434;
        atan_lut[01] = 16'd3798;
        atan_lut[02] = 16'd2007;
        atan_lut[03] = 16'd1019;
        atan_lut[04] = 16'd511;
        atan_lut[05] = 16'd256;
        atan_lut[06] = 16'd128;
        atan_lut[07] = 16'd64;
        atan_lut[08] = 16'd32;
        atan_lut[09] = 16'd16;
        atan_lut[10] = 16'd8;
        atan_lut[11] = 16'd4;
        atan_lut[12] = 16'd2;
        atan_lut[13] = 16'd1;
        atan_lut[14] = 16'd1;
    end
    
    localparam signed [WIDTH-1:0] CORDIC_GAIN = 16'd19898;  // Q1.15
    localparam signed [WIDTH-1:0] PI_OVER_2 = 16'd12868;     // Q2.14
    localparam signed [WIDTH-1:0] PI = 16'd25736;            // Q2.14
    localparam signed [WIDTH-1:0] TWO_PI = 16'd51472;        // 2? in Q2.14
    localparam signed [WIDTH-1:0] TOLERANCE = 16'd512; // Tolerance. This allows precision of output up to 4dp only!
    
    localparam signed [WIDTH-1:0] PI_Q610 = 16'd3217;      // ? * 1024 ? 3217
    localparam signed [WIDTH-1:0] TWO_PI_Q610 = 16'd6434;  // 2? * 1024 ? 6434

    
    reg signed [WIDTH:0] x, y, z;
    reg signed [WIDTH:0] x_new, y_new;
    reg signed [WIDTH-1:0] angle_work;
    reg negate_cos = 0, negate_sin = 0;
    
    integer i, j;
    
    always @(*) begin
        // Step 1: Wrap to [-?, ?]
        angle_work = angle;
        for (j = 0; j < 8; j = j + 1) begin
            if (angle_work > PI_Q610)
                angle_work = angle_work - TWO_PI_Q610;
            else if (angle_work < -PI_Q610)
                angle_work = angle_work + TWO_PI_Q610;
        end
        
        angle_work = angle_work << 3; //convert to 3.13 format for processing
        
        // Step 2: Handle special endpoint cases        
        // Then modify the endpoint checks:
        if (angle_work >= -TOLERANCE && angle_work <= TOLERANCE) begin
            // Near 0
            sin_out = 16'sd0;
            cos_out = 16'sd32767;
            
        end else if (angle_work >= (PI_OVER_2 - TOLERANCE) && angle_work <= (PI_OVER_2 + TOLERANCE)) begin
            // Near ?/2
            sin_out = 16'sd32767;  // FIX: Changed from -32767 to +32767
            cos_out = 16'sd0;
            
        end else if (angle_work >= (-PI_OVER_2 - TOLERANCE) && angle_work <= (-PI_OVER_2 + TOLERANCE)) begin
            // Near -?/2
            sin_out = -16'sd32767;
            cos_out = 16'sd0;
            
        end else if (angle_work >= (PI - TOLERANCE) || angle_work <= (-PI + TOLERANCE)) begin
            // Near ??
            sin_out = 16'sd0;
            cos_out = -16'sd32767;
            
        end else begin
            // Step 3: Quadrant mapping for non-endpoint angles
            if (angle_work >= -PI_OVER_2 && angle_work <= PI_OVER_2) begin
                // Already in range, no change needed
                negate_cos = 1'b0;
                negate_sin = 1'b0;
                
            end else if (angle_work > PI_OVER_2) begin
                angle_work = PI - angle_work;
                negate_cos = 1'b1;
                negate_sin = 1'b0;
                
            end else begin
                angle_work = -PI - angle_work;
                negate_cos = 1'b1;
                negate_sin = 1'b0;
            end
            
            // Step 4: CORDIC iterations
            x = {CORDIC_GAIN[WIDTH-1], CORDIC_GAIN};
            y = 17'sd0;
            z = {angle_work[WIDTH-1], angle_work};
            
            for (i = 0; i < ITER; i = i + 1) begin
                if (z[WIDTH] == 1'b0) begin
                    x_new = x - (y >>> i);
                    y_new = y + (x >>> i);
                    z = z - {atan_lut[i][WIDTH-1], atan_lut[i]};
                end else begin
                    x_new = x + (y >>> i);
                    y_new = y - (x >>> i);
                    z = z + {atan_lut[i][WIDTH-1], atan_lut[i]};
                end
                x = x_new;
                y = y_new;
            end
            
            // Apply sign corrections
            cos_out = negate_cos ? -x[WIDTH-1:0] : x[WIDTH-1:0];
            sin_out = negate_sin ? -y[WIDTH-1:0] : y[WIDTH-1:0];
        end
    end
    
endmodule
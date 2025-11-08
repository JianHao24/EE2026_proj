module sine_graph_plotter (
    input wire clk,
    input wire rst,
    input wire start_plot,
    input sample_pixel,
    input [12:0] pixel_index,
    input enable,
        
    output reg [15:0] pixel_data
);


    // Screen parameters
    parameter SCREEN_WIDTH = 96;
    parameter SCREEN_HEIGHT = 64;
    parameter COLOR_BG = 16'hFFFF;      // White background
    parameter COLOR_CURVE = 16'h001F;   // Blue for sine curve
    parameter COLOR_AXIS = 16'h0000;    // Black for axes
    
    wire [6:0] x_pos = pixel_index % 96;
    wire [5:0] y_pos = pixel_index / 96;
    
    // Amplitude parameter
    localparam [5:0] AMPLITUDE = 6'd28;
    // Constants in Q6.10 format
    localparam signed [15:0] NEG_PI_Q610 = -16'sd3217;
    localparam signed [31:0] TWO_PI_Q610 = 32'sd6434;    // 2? in Q6.10
    
    localparam IDLE         = 0;
    localparam COMPUTE_VALUES   = 1;
    localparam WAIT_CORDIC  = 2;
    localparam CACHE_UPDATED = 3;

    reg [2:0] computation_state;
    reg [7:0] current_x_index; //current_x_index
    reg [4:0] wait_counter;
    
        // Cache for sine Y values (one for each X position)
    reg [5:0] y_cache [0:SCREEN_WIDTH-1];
    reg cache_valid = 0;
    
    // Phase calculation for current X position
    // phase = -? + (x_pos * k * 2?) / 127
    // We'll compute this in Q6.10 format
    wire signed [31:0] phase_scaled = (current_x_index * TWO_PI_Q610);
    wire signed [31:0] phase_offset = phase_scaled / 127;
    wire signed [31:0] phase_calc = NEG_PI_Q610 + phase_offset[15:0];    
    reg signed [15:0] angle_in;
    
    wire signed [15:0] sin_out, cos_out;
    
    cordic_sin_cos #(
        .WIDTH(16),
        .ITER(12)  // Reduced from 15 to save LUTs
    ) cordic_inst (
        .angle(angle_in),
        .sin_out(sin_out),
        .cos_out(cos_out)
    );

    // Scale sine output to pixel offset
    wire signed [31:0] sin_scaled = $signed(sin_out) * $signed({10'd0, AMPLITUDE});
    wire signed [15:0] y_offset = sin_scaled >>> 15;
    
    // Center at Y=32 and clamp
    wire signed [7:0] y_temp = 8'sd32 - y_offset[7:0];
    wire [5:0] y_final = (y_temp[7]) ? 6'd0 :
                         (y_temp > 63) ? 6'd63 :
                         y_temp[5:0];

// Pre-compute all Y values and store in cache
    always @(posedge clk) begin
        if (rst) begin
            computation_state <= IDLE;
            current_x_index <= 0;
            wait_counter <= 0;
            cache_valid <= 0;
            angle_in <= 0;
        end else if (!cache_valid && enable) begin
            case (computation_state)
                IDLE: begin
                    current_x_index <= 0;
                    wait_counter <= 0;
                    computation_state <= COMPUTE_VALUES;
                end
                
                COMPUTE_VALUES: begin
                    // Send angle to CORDIC
                    angle_in <= phase_calc[15:0];
                    wait_counter <= 0;
                    computation_state <= WAIT_CORDIC;
                end
                
                WAIT_CORDIC: begin
                    wait_counter <= wait_counter + 1;
                    
                    // Wait for CORDIC to settle
                    if (wait_counter >= 3) begin
                        // Store computed Y value in cache
                        y_cache[current_x_index] <= y_final;
                        
                        // Check if done with all X positions
                        if (current_x_index == SCREEN_WIDTH - 1) begin
                            cache_valid <= 1;
                            computation_state <= CACHE_UPDATED;
                        end else begin
                            current_x_index <= current_x_index + 1;
                            computation_state <= COMPUTE_VALUES;
                        end
                    end
                end
                
                CACHE_UPDATED: begin
                    // Cache is ready
                    computation_state <= CACHE_UPDATED;
                end
                
                default: computation_state <= IDLE;
            endcase
        end else if (!enable) begin
            cache_valid <= 0;
            computation_state <= IDLE;
        end
    end
    
    // Rendering logic - draw from cache
    reg [5:0] curr_y_val;
    reg [5:0] prev_y_val;
    
    always @(posedge clk) begin
        if (enable && cache_valid) begin
            // Default: white background
            pixel_data <= 16'hFFFF;
            
            // Draw center axes
            if (x_pos == (SCREEN_WIDTH >> 1) || y_pos == (SCREEN_HEIGHT >> 1)) begin
                pixel_data <= 16'h0000;  // Black axes
            end
            
            // Draw sine curve
            if (x_pos < SCREEN_WIDTH) begin
                curr_y_val = y_cache[x_pos];
                
                // Check if current pixel is on or near the curve (±1 pixel)
                if (y_pos >= curr_y_val - 1 && y_pos <= curr_y_val + 1) begin
                    pixel_data <= 16'h001F;  // Blue curve
                end
                
                // Draw line between consecutive points
                if (x_pos > 0) begin
                    prev_y_val = y_cache[x_pos - 1];
                    
                    // Check if line crosses this pixel
                    if ((curr_y_val >= y_pos && prev_y_val <= y_pos) ||
                        (curr_y_val <= y_pos && prev_y_val >= y_pos)) begin
                        pixel_data <= 16'h001F;  // Blue curve
                    end
                end
            end
        end else if (!enable) begin
            pixel_data <= 16'h0000;  // Black when disabled
        end
    end
    
    // Initialize cache
    integer i;
    initial begin
        for (i = 0; i < SCREEN_WIDTH; i = i + 1) begin
            y_cache[i] = 32;
        end
        cache_valid = 0;
    end


endmodule
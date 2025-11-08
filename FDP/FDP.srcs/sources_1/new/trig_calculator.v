module trig_calculator #(
    parameter FIXED_FRAC_BITS = 16
)(
    input wire clk,
    input wire rst,
    input wire trig_valid,              // Start calculation
    input wire [1:0] trig_sel,          // 00=sin, 01=cos, 10=tan, 11=log2
    input wire signed [31:0] input_val, // 16.16 format angle/value input
    output reg signed [31:0] result,    // 16.16 format result
    output reg result_valid,            // Result ready
    output reg overflow                 // Overflow flag
);
    // States
    localparam IDLE = 3'd0;
    localparam COMPUTE = 3'd1;
    localparam WAIT_CORDIC = 3'd2;
    localparam COMPUTE_LOG2 = 3'd3;
    localparam DONE = 3'd4;
    
    reg [2:0] state, next_state;  // Increased to 3 bits for more states
    reg [1:0] trig_mode;
    reg [4:0] wait_counter;  // Increased for log2 iterations
    
    // Convert 16.16 to Q6.10 for CORDIC input
    wire signed [15:0] angle_q610 = input_val[21:6];
    
    // CORDIC instance (for sin/cos/tan)
    wire signed [15:0] sin_out, cos_out;
    
    cordic_sin_cos #(
        .WIDTH(16),
        .ITER(12)
    ) cordic_inst (
        .angle(angle_q610),
        .sin_out(sin_out),
        .cos_out(cos_out)
    );
    
    // Convert Q1.15 to 16.16
    wire signed [31:0] sin_16_16 = {{16{sin_out[15]}}, sin_out} << 1;
    wire signed [31:0] cos_16_16 = {{16{cos_out[15]}}, cos_out} << 1;
    
    // Tangent calculation
    reg signed [31:0] tan_16_16;
    wire is_cos_zero = (cos_out >= -100 && cos_out <= 100);
    
    // ===== LOG2 CALCULATION LOGIC =====
    // Log2 using bit-scanning and linear interpolation
    reg signed [31:0] log2_result;
    reg signed [31:0] log2_input;
    reg [4:0] log2_iter;
    reg [4:0] msb_pos;  // Most significant bit position
    reg [31:0] normalized;  // Normalized value
    reg [31:0] frac_part;   // Fractional part for interpolation
    
    // Constants for log2 calculation
    // log2(1 + x) ? x - x²/2 + x³/3 for small x
    // We'll use a simpler approximation: log2(1+x) ? x / ln(2) where ln(2) ? 0.693
    // In 16.16 format: 1/ln(2) ? 1.4427 ? 0x00016A09
    localparam [31:0] INV_LN2_16_16 = 32'h00016A09;  // 1.4427 in 16.16
    
    // State register
    always @(posedge clk) begin
        if (rst) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end
    
    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (trig_valid) begin
                    if (trig_sel == 2'b11)  // log2
                        next_state = COMPUTE_LOG2;
                    else
                        next_state = COMPUTE;
                end
            end
            COMPUTE: begin
                next_state = WAIT_CORDIC;
            end
            WAIT_CORDIC: begin
                if (wait_counter >= 3)
                    next_state = DONE;
            end
            COMPUTE_LOG2: begin
                if (wait_counter >= 20)  // Give enough cycles for log2
                    next_state = DONE;
            end
            DONE: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end
    
    // Helper function to find MSB position
    function [4:0] find_msb;
        input [31:0] value;
        integer i;
        begin
            find_msb = 0;
            for (i = 31; i >= 0; i = i - 1) begin
                if (value[i] == 1'b1 && find_msb == 0) begin
                    find_msb = i;
                end
            end
        end
    endfunction
    
    // Output logic
    always @(posedge clk) begin
        if (rst) begin
            result <= 0;
            result_valid <= 0;
            overflow <= 0;
            trig_mode <= 0;
            tan_16_16 <= 0;
            wait_counter <= 0;
            log2_result <= 0;
            log2_input <= 0;
            log2_iter <= 0;
            msb_pos <= 0;
            normalized <= 0;
            frac_part <= 0;
        end else begin
            case (state)
                IDLE: begin
                    result_valid <= 0;
                    overflow <= 0;
                    wait_counter <= 0;
                    
                    if (trig_valid) begin
                        trig_mode <= trig_sel;
                        
                        // Initialize log2 computation if needed
                        if (trig_sel == 2'b11) begin
                            // Check for invalid input (negative or zero)
                            if (input_val <= 0) begin
                                log2_result <= 32'h80000000;  // Return -32768 for invalid
                                overflow <= 1;
                            end else begin
                                log2_input <= input_val;
                                log2_iter <= 0;
                                overflow <= 0;
                            end
                        end
                    end
                end
                
                COMPUTE: begin
                    // Start waiting for CORDIC to settle
                    wait_counter <= 0;
                end
                
                WAIT_CORDIC: begin
                    wait_counter <= wait_counter + 1;
                    
                    // After CORDIC settles, calculate tangent if needed
                    if (wait_counter >= 3) begin
                        if (trig_mode == 2'b10) begin
                            if (is_cos_zero) begin
                                tan_16_16 <= 32'h7FFFFFFF;
                                overflow <= 1;
                            end else begin
                                tan_16_16 <= ({{16{sin_out[15]}}, sin_out} << 16) / {{16{cos_out[15]}}, cos_out};
                            end
                        end
                    end
                end
                
                COMPUTE_LOG2: begin
                    wait_counter <= wait_counter + 1;
                    
                    if (wait_counter == 0) begin
                        // Step 1: Find MSB position (integer part of log2)
                        msb_pos <= find_msb(log2_input);
                    end
                    else if (wait_counter == 1) begin
                        // Step 2: Normalize to range [1.0, 2.0)
                        // Shift so MSB is at bit 16 (the integer/fraction boundary)
                        if (msb_pos >= 16) begin
                            normalized <= log2_input >> (msb_pos - 16);
                        end else begin
                            normalized <= log2_input << (16 - msb_pos);
                        end
                    end
                    else if (wait_counter == 2) begin
                        // Step 3: Extract fractional part (normalized - 1.0)
                        // In 16.16 format, 1.0 = 0x00010000
                        frac_part <= normalized - 32'h00010000;
                    end
                    else if (wait_counter == 3) begin
                        // Step 4: Approximate log2(1 + frac_part)
                        // Using: log2(1+x) ? x * (1/ln(2))
                        // Multiply in 16.16: (a * b) >> 16
                        log2_result <= (frac_part * INV_LN2_16_16) >>> 16;
                    end
                    else if (wait_counter == 4) begin
                        // Step 5: Add integer part (msb_pos - 16)
                        // Convert msb_pos offset to 16.16 format
                        if (msb_pos >= 16) begin
                            log2_result <= log2_result + ((msb_pos - 16) << 16);
                        end else begin
                            log2_result <= log2_result - ((16 - msb_pos) << 16);
                        end
                    end
                    
                    // Check for overflow
                    if (wait_counter == 5) begin
                        if (log2_result > 32'h7FFF0000 || log2_result < -32'h80000000) begin
                            overflow <= 1;
                            log2_result <= (log2_result[31]) ? 32'h80000000 : 32'h7FFF0000;
                        end
                    end
                end
                
                DONE: begin
                    // Select output based on mode
                    case (trig_mode)
                        2'b00: result <= sin_16_16;   // sin
                        2'b01: result <= cos_16_16;   // cos
                        2'b10: result <= tan_16_16;   // tan
                        2'b11: result <= log2_result; // log2
                        default: result <= 0;
                    endcase 
                    
                    result_valid <= 1;
                end
                
                default: begin
                    result_valid <= 0;
                    wait_counter <= 0;
                end
            endcase
        end
    end
endmodule
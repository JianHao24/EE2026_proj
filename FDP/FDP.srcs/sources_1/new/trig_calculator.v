module trig_calculator #(
    parameter FIXED_FRAC_BITS = 16
)(
    input wire clk,
    input wire rst,
    input wire trig_valid,              // Start calculation
    input wire [1:0] trig_sel,          // 00=sin, 01=cos, 10=tan
    input wire signed [31:0] input_val, // 16.16 format angle input
    output reg signed [31:0] result,    // 16.16 format result
    output reg result_valid,            // Result ready
    output reg overflow                 // Overflow flag
);
    // States
    localparam IDLE = 2'd0;
    localparam COMPUTE = 2'd1;
    localparam WAIT_CORDIC = 2'd2;
    localparam DONE = 2'd3;
    
    reg [1:0] state, next_state;
    reg [1:0] trig_mode;
    reg [2:0] wait_counter;
    
    // Convert 16.16 to Q6.10 for CORDIC input
    wire signed [15:0] angle_q610 = input_val[21:6];
    
    // CORDIC instance (your existing module)
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
    // Q1.15 << 1 = 16.16
    wire signed [31:0] sin_16_16 = {{16{sin_out[15]}}, sin_out} << 1;
    wire signed [31:0] cos_16_16 = {{16{cos_out[15]}}, cos_out} << 1;
    
    // Tangent calculation
    reg signed [31:0] tan_16_16;
    wire is_cos_zero = (cos_out >= -100 && cos_out <= 100);  // Near zero
    
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
                if (trig_valid)
                    next_state = COMPUTE;
            end
            COMPUTE: begin
                next_state = WAIT_CORDIC;
            end
            WAIT_CORDIC: begin
                if (wait_counter >= 3)
                    next_state = DONE;
            end
            DONE: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end
    
    // Output logic
    always @(posedge clk) begin
        if (rst) begin
            result <= 0;
            result_valid <= 0;
            overflow <= 0;
            trig_mode <= 0;
            tan_16_16 <= 0;
            wait_counter <= 0;
        end else begin
            case (state)
                IDLE: begin
                    result_valid <= 0;
                    overflow <= 0;
                    wait_counter <= 0;
                    
                    if (trig_valid) begin
                        trig_mode <= trig_sel;
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
                                // Tangent = sin/cos
                                tan_16_16 <= ({{16{sin_out[15]}}, sin_out} << 16) / {{16{cos_out[15]}}, cos_out};
                            end
                        end
                    end
                end
                
                DONE: begin
                    // Select output based on mode
                    case (trig_mode)
                        2'b00: result <= sin_16_16;  // sin
                        2'b01: result <= cos_16_16;  // cos
                        2'b10: result <= tan_16_16;  // tan
                        default: result <= 0;
                    endcase 
                    
                    result_valid <= 1;  // This will stay high for one full clock cycle
                end
                
                default: begin
                    result_valid <= 0;
                    wait_counter <= 0;
                end
            endcase
        end
    end
endmodule
`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10/19/2025 06:27:21 PM
// Design Name: 
// Module Name: digit_manager
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


//   Handles keypad-style numeric entry with support for digits, decimal point,
//   sign (negative), backspace, and submit (enter). Uses an internal circular
//   buffer to efficiently manage characters and metadata.

module digit_manager #(
    parameter BUFFER_SIZE = 8
)(
    input  wire clk,
    input  wire rst_n,
    input  wire active,                     // enables input logic
    
    // Command interface
    input  wire cmd_valid,                  // command ready
    input  wire [3:0] cmd_type,             // 0-9: digit, 10: dot, 11: backspace, 12: enter, 13: negative
    
    // Configuration
    input  wire enable_backspace_key,       // allows use of backspace key
    input  wire enable_negative_key,        // allows entering negative sign
     
    // Outputs
    output reg  [BUFFER_SIZE*4-1:0] packed_digits, // 4-bit packed array of buffer digits
    output reg  [3:0] total_chars,          // number of active characters in buffer
    output reg  sign_present,               // sign currently present
    output reg  dot_present,                // decimal point currently present
    output reg  [3:0] dot_location,         // index position of decimal point
    output reg  submit_ready                // input ready for conversion (enter pressed)
);

    // Buffers and metadata for storing input digits and their types
    reg [3:0] buffer_mem [0:BUFFER_SIZE-1]; // stores 4-bit values (0-9, dot, sign)
    reg [2:0] char_types [0:BUFFER_SIZE-1]; // 0=digit, 1=dot, 2=sign
    reg [3:0] write_ptr;                    // pointer to next buffer position (acts as index)
    
    integer j;
    
    // Character types
    localparam TYPE_DIGIT = 3'd0;           // regular numeric digit
    localparam TYPE_DOT   = 3'd1;           // decimal point
    localparam TYPE_SIGN  = 3'd2;           // sign (negative)
    
    // Key codes
    localparam KEY_DOT       = 4'd10;
    localparam KEY_BACKSPACE = 4'd11;
    localparam KEY_ENTER     = 4'd12;
    localparam KEY_NEGATIVE  = 4'd13;
    
    // Main input handler
    always @(posedge clk or negedge rst_n) begin
        // Reset or inactive mode clears all state
        if (!rst_n || !active) begin
            write_ptr     <= 0;              // reset write pointer
            total_chars   <= 0;              // clear total characters
            sign_present  <= 0;              // clear sign flag
            dot_present   <= 0;              // clear decimal flag
            dot_location  <= 4'hF;           // mark dot as unset
            submit_ready  <= 0;              // disable submit flag
            
            for (j = 0; j < BUFFER_SIZE; j = j + 1) begin
                buffer_mem[j] <= 0;          // clear stored digits
                char_types[j] <= TYPE_DIGIT; // reset type info
            end
        end
        else if (cmd_valid) begin
            submit_ready <= 0;               // clear submit flag each cycle
            
            case (cmd_type)
                // Handle Enter key
                KEY_ENTER: begin
                    submit_ready <= (total_chars > 0);  // mark input complete if non-empty
                end
                
                // Handle Decimal Point
                KEY_DOT: begin
                    if (!dot_present && write_ptr < BUFFER_SIZE) begin
                        buffer_mem[write_ptr] <= KEY_DOT;       // store dot symbol
                        char_types[write_ptr] <= TYPE_DOT;      // label as dot
                        dot_present           <= 1;             // flag dot presence
                        dot_location          <= write_ptr;     // remember dot position
                        write_ptr             <= write_ptr + 1; // advance pointer
                        total_chars           <= total_chars + 1; // update char count
                    end
                end
                
                // Handle Backspace
                KEY_BACKSPACE: begin
                    if (enable_backspace_key && write_ptr > 0) begin
                        write_ptr   <= write_ptr - 1;            // move pointer back
                        total_chars <= total_chars - 1;          // decrement count
                        
                        case (char_types[write_ptr - 1])
                            TYPE_DOT: begin
                                dot_present  <= 0;               // clear dot flag
                                dot_location <= 4'hF;            // reset dot index
                            end
                            TYPE_SIGN: begin
                                sign_present <= 0;               // clear sign flag
                            end
                        endcase
                        
                        buffer_mem[write_ptr - 1] <= 0;          // clear removed char
                        char_types[write_ptr - 1] <= TYPE_DIGIT; // reset char type
                    end
                end
                
                // Handle Negative Sign
                KEY_NEGATIVE: begin
                    if (enable_negative_key && write_ptr == 0 && !sign_present) begin
                        buffer_mem[0]  <= KEY_NEGATIVE;          // insert minus at start
                        char_types[0]  <= TYPE_SIGN;             // mark as sign
                        sign_present   <= 1;                     // flag sign
                        write_ptr      <= 1;                     // move pointer
                        total_chars    <= 1;                     // update count
                    end
                end
                
                // Handle Regular Digits
                default: begin
                    if (cmd_type < 10 && write_ptr < BUFFER_SIZE) begin
                        buffer_mem[write_ptr] <= cmd_type;       // store numeric digit
                        char_types[write_ptr] <= TYPE_DIGIT;     // mark as digit
                        write_ptr             <= write_ptr + 1;  // advance pointer
                        total_chars           <= total_chars + 1; // increment char count
                    end
                end
            endcase
        end
    end
    
    // Pack buffer into single output bus
    always @(*) begin
        packed_digits = 0;                  // clear before packing
        for (j = 0; j < BUFFER_SIZE; j = j + 1) begin
            packed_digits[j*4 +: 4] = buffer_mem[j]; // pack each digit into output
        end
    end

endmodule

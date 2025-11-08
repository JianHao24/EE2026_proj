// diff_params_simple.vh
`ifndef DIFF_PARAMS_SIMPLE_VH
`define DIFF_PARAMS_SIMPLE_VH

// Formats
`define COEFF_W     32     // fixed-point width for coefficients (e.g., Q4.28 or Q16.16)
`define DATA_W      32     // Q16.16 for x and results
`define FRAC_BITS   16     // fractional bits for Q16.16

// Limits
`define MAX_DEG      8     // support up to degree 8 (a0..a8)

// Simple status bit positions (for a small status_bus if you want)
`define STS_VALID_BIT   0
`define STS_BUSY_BIT    1

`endif

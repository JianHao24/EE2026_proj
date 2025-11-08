// ===================== deriv_coeff_gen_fixed4.v =====================
`timescale 1ns/1ps
`include "diff_params.vh"

module deriv_coeff_gen_fixed4 #(
  parameter integer COEFF_W = `COEFF_W
)(
  input  wire                   clk,
  input  wire                   rst_n,    // active-low sync reset

  // Load base polynomial a[i], i=0..4 (Q-format same as system)
  input  wire [COEFF_W-1:0]     a_bus,
  input  wire [2:0]             a_idx,    // 0..4
  input  wire                   a_we,

  // Start/status (immediate 'done' pulse on cfg_start)
  input  wire                   cfg_start,
  output reg                    busy,
  output reg                    done,     // 1-cycle pulse

  // Plain polynomial read: a[k], k=0..4
  input  wire [2:0]             a_addr,
  output wire [COEFF_W-1:0]     a_rdata,

  // Derivative read: b[j], j=0..3  (b0=a1, b1=2a2, b2=3a3, b3=4a4)
  input  wire [1:0]             b_addr,
  output wire [COEFF_W-1:0]     b_rdata
);

  // Base coefficients a[0..4]
  reg signed [COEFF_W-1:0] a_mem [0:4];
  integer k;

  always @(posedge clk) begin
    if (!rst_n) begin
      for (k=0; k<=4; k=k+1) a_mem[k] <= {COEFF_W{1'b0}};
      busy <= 1'b0;
      done <= 1'b0;
    end else begin
      done <= 1'b0;
      if (a_we) a_mem[a_idx] <= a_bus;
      if (cfg_start) begin
        busy <= 1'b0;
        done <= 1'b1;    // instantaneous in this simple generator
      end
    end
  end

  // Plain polynomial read
  assign a_rdata = (a_addr <= 3'd4) ? a_mem[a_addr] : {COEFF_W{1'b0}};

  // Small integer multiply helper (synthesizable)
  function signed [COEFF_W-1:0] mul_int;
    input signed [COEFF_W-1:0] x;
    input integer              kint;
    begin
      mul_int = x * kint;
    end
  endfunction

  // Derivative coeffs: b0=a1, b1=2a2, b2=3a3, b3=4a4
  assign b_rdata = (b_addr==2'd0) ? a_mem[1] :
                   (b_addr==2'd1) ? mul_int(a_mem[2], 2) :
                   (b_addr==2'd2) ? mul_int(a_mem[3], 3) :
                   (b_addr==2'd3) ? mul_int(a_mem[4], 4) :
                                     {COEFF_W{1'b0}};
endmodule

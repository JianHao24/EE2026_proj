// ========================= diff_core_1st.v ==========================
`timescale 1ns/1ps
`include "diff_params.vh"

module diff_core_1st #(
  parameter integer DATA_W  = `DATA_W,   // e.g., 32 (Q16.16)
  parameter integer COEFF_W = `COEFF_W,  // coeff width
  parameter integer FRAC    = `FRAC_BITS // e.g., 16
)(
  input  wire                       clk,
  input  wire                       rst_n,       // active-low sync reset

  // Load interface (pass-through to generator)
  input  wire [COEFF_W-1:0]         a_bus,
  input  wire [2:0]                 a_idx,       // 0..4
  input  wire                       a_we,

  // Control
  input  wire                       cfg_start,   // pulse to start an evaluation
  input  wire                       mode,        // 0: f(x), 1: f'(x)
  input  wire [2:0]                 deg_n,       // poly degree (0..4)

  // Evaluation input
  input  wire signed [DATA_W-1:0]   x_cursor,    // Q format

  // Output
  output reg  signed [DATA_W-1:0]   fp1,         // result
  output reg                        busy,
  output reg                        valid        // 1-cycle pulse when fp1 updated
);

  // ---------------- Coeff generator (fixed-4) ----------------
  wire                    gen_busy, gen_done;
  reg  [2:0]             a_addr;       // 0..4 for a[k]
  wire [COEFF_W-1:0]     a_rdata;
  reg  [1:0]             b_addr;       // 0..3 for b[j]
  wire [COEFF_W-1:0]     b_rdata;

  deriv_coeff_gen_fixed4 #(
    .COEFF_W(COEFF_W)
  ) u_gen (
    .clk(clk), .rst_n(rst_n),
    .a_bus(a_bus), .a_idx(a_idx), .a_we(a_we),
    .cfg_start(cfg_start),
    .busy(gen_busy), .done(gen_done),
    .a_addr(a_addr), .a_rdata(a_rdata),
    .b_addr(b_addr), .b_rdata(b_rdata)
  );

  // ---------------- Helpers ----------------
  function signed [DATA_W-1:0] align_coeff;
    input signed [COEFF_W-1:0] c;
    begin
      if (COEFF_W >= DATA_W)
        align_coeff = c[COEFF_W-1 : COEFF_W-DATA_W];
      else
        align_coeff = {{(DATA_W-COEFF_W){c[COEFF_W-1]}}, c};
    end
  endfunction

  function signed [DATA_W-1:0] qmul_q;
    input signed [DATA_W-1:0] a;
    input signed [DATA_W-1:0] b;
    reg   signed [(2*DATA_W)-1:0] p;
    reg   signed [DATA_W-1:0]     truncd;
    begin
      p      = $signed(a) * $signed(b);
      truncd = p[FRAC + DATA_W - 1 : FRAC];              // >> FRAC
      qmul_q = truncd + {{(DATA_W-1){1'b0}}, p[FRAC-1]}; // round-to-nearest
    end
  endfunction

  // Map 3-bit k -> 2-bit for b_addr safely
  function [1:0] to_u2;
    input [2:0] k3;
    begin
      case (k3)
        3'd0: to_u2 = 2'd0;
        3'd1: to_u2 = 2'd1;
        3'd2: to_u2 = 2'd2;
        default: to_u2 = 2'd3;
      endcase
    end
  endfunction

  // Compute starting k based on mode/deg
  function [2:0] start_k_fn;
    input m;            // mode
    input [2:0] dn;     // degree
    reg [2:0] d1;
    begin
      if (m) begin
        d1 = (dn > 0) ? (dn - 1) : 3'd0;   // derivative degree
        start_k_fn = (d1 > 3) ? 3'd3 : d1; // cap at 3
      end else begin
        start_k_fn = (dn > 4) ? 3'd4 : dn; // cap at 4
      end
    end
  endfunction

  // ---------------- Horner evaluator ----------------
  reg [2:0]                k;        // counts down to 0
  reg signed [DATA_W-1:0]  acc;
  reg signed [DATA_W-1:0]  x_val;
  reg [COEFF_W-1:0]        coeff_q;

  wire [COEFF_W-1:0] coeff_sel = mode ? b_rdata : a_rdata;

  // capture selected coefficient one cycle after address is issued
  always @(posedge clk) begin
    coeff_q <= coeff_sel;
  end

  // FSM
  localparam [2:0] S_IDLE = 3'd0,
                   S_PREP = 3'd1,
                   S_WAIT = 3'd2,
                   S_EVAL = 3'd3,
                   S_DONE = 3'd4;

  reg [2:0] state, nstate;

  // state regs
  always @(posedge clk) begin
    if (!rst_n) begin
      state   <= S_IDLE;
      busy    <= 1'b0;
      valid   <= 1'b0;
      fp1     <= {DATA_W{1'b0}};
      k       <= 3'd0;
      acc     <= {DATA_W{1'b0}};
      x_val   <= {DATA_W{1'b0}};
      a_addr  <= 3'd0;
      b_addr  <= 2'd0;
    end else begin
      state <= nstate;
      valid <= 1'b0; // default

      case (state)
        S_IDLE: begin
          busy <= 1'b0;
        end

        // Issue first read for current k (a[k] or b[k]); capture x
        S_PREP: begin
          busy  <= 1'b1;
          k     <= start_k_fn(mode, deg_n);
          acc   <= {DATA_W{1'b0}};
          x_val <= x_cursor;

          if (mode) b_addr <= to_u2(start_k_fn(mode, deg_n));
          else       a_addr <=        start_k_fn(mode, deg_n);
        end

        // WAIT lets coeff_q capture the CURRENT term
        S_WAIT: begin
          // No addr changes here; addr for CURRENT k already set
        end

        // Horner: acc = acc*x + coeff[k]  (coeff_q is CURRENT k term)
        S_EVAL: begin
          acc <= qmul_q(acc, x_val) + align_coeff(coeff_q);

          if (k > 3'd0) begin
            k <= k - 3'd1;
            if (mode) b_addr <= to_u2(k - 3'd1); else a_addr <= (k - 3'd1);
          end
        end

        S_DONE: begin
          busy  <= 1'b0;
          valid <= 1'b1;
          fp1   <= acc;
        end
      endcase
    end
  end

  // next-state (WAIT between EVALs is essential)
  always @* begin
    nstate = state;
    case (state)
      S_IDLE:  nstate = cfg_start ? S_PREP : S_IDLE;
      S_PREP:  nstate = S_WAIT;                     // capture first coeff
      S_WAIT:  nstate = S_EVAL;                     // use captured coeff
      S_EVAL:  nstate = (k == 3'd0) ? S_DONE : S_WAIT; // more terms? go WAIT then EVAL
      S_DONE:  nstate = S_IDLE;
      default: nstate = S_IDLE;
    endcase
  end

endmodule

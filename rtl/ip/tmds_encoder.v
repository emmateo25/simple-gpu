// TMDS encoder — DVI 1.0 specification Section 3.3.3
//
// Converts an 8-bit pixel channel to a 10-bit TMDS word each pixel clock.
// Two encoding stages:
//   Phase 1: transition-minimised 8→9 bit coding (XOR or XNOR chain).
//   Phase 2: DC-balance using a signed running-disparity counter.
//
// During blanking (de=0) the encoder outputs one of four 10-bit control
// tokens defined by the DVI spec.  The blue channel carries {vsync,hsync}
// as ctrl[1:0]; all other channels should tie ctrl to 2'b00.

module tmds_encoder (
    input  wire        clk,    // pixel clock (25.2 MHz)
    input  wire        rst_n,  // active-low reset
    input  wire [7:0]  din,    // 8-bit pixel data (R, G or B channel)
    input  wire [1:0]  ctrl,   // control bits: {vsync, hsync} (blue only, else 0)
    input  wire        de,     // data enable: high inside active video area
    output reg  [9:0]  dout    // 10-bit TMDS word (LSB transmitted first by OSER10)
);

// ---- Phase 1: transition-minimised encoding ----
// Count 1s in din to choose XOR vs XNOR chain
wire [3:0] n1d = din[0]+din[1]+din[2]+din[3]+din[4]+din[5]+din[6]+din[7];

// XOR chain: q_m[8]=1
wire [7:0] q_xor;
assign q_xor[0] = din[0];
assign q_xor[1] = q_xor[0] ^ din[1];
assign q_xor[2] = q_xor[1] ^ din[2];
assign q_xor[3] = q_xor[2] ^ din[3];
assign q_xor[4] = q_xor[3] ^ din[4];
assign q_xor[5] = q_xor[4] ^ din[5];
assign q_xor[6] = q_xor[5] ^ din[6];
assign q_xor[7] = q_xor[6] ^ din[7];

// XNOR chain: q_m[8]=0
wire [7:0] q_xnor;
assign q_xnor[0] = din[0];
assign q_xnor[1] = ~(q_xnor[0] ^ din[1]);
assign q_xnor[2] = ~(q_xnor[1] ^ din[2]);
assign q_xnor[3] = ~(q_xnor[2] ^ din[3]);
assign q_xnor[4] = ~(q_xnor[3] ^ din[4]);
assign q_xnor[5] = ~(q_xnor[4] ^ din[5]);
assign q_xnor[6] = ~(q_xnor[5] ^ din[6]);
assign q_xnor[7] = ~(q_xnor[6] ^ din[7]);

// Use XNOR when more 1s than 0s, or tied with din[0]=0 (per DVI spec)
wire use_xnor  = (n1d > 4) | (n1d == 4 & ~din[0]);

wire [8:0] q_m;
assign q_m[7:0] = use_xnor ? q_xnor : q_xor;
assign q_m[8]   = ~use_xnor;  // 1 = XOR mode, 0 = XNOR mode

// ---- Phase 2: DC balance ----
wire [3:0] n1q = q_m[0]+q_m[1]+q_m[2]+q_m[3]+q_m[4]+q_m[5]+q_m[6]+q_m[7];
wire [3:0] n0q = 4'd8 - n1q;

// Signed disparity counter: tracks accumulated DC imbalance (-8..+8)
reg signed [4:0] cnt;

wire cnt_zero    = (cnt == 5'sd0);
wire n1q_eq_n0q  = (n1q == n0q);
wire cnt_pos     = (cnt > 5'sd0);
wire cnt_neg     = (cnt < 5'sd0);
wire heavy_ones  = (n1q > 4);
wire heavy_zeros = (n1q < 4);

// Signed difference n1q - n0q (range -8..+8)
wire signed [4:0] diff = $signed({1'b0, n1q}) - $signed({1'b0, n0q});

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        cnt  <= 5'sd0;
        dout <= 10'b1101010100;
    end else if (!de) begin
        // Send fixed control tokens during blanking; reset disparity
        case (ctrl)
            2'b00: dout <= 10'b1101010100;
            2'b01: dout <= 10'b0010101011;
            2'b10: dout <= 10'b0101010100;
            2'b11: dout <= 10'b1010101011;
        endcase
        cnt <= 5'sd0;
    end else begin
        if (cnt_zero || n1q_eq_n0q) begin
            // No accumulated disparity or perfectly balanced: apply q_m[8] inversion rule
            dout[9]   <= ~q_m[8];
            dout[8]   <=  q_m[8];
            if (q_m[8]) begin
                dout[7:0] <= q_m[7:0];
                cnt <= cnt + diff;       // += n1q - n0q
            end else begin
                dout[7:0] <= ~q_m[7:0];
                cnt <= cnt - diff;       // += n0q - n1q
            end
        end else if ((cnt_pos && heavy_ones) || (cnt_neg && heavy_zeros)) begin
            // Disparity and data lean same way → invert data to restore balance
            dout[9]   <= 1'b1;
            dout[8]   <=  q_m[8];
            dout[7:0] <= ~q_m[7:0];
            // cnt += 2*q_m[8] + n0q - n1q
            cnt <= cnt + (q_m[8] ? 5'sd2 : 5'sd0) - diff;
        end else begin
            // Opposite leanings → pass data through unchanged
            dout[9]   <= 1'b0;
            dout[8]   <=  q_m[8];
            dout[7:0] <= q_m[7:0];
            // cnt += n1q - n0q - 2*(1 - q_m[8])
            cnt <= cnt + diff - (q_m[8] ? 5'sd0 : 5'sd2);
        end
    end
end

endmodule

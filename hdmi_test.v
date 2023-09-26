module  HDMI_test (
    input clk,                          //25MHz
    output [2:0] TMDSp, TMDSn,
    output TMDSp_clk, TMDSn_clk
);

reg [9:0] cntx = 0, cnty = 0;
reg hsync, vsync, draw_area;

always @(posedge clk) begin
    draw_area <= (cntx < 640) && (cnty < 480);
end

always @(posedge clk) begin
    if(cntx == 799)
        cnty <= (cnty == 524) ? 0 : cnty + 1;
end

always @(posedge clk) begin
    hsync <= (cntx >= 656) && (cntx < 752);
end

always @(posedge clk) begin
    vsync <= (cnty >= 490) && (cnty < 492);
end

wire [7:0] w = {8{cntx[7:0] == cnty[7:0]}};
wire [7:0] a = {8{cntx[7:5] == 3'h2 && cnty[7:5] == 3'h2}};
reg [7:0] red, green, blue;

always @(posedge clk) begin
    red <= ({cntx[5:0] & {6{cnty[4:3] == ~cntx[4:3]}}, 2'b00} | w) & ~a;
end

always @(posedge clk) begin
    green <= (cntx[7:0] & {8{cnty[6]}} | w) & ~a;
end

always @(posedge clk) begin
    blue <= cnty [7:0] | w | a;
end

wire [9:0] TMDS_r, TMDS_g, TMDS_b;
TMDS_encoder enc_r(.clk(clk), .VD(red), .CD(2'b00), .VDE(draw_area), .TMDS(TMDS_r));
TMDS_encoder enc_g(.clk(clk), .VD(green), .CD(2'b00), .VDE(draw_area), .TMDS(TMDS_g));
TMDS_encoder enc_b(.clk(clk), .VD(blue), .CD({vsync, hsync}), .VDE(draw_area), .TMDS(TMDS_b));

wire clk_TMDS, DCM_TMDS_CLKFX;          // 25MHz x 10 = 250MHz
DCM_SP #(.CLKFX_MULTIPLY(10)) DCM_TMDS_inst(.CLKIN(clk), .CLKFX(DCM_TMDS_CLKFX), .RST(1'b0));
BUFG BUFG_TMDSp(.I(DCM_TMDS_CLKFX), .O(clk_TMDS));

reg [3:0] TMDS_mod10=0;  // modulus 10 counter
reg [9:0] TMDS_shift_r=0, TMDS_shift_g=0, TMDS_shift_b=0;
reg TMDS_shift_load=0;
always @(posedge clk_TMDS) TMDS_shift_load <= (TMDS_mod10==4'd9);

always @(posedge clk_TMDS)
begin
	TMDS_shift_r   <= TMDS_shift_load ? TMDS_r   : TMDS_shift_r[9:1];
	TMDS_shift_g <= TMDS_shift_load ? TMDS_g : TMDS_shift_g[9:1];
	TMDS_shift_b  <= TMDS_shift_load ? TMDS_b  : TMDS_shift_b[9:1];	
	TMDS_mod10 <= (TMDS_mod10==4'd9) ? 4'd0 : TMDS_mod10+4'd1;
end

OBUFDS OBUFDS_r  (.I(TMDS_shift_r  [0]), .O(TMDSp[2]), .OB(TMDSn[2]));
OBUFDS OBUFDS_g(.I(TMDS_shift_g[0]), .O(TMDSp[1]), .OB(TMDSn[1]));
OBUFDS OBUFDS_b (.I(TMDS_shift_b [0]), .O(TMDSp[0]), .OB(TMDSn[0]));
OBUFDS OBUFDS_clk(.I(clk), .O(TMDSp_clk), .OB(TMDSn_clk));
endmodule

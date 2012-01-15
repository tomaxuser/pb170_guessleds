/**
*  clk_div - simple clock signal divider
*/


module clk_div (
	CLK, RST, CLK_DIV, cntr
	);

	input CLK;
	input RST;
	output CLK_DIV;
	output [31:0] cntr;

	reg [31:0] cntr;
	reg CLK_DIV;
	parameter divider = 32'd6_000_000;

	always@(posedge CLK)
	begin
		if (!RST || !cntr) cntr <= divider;
		else cntr <= cntr - 1;
	end

	always@(posedge CLK)
	begin
		if (cntr == 1) CLK_DIV = 1;
		else CLK_DIV = 0;
	end

endmodule


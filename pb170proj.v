/**
 *  Guess LEDs
 *
 *  Tomas Szaniszlo, UCO 359894
 *  xszanisz@fi.muni.cz
 *
 *  A simple game where the objective is to guess which LEDs were lit up for a brief moment.
 *  Guessed and total attempts are displayed on hex display.
 *
 */

module pb170proj (
		CLK, KEY, SW, LEDG, LEDR, HEX4, HEX5, HEX6, HEX7
	);


	/* clock divider module */
	clk_div divider1 (
		.cntr(CNTR), .CLK(CLK), .RST(rst), .CLK_DIV(clk_div)
	);
	defparam divider1.divider = 2_000_000;


	/* Input and output ports, registers and assignments */
	input CLK;
	input	[1:0] KEY;
	input	[15:0] SW;
	output [4:0] LEDG;
	output [15:0] LEDR;
	output [6:0] HEX4;
	output [6:0] HEX5;
	output [6:0] HEX6;
	output [6:0] HEX7;

	wire clk_div;
	wire rst;

	reg [31:0] CNTR;
	reg [15:0] LEDS;
	reg [4:0] LEDZ;
	reg [19:0] rnd;

	/* hex displays */
	reg [6:0] HX4;
	reg [6:0] HX6;
	reg [6:0] HX5;
	reg [6:0] HX7;
	assign HEX4 = HX4;
	assign HEX6 = HX6;
	assign HEX5 = HX5;
	assign HEX7 = HX7;
	
	reg [15:0] ledscfg;
	reg [2:0] mode;
	reg [15:0] cntdwn;
	reg [3:0] rounds_ok;
	reg [3:0] rounds;
	reg old_key1;

	assign LEDR = LEDS;
	assign LEDG = LEDZ;
	assign rst = KEY[0];


	/**
	 *  Task for displaying 7-segment digits
	 */
	task showhex;
	input pos;
	input [3:0] num;
	reg [6:0] hex;
	begin
		case (num)
		0: hex = 7'b1000000;
		1: hex = 7'b1111001;
		2: hex = 7'b0100100;
		3: hex = 7'b0110000;
		4: hex = 7'b0011001;
		5: hex = 7'b0010010;
		6: hex = 7'b0000010;
		7: hex = 7'b1111000;
		8: hex = 7'b0000000;
		9: hex = 7'b0010000;
		default: hex = 7'b1111111;
		endcase
		if (pos == 0)
			HX6 <= hex;
		else
			HX4 <= hex;
	end
	endtask
	
	
	initial
	begin
		HX7 <= 7'b1111111;
		HX5 <= 7'b1111111;
	end


	/* main block */
	always @(posedge CLK)
	begin

		/* is KEY[0] pressed */
		if (KEY[0] == 0)
		begin
			mode = 0;
			rounds = 0;
			rounds_ok = 0;
			old_key1 = 0;
		end

		
		/* detect KEY[1] negedge */
		if (KEY[1] == 0 && old_key1 == 1)
		begin
			case (mode)
			0:
			begin
				rnd = CNTR[19:0];
				mode = 1;
			end
			2:
			begin
				mode = 3;
			end
			endcase
		end
		old_key1 = KEY[1];
		

		if (clk_div)
		begin
			case (mode)
			
			0:
			begin
				/* nothing to do... waiting for user to press KEY[1] */
				cntdwn = 5;
			end
			
			1:
			begin
				/* user pressed KEY[1], showing random LEDs for a short time */
				case (cntdwn)
				0:
				begin
					/* time has run up, let him guess */
					LEDS <= 0;
					mode = 2;
					cntdwn = 500;
				end
				5:
				begin
					/* start showing LEDs */
					ledscfg = (16'b1 << rnd[3:0]) | (16'b1 << rnd[7:4]) | (16'b1 << rnd[11:8]) | (16'b1 << rnd[15:12]); // | (16'b1 << rnd[19:16]);
					LEDS <= ledscfg;
					cntdwn = cntdwn - 16'b1;
				end
				default:
				begin
					/* decrement counter */
					cntdwn = cntdwn - 16'b1;
				end
				endcase
			end

			2:
			begin
				/* user is trying to guess which LEDs lit */
				if (cntdwn == 0)
				begin
					/* time has run up, go to evaluation phase */
					mode = 3;
				end
				else
				begin
					/* decrement counter */
					cntdwn = cntdwn - 16'b1;
				end
			end

			3:
			begin
				/* user pressed KEY[1], he thinks he got his guess right, evaluate */
				cntdwn = 96;
				if (SW[15:0] == ledscfg)
				begin
					rounds_ok = rounds_ok + 4'b1;
					cntdwn = 48;
				end
				rounds = rounds + 4'b1;
				mode = 4;
			end

			4:
			begin
				/* show him the answer */
				LEDS <= cntdwn[2] ? ledscfg : 16'b0;
				if (cntdwn == 0)
				begin
					if (rounds == 5)
					begin
						mode = 5;
						LEDS <= 16'b1;
					end
					else
					begin
						mode = 0;
					end
				end
				cntdwn = cntdwn - 16'b1;
			end
			
			5:
			begin
				/* the end, final mode; only reset can exit from it */
				cntdwn = cntdwn + 16'b1;
				// LEDS <= (cntdwn[3] == 0) ? 16'hffff : 16'h0000;
				LEDS <= (LEDS[14:0] << 1) | LEDS[15];
			end

			endcase
			LEDZ <= (5'b1 << mode);

		end

		showhex(0, rounds_ok);
		showhex(1, rounds);
		
	end

endmodule

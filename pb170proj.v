/**
 *  Guess LEDs
 *
 *  Tomas Szaniszlo, UCO 359894
 *  xszanisz()fi.muni.cz
 *
 *  A simple game where the objective is to guess which LEDs were lit up for a brief moment.
 *  Guessed and total attempts are displayed on hex display.
 *  Target: Altera DE2, FPGA Cyclone II EP2C70F896
 *
 */

module pb170proj (
		CLK, KEY, SW, LEDG, LEDR, HEX4, HEX5, HEX6, HEX7
	);


	/* clock divider module */
	clk_div divider1 (
		.cntr(cntr), .CLK(CLK), .RST(RST), .CLK_DIV(clk_div)
	);
	defparam divider1.divider = 2_000_000;


	/* Input and output ports, registers and assignments */
	input CLK;
	input [1:0] KEY;
	input [15:0] SW;
	output [4:0] LEDG;
	output [15:0] LEDR;
	output [6:0] HEX4;
	output [6:0] HEX5;
	output [6:0] HEX6;
	output [6:0] HEX7;

	wire clk_div;
	wire RST;

	reg [31:0] cntr;
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
	reg [15:0] cnt_m1;
	reg [15:0] cnt_m2;
	reg [15:0] cnt_m4a;
	reg [15:0] cnt_m4b;
	reg [3:0] rounds_ok;
	reg [3:0] rounds;
	reg [3:0] max_rounds;
	reg old_key1;

	assign LEDR = LEDS;
	assign LEDG = LEDZ;
	assign RST = KEY[0];


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


	/* initialisation */
	initial
	begin
		/* turn off unnecessary hex displays */
		HX7 <= 7'b1111111;
		HX5 <= 7'b1111111;

		max_rounds = 4'd8;

		/* set time spent in various modes */
		/* how long are the LEDs displayed */
		cnt_m1 = 16'd5;
		/* how much time has the user to answer */
		cnt_m2 = 16'd500;
		/* how long should the correct answer be displayed if user failed */
		cnt_m4a = 16'd96;
		/* how long should the correct answer be displayed if user passed */
		cnt_m4b = 16'd48;
	end


	/* main block */
	always @(posedge CLK)
	begin

		/* is KEY[0] pressed? */
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
				/* get randomness from the clock transitions counter;
				 * with 20 bits and clock divider 20M for UI it can be
				 * considered fairly random */
				rnd = cntr[19:0];
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
			
			/* nothing to do... waiting for user to press KEY[1];
			 * this mode is used to get some randomness from the delay
			 * between entering it and the user pressing KEY[1] */
			0:
			begin
				/* prepare counter for mode 1 */
				cntdwn = cnt_m1;
			end
			
			/* user pressed KEY[1], show random LEDs for a short time */
			1:
			begin
				case (cntdwn)
				0:
				begin
					/* time has run up, let him guess */
					LEDS <= 0;
					cntdwn = cnt_m2;
					mode = 2;
				end
				cnt_m1:
				begin
					/* start showing LEDs; a combination of 1-5 LEDs is shown;
					 * five random (possibly overlaping) positions 0-15 are chosen */
					ledscfg = (16'b1 << rnd[3:0]) | (16'b1 << rnd[7:4]) | (16'b1 << rnd[11:8]) | (16'b1 << rnd[15:12]) | (16'b1 << rnd[19:16]);
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

			/* user is trying to guess which LEDs lit */
			2:
			begin
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

			/* user pressed KEY[1], he thinks he got his guess right, evaluate */
			3:
			begin
				cntdwn = cnt_m4a;
				if (SW[15:0] == ledscfg)
				begin
					/* guess correct */
					rounds_ok = rounds_ok + 4'b1;
					cntdwn = cnt_m4b;
				end
				rounds = rounds + 4'b1;

				/* update score */
				showhex(0, rounds_ok);
				showhex(1, rounds);

				mode = 4;
			end

			/* show him the answer */
			4:
			begin
				/* blink the correct answer */
				LEDS <= cntdwn[2] ? ledscfg : 16'b0;

				if (cntdwn == 0)
				begin
					if (rounds == max_rounds)
					begin
						/* the end of the game */
						LEDS <= 16'b1;
						mode = 5;
					end
					else
					begin
						mode = 0;
					end
				end
				cntdwn = cntdwn - 16'b1;
			end
			
			/* the end, final mode; only reset signal can escape from it */
			5:
			begin
				/* some random effect */
				// cntdwn = cntdwn + 16'b1;
				// LEDS <= (cntdwn[3] == 0) ? 16'hffff : 16'h0000;
				LEDS <= (LEDS[14:0] << 1) | LEDS[15];
			end

			endcase

			/* display current mode */
			LEDZ <= (5'b1 << mode);

		end

	end

endmodule


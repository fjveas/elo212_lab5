/*
 *
 */

`timescale 1ns / 1ps

module top_level
(
	input clk_100M,
	input reset_n,

	input uart_rx,
	output uart_tx,

	output [7:0] ss_value,
	output [7:0] ss_select,
	output [2:0] rgb_led16,
	output [15:0] leds
);

	/* UART signals */
	wire [7:0] rx_data;
	wire rx_ready;
	wire [7:0] tx_data;
	wire tx_start;
	wire tx_busy;

	/* ALU signals */
	wire [15:0] alu_in1;
	wire [15:0] alu_in2;
	wire [2:0] alu_op;
	wire [15:0] alu_out;
	wire [4:0] alu_flags;

	/* Trigger signal from rx_ctrl to tx_ctrl for sending the result */
	wire send_result;

	/* Register ALU outputs to display (glue logic) */
	reg [15:0] alu_out_reg;
	reg [4:0] alu_flags_reg;
	always @(posedge clk_100M) begin
		if (~reset_n) begin
			alu_out_reg <= 'd0;
			alu_flags_reg <= 'd0;
		end else if (send_result) begin
			alu_out_reg <= alu_out;
			alu_flags_reg <= alu_flags;
		end
	end

	assign leds = alu_out_reg;

	wire [2:0] rgb_state;
	rx_controller rx_ctrl_inst (
		.clk(clk_100M),
		.reset(~reset_n),
		.rx_ready(rx_ready),
		.rx_data(rx_data),
		.alu_in1(alu_in1),
		.alu_in2(alu_in2),
		.alu_op(alu_op),
		.send_result(send_result),
		.rgb_state(rgb_state)
	);

	tx_controller tx_ctrl_inst (
		.clk(clk_100M),
		.reset(~reset_n),
		.tx_busy(tx_busy),
		.tx_start(tx_start),
		.tx_data(tx_data),
		.alu_out(alu_out),
		.send_result(send_result)
	);

	/* UART instantiation */
	uart_basic #(
		.CLK_FREQUENCY(100000000),
		.BAUD_RATE(115200)
	) uart_inst (
		.clk(clk_100M),
		.reset(~reset_n),
		.rx(uart_rx),
		.rx_data(rx_data),
		.rx_ready(rx_ready),
		.tx(uart_tx),
		.tx_start(tx_start),
		.tx_data(tx_data),
		.tx_busy(tx_busy)
	);

	/* ALU instantiation */
	alu #(
		.WIDTH(16)
	) alu_inst (
		.in1(alu_in1),
		.in2(alu_in2),
		.op(alu_op),
		.out(alu_out),
		.flags(alu_flags)
	);

	/* Clock divider for the 7 segment display */
	wire clk_ss;
	clk_divider #(
		.O_CLK_FREQ(480)
	) clk_div_ss_display (
		.clk_in(clk_100M),
		.reset(1'b0),
		.clk_out(clk_ss)
	);

	/* Double dabble & absolute value (glue logic) */
	wire [31:0] bcd;
	wire is_negative = alu_out_reg[15];
	wire [15:0] alu_out_abs =
		(is_negative) ? (~alu_out_reg + 1) : alu_out_reg; // C2 absolute value

	unsigned_to_bcd u32_to_bcd_inst (
		.clk(clk_100M),
		.trigger(1'b1),
		.in({16'd0, alu_out_abs}),
		.idle(),
		.bcd(bcd)
	);

	/* 7 segment display driver */
	display_mux display_mux_inst (
		.clk(clk_ss),
		.clk_enable(1'b1),
		.bcd(bcd),
		.dots({3'd0, alu_flags_reg}),
		.is_negative(is_negative),
		.turn_off(1'b0),
		.ss_value(ss_value),
		.ss_select(ss_select)
	);

	/* RGB led (glue logic) */
	wire clk_counter;
	reg dir_counter;
	reg [5:0] cmp_counter;

	always @(posedge clk_counter) begin
		if (dir_counter == 1'b0)
			cmp_counter <= cmp_counter + 'd1;
		else
			cmp_counter <= cmp_counter - 'd1;

		if (cmp_counter == 62)
			dir_counter <= 1'b1;
		else if (cmp_counter == 1)
			dir_counter <= 1'b0;
	end

	wire pwm_clk;
	wire pwm_out;
	assign rgb_led16 = {3{pwm_out}} & rgb_state;

	pwm #(
		.CTR_LEN(6)
	) pwm_inst (
		.clk(pwm_clk),
		.reset(~reset_n),
		.compare(cmp_counter),
		.out(pwm_out)
	);

	clk_divider #(
		.O_CLK_FREQ(64000)
	) clk_div_pwm (
		.clk_in(clk_100M),
		.reset(1'b0),
		.clk_out(pwm_clk)
	);

	clk_divider #(
		.O_CLK_FREQ(40)
	) clk_div_counter (
		.clk_in(clk_100M),
		.reset(1'b0),
		.clk_out(clk_counter)
	);

endmodule

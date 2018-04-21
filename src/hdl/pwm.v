/*
 * pwm.v
 *
 * https://embeddedmicro.com/tutorials/mojo/pulse-width-modulation
 */

`timescale 1ns / 1ps

module pwm
#(
	parameter CTR_LEN = 8
)(
	input clk,
	input reset,
	input [CTR_LEN-1:0] compare,
	output out
);

	reg pwm_d, pwm_q;
	reg [CTR_LEN-1:0] ctr_d, ctr_q;

	assign out = pwm_q;

	always @(*) begin
		ctr_d = ctr_q + 1'b1;

		if (compare > ctr_q)
			pwm_d = 1'b1;
		else
			pwm_d = 1'b0;
	end

	always @(posedge clk) begin
		if (reset) begin
			ctr_q <= 1'b0;
		end else begin
			ctr_q <= ctr_d;
		end

		pwm_q <= pwm_d;
	end

endmodule
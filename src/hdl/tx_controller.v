/*
 *
 */

`timescale 1ns / 1ps

module tx_controller
(
	input clk,
	input reset,

	input tx_busy,
	output reg tx_start,
	output reg [7:0] tx_data,

	input [15:0] alu_out,
	input send_result
);

	/* Machine states */
	localparam TX_IDLE     = 'b000;
	localparam TX_SEND_LSB = 'b001;
	localparam TX_WAIT_LSB = 'b010;
	localparam TX_SEND_MSB = 'b011;
	localparam TX_WAIT_MSB = 'b100;

	reg [2:0] tx_state, tx_state_next;

	always @(*) begin
		tx_state_next = tx_state;
		tx_data = 'd0;
		tx_start = 1'b0;

		case (tx_state)
		TX_IDLE:
			if (send_result)
				tx_state_next = TX_SEND_LSB;
		TX_SEND_LSB: begin
			tx_data = alu_out[7:0];
			tx_start = 1'b1;
			tx_state_next = TX_WAIT_LSB;
		end
		TX_WAIT_LSB: begin
			if (tx_busy == 1'b0)
				tx_state_next = TX_SEND_MSB;
		end
		TX_SEND_MSB: begin
			tx_data = alu_out[15:8];
			tx_start = 1'b1;
			tx_state_next = TX_WAIT_MSB;
		end
		TX_WAIT_MSB: begin
			if (tx_busy == 1'b0)
				tx_state_next = TX_IDLE;
		end
		default:
			tx_state_next = TX_IDLE;
		endcase
	end

	always @(posedge clk) begin
		if (reset) begin
			tx_state <= TX_IDLE;
		end else begin
			tx_state <= tx_state_next;
		end
	end

endmodule
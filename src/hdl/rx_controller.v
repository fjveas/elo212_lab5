/*
 *
 */

`timescale 1ns / 1ps

module rx_controller
(
	input clk,
	input reset,

	input rx_ready,
	input [7:0] rx_data,

	output reg [15:0] alu_in1,
	output reg [15:0] alu_in2,
	output reg [2:0] alu_op,

	output reg send_result,
	output reg [2:0] rgb_state
);

	/* Machine states */
	localparam WAIT_OP1_LSB  = 'h1;
	localparam STORE_OP1_LSB = 'h2;
	localparam WAIT_OP1_MSB  = 'h3;
	localparam STORE_OP1_MSB = 'h4;
	localparam WAIT_OP2_LSB  = 'h5;
	localparam STORE_OP2_LSB = 'h6;
	localparam WAIT_OP2_MSB  = 'h7;
	localparam STORE_OP2_MSB = 'h8;
	localparam WAIT_COMMAND  = 'h9;
	localparam STORE_COMMAND = 'hA;
	localparam WAIT_RESULT   = 'hB;
	localparam START_TX_RES  = 'hC;

	reg [3:0] rx_state, rx_state_next;

	/* (Hi)gher and (Lo)wer parts of the ALU inputs */
	reg [7:0] alu_in1_hi, alu_in1_lo;
	reg [7:0] alu_in2_hi, alu_in2_lo;

	/* ALU operation */
	reg [2:0] alu_op_next;

	/* Machine state transitions */
	always @(*) begin
		rx_state_next = rx_state;

		case (rx_state)
		WAIT_OP1_LSB:
			if (rx_ready)
				rx_state_next = STORE_OP1_LSB;
		STORE_OP1_LSB:
			rx_state_next = WAIT_OP1_MSB;
		WAIT_OP1_MSB:
			if (rx_ready)
				rx_state_next = STORE_OP1_MSB;
		STORE_OP1_MSB:
			rx_state_next = WAIT_OP2_LSB;
		WAIT_OP2_LSB:
			if (rx_ready)
				rx_state_next = STORE_OP2_LSB;
		STORE_OP2_LSB:
			rx_state_next = WAIT_OP2_MSB;
		WAIT_OP2_MSB:
			if (rx_ready)
				rx_state_next = STORE_OP2_MSB;
		STORE_OP2_MSB:
			rx_state_next = WAIT_COMMAND;
		WAIT_COMMAND:
			if (rx_ready)
				rx_state_next = STORE_COMMAND;
		STORE_COMMAND:
			rx_state_next = WAIT_RESULT;
		WAIT_RESULT:
			rx_state_next = START_TX_RES;
		START_TX_RES:
			rx_state_next = WAIT_OP1_LSB;
		default:
			rx_state_next = WAIT_OP1_LSB;
		endcase
	end

	always @(posedge clk) begin
		if (reset) begin
			rx_state <= WAIT_OP1_LSB;
		end else begin
			rx_state <= rx_state_next;
		end
	end

	/*
	 * The signal 'send_result' is a pulse that last for one clock cycle
	 * and tells when the tx_controller should send the result
	 */
	always @(*) begin
		send_result = 1'b0;
		if (rx_state == START_TX_RES)
			send_result = 1'b1;
	end

	/* Update operands and operation depending on the current state */
	always @(*) begin
		/* Keep the previous value by default */
		{alu_in1_hi, alu_in1_lo} = alu_in1;
		{alu_in2_hi, alu_in2_lo} = alu_in2;
		alu_op_next = alu_op;

		/* Otherwise, update from rx_data when needed */
		case (rx_state)
		STORE_OP1_LSB:
			alu_in1_lo = rx_data;
		STORE_OP1_MSB:
			alu_in1_hi = rx_data;
		STORE_OP2_LSB:
			alu_in2_lo = rx_data;
		STORE_OP2_MSB:
			alu_in2_hi = rx_data;
		STORE_COMMAND:
			alu_op_next = rx_data[2:0];
		endcase
	end

	always @(posedge clk) begin
		if (reset) begin
			alu_in1 <= 'd0;
			alu_in2 <= 'd0;
			alu_op <= 'd0;
		end else begin
			alu_in1 <= {alu_in1_hi, alu_in1_lo};
			alu_in2 <= {alu_in2_hi, alu_in2_lo};
			alu_op <= alu_op_next;
		end
	end

	/* rgb_state tells which operand we are expecting */
	reg [2:0] rgb_state_next;

	always @(*) begin
		rgb_state_next = rgb_state;
		
		case (rx_state)
		WAIT_OP1_LSB:
			rgb_state_next = 'b001;
		WAIT_OP1_MSB:
			rgb_state_next = 'b011;
		WAIT_OP2_LSB:
			rgb_state_next = 'b010;
		WAIT_OP2_MSB:
			rgb_state_next = 'b110;
		WAIT_COMMAND:
			rgb_state_next = 'b100;
		endcase
	end

	always @(posedge clk)
		rgb_state <= rgb_state_next;

endmodule
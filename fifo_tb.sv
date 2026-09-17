

timeunit 1ns;
timeprecision 1ps;

module fifo_tb;

	localparam int DSIZE = 8;
	localparam int ASIZE = 4;
	localparam int DEPTH = 1 << ASIZE;

	logic [DSIZE-1:0] wdata;
	logic [DSIZE-1:0] rdata;
	logic             winc;
	logic             rinc;
	logic             wclk;
	logic             rclk;
	logic             wrst_n;
	logic             rrst_n;
	logic             wfull;
	logic             rempty;
	logic             almost_wfull;
	logic             almost_rempty;
	int               errors;

	fifo #(
		.DSIZE(DSIZE),
		.ASIZE(ASIZE)
	) dut (
		.rdata (rdata),
		.wfull (wfull),
		.rempty(rempty),
		.almost_wfull(almost_wfull),
		.almost_rempty(almost_rempty),
		.wdata (wdata),
		.winc  (winc),
		.wclk  (wclk),
		.wrst_n(wrst_n),
		.rinc  (rinc),
		.rclk  (rclk),
		.rrst_n(rrst_n)
	);

	initial begin
		wclk = 1'b0;
		forever #5 wclk = ~wclk;
	end

	initial begin
		rclk = 1'b0;
		forever #7 rclk = ~rclk;
	end

	task automatic check_flag(
		input logic actual,
		input logic expected,
		input string name
	);
		if (actual !== expected) begin
			$error("%s: expected %b, got %b at time %0t", name, expected, actual, $time);
			errors++;
		end
	endtask

	task automatic write_word(input logic [DSIZE-1:0] value);
		@(negedge wclk);
		wdata = value;
		winc = 1'b1;
		@(negedge wclk);
		winc = 1'b0;
	endtask

	task automatic read_word(input logic [DSIZE-1:0] expected);
		@(negedge rclk);
		rinc = 1'b1;
		#1;
		if (rdata !== expected) begin
			$error("read data: expected %h, got %h at time %0t", expected, rdata, $time);
			errors++;
		end
		@(negedge rclk);
		rinc = 1'b0;
	endtask

	task automatic attempt_read;
		@(negedge rclk);
		rinc = 1'b1;
		@(negedge rclk);
		rinc = 1'b0;
	endtask

	initial begin
		wdata = '0;
		winc = 1'b0;
		rinc = 1'b0;
		wrst_n = 1'b0;
		rrst_n = 1'b0;
		errors = 0;

		repeat (2) @(posedge wclk);
		repeat (2) @(posedge rclk);
		wrst_n = 1'b1;
		rrst_n = 1'b1;
		#1;
		check_flag(wfull, 1'b0, "wfull after reset");
		check_flag(rempty, 1'b1, "rempty after reset");

		for (int index = 0; index < DEPTH; index++) begin
			write_word(DSIZE'(index + 8'h10));
		end
		@(negedge wclk);
		check_flag(wfull, 1'b1, "wfull after filling FIFO");

		write_word(8'hff);
		check_flag(wfull, 1'b1, "wfull after blocked write");

		repeat (3) @(posedge rclk);
		for (int index = 0; index < DEPTH; index++) begin
			read_word(DSIZE'(index + 8'h10));
		end
		@(negedge rclk);
		check_flag(rempty, 1'b1, "rempty after draining FIFO");

		attempt_read();
		check_flag(rempty, 1'b1, "rempty after blocked read");

		if (errors == 0)
			$display("FIFO full/empty test PASSED");
		else
			$display("FIFO full/empty test FAILED with %0d errors", errors);
		$finish;
	end
	

    initial begin
        $fsdbDumpfile("novas.fsdb");
        $fsdbDumpvars(0, dut, "+mda");
    end
endmodule
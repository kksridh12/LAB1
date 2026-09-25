timeunit 1ns;
timeprecision 1ps;

module odd_even_tb;

	localparam int DSIZE = 8;
	localparam int ASIZE = 6;
	localparam int TOTAL_ITEMS = 160;

	logic [DSIZE-1:0] data_in;
	logic [DSIZE-1:0] data_out;
	logic             write_en;
	logic             read_en;
	logic             clock;
	logic             reset;

	int               errors;
	int               output_count;

	odd_even #(
		.DSIZE(DSIZE),
		.ASIZE(ASIZE),
		.ASYNC(0)
	) dut (
		.clock   (clock),
		.reset   (reset),
		.data_in (data_in),
		.write_en(write_en),
		.read_en (read_en),
		.data_out(data_out)
	);

	// 10 ns clock period
	initial begin
		clock = 1'b0;
		forever #5 clock = ~clock;
	end

	task automatic reset_design;
		data_in     = '0;
		write_en    = 1'b0;
		read_en     = 1'b0;
		reset       = 1'b0;
		errors      = 0;
		output_count = 0;
		repeat (3) @(posedge clock);
		reset = 1'b1;
		repeat (2) @(posedge clock);
	endtask

	// Check output data.
	// Since the input contains equal ordered even/odd streams,
	// the correct alternating output is 0,1,2,3,...159.
	task automatic check_output;
		if (data_out !== DSIZE'(output_count)) begin
			$error(
				"Output error: expected %h, got %h at time %0t",
				DSIZE'(output_count),
				data_out,
				$time
			);
			errors++;
		end
		output_count++;
	endtask

	// Generate input data as:
	//
	// 4 even values, then 4 odd values.
	//
	// Example:
	// 0,2,4,6, 1,3,5,7,
	// 8,10,12,14, 9,11,13,15, ...
	//
	// Each set of 80 values contains 40 even and 40 odd values,
	// but the input is not already alternating.
	task automatic set_input(input int item);
		int window;
		int position;
		int group;
		int base;
		window   = item / 80;
		position = item % 8;
		group    = (item % 80) / 8;
		base     = window * 80;
		if (position < 4)
			data_in = DSIZE'(
				base +
				(group * 8) +
				(position * 2)
			);
		else
			data_in = DSIZE'(
				base +
				(group * 8) +
				((position - 4) * 2) +
				1
			);
	endtask

	// Read requests occur on 8 out of every 10 cycles.
	// Run for a fixed number of cycles so simulation always ends.
	task automatic run_consumer;
		for (int cycle = 0; cycle < 300; cycle++) begin
			@(negedge clock);
			if ((cycle % 10) < 8)
				read_en = 1'b1;
			else
				read_en = 1'b0;
			#1;
			// Only check data when the DUT actually reads
			// one of the two FIFOs.
			if (dut.even_read_en || dut.odd_read_en) begin
				if (output_count < TOTAL_ITEMS)
					check_output();
			end
			@(posedge clock);
		end
		@(negedge clock);
		read_en = 1'b0;
	endtask

	// ============================================================
	// TEST 1:
	// FIFO depth document Case 9 - Case 4
	//
	// Cycles   0-19  : IDLE
	// Cycles  20-179 : WRITE
	// Cycles 180-199 : IDLE
	//
	// This produces:
	// 80 writes in the first 100 cycles
	// 80 writes in the second 100 cycles
	// ============================================================
	task automatic test_case4;
		int item;
		reset_design();
		item = 0;

		fork
			begin : producer
				for (int cycle = 0; cycle < 200; cycle++) begin
					@(negedge clock);
					if ((cycle >= 20) &&
					    (cycle < 180)) begin
						write_en = 1'b1;
						set_input(item);
						item++;
					end
					else begin
						write_en = 1'b0;
					end
					@(posedge clock);
				end
				@(negedge clock);
				write_en = 1'b0;
			end

			begin : consumer
				run_consumer();
			end
		join

		if (output_count != TOTAL_ITEMS) begin
			$error(
				"Expected %0d outputs, got %0d",
				TOTAL_ITEMS,
				output_count
			);
			errors++;
		end

		if (errors == 0)
			$display("TEST 1: Case 9 - Case 4 PASSED");
		else
			$display(
				"TEST 1: Case 9 - Case 4 FAILED with %0d errors",
				errors
			);
	endtask

	// ============================================================
	// TEST 2:
	// FIFO depth document Case 9 - Case 5
	//
	// Random-style idle cycles.
	// There are exactly 20 idle cycles and 80 write cycles
	// during each 100-cycle interval.
	// ============================================================
	task automatic test_case5;
		int item;
		int slot;
		logic idle_cycle;
		reset_design();
		item = 0;

		fork
			begin : producer
				for (int cycle = 0; cycle < 200; cycle++) begin
					@(negedge clock);
					slot = cycle % 100;
					// 20 irregular idle cycles per 100 cycles
					case (slot)
						3, 9, 14, 18, 27,
						31, 36, 44, 49, 53,
						61, 67, 72, 78, 83,
						87, 91, 94, 97, 99:
							idle_cycle = 1'b1;
						default:
							idle_cycle = 1'b0;
					endcase
					if (!idle_cycle) begin
						write_en = 1'b1;
						set_input(item);
						item++;
					end
					else begin
						write_en = 1'b0;
					end
					@(posedge clock);
				end
				@(negedge clock);
				write_en = 1'b0;
			end

			begin : consumer
				run_consumer();
			end
		join

		if (output_count != TOTAL_ITEMS) begin
			$error(
				"Expected %0d outputs, got %0d",
				TOTAL_ITEMS,
				output_count
			);
			errors++;
		end

		if (errors == 0)
			$display("TEST 2: Case 9 - Case 5 PASSED");
		else
			$display(
				"TEST 2: Case 9 - Case 5 FAILED with %0d errors",
				errors
			);
	endtask


	// ============================================================
	// Select testcase from command line
	// ============================================================
	string testname;

	initial begin

		if (!$value$plusargs("TEST=%s", testname))
			testname = "case4";

		case (testname)

			"case4": begin
				$fsdbDumpfile("test1_case4.fsdb");
				$fsdbDumpvars(0, "+mda");
				test_case4();
			end

			"case5": begin
				$fsdbDumpfile("test2_case5.fsdb");
				$fsdbDumpvars(0, "+mda");
				test_case5();
			end

			default: begin
				$display(
					"ERROR: Unknown testcase '%s'",
					testname
				);
				$display("Use:");
				$display("  +TEST=case4");
				$display("  +TEST=case5");
			end
		endcase
		$finish;
	end
endmodule
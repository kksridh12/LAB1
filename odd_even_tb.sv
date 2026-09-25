timeunit 1ns;
timeprecision 1ps;

module odd_even_tb;

	localparam int DSIZE = 8;
	localparam int ASIZE = 6;

	logic [DSIZE-1:0] data_in;
	logic [DSIZE-1:0] data_out;
	logic             write_en;
	logic             read_en;
	logic             clock;
	logic             reset;

	int               errors;
	int               output_count;

	// Expected output values
	logic [DSIZE-1:0] expected [0:79];


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


	task automatic write_value(
		input logic [DSIZE-1:0] value
	);
		@(negedge clock);
		data_in  = value;
		write_en = 1'b1;
		@(negedge clock);
		write_en = 1'b0;
	endtask


	task automatic check_output(
		input logic [DSIZE-1:0] expected_value
	);
		if (data_out !== expected_value) begin
			$error(
				"Output error: expected %h, got %h at time %0t",
				expected_value,
				data_out,
				$time
			);
			errors++;
		end
	endtask


	// ============================================================
	// TEST 1:
	// Even values arrive first, then odd values.
	// This creates a large buildup in the even FIFO.
	// ============================================================
	task automatic test_even_first;
		reset_design();

		// Expected alternating output:
		// 0,1,2,3,4,5,...,79
		for (int index = 0; index < 80; index++) begin
			expected[index] = DSIZE'(index);
		end


		fork

			// ----------------------------------------------------
			// PRODUCER
			// 80 writes during a 100-cycle window.
			//
			// First 40 values are even:
			// 0,2,4,...,78
			//
			// Then 40 values are odd:
			// 1,3,5,...,79
			// ----------------------------------------------------
			begin : producer

				// 40 even values
				for (int index = 0; index < 40; index++) begin
					@(negedge clock);
					data_in  = DSIZE'(index * 2);
					write_en = 1'b1;
					@(negedge clock);
					write_en = 1'b0;
				end

				// 40 odd values
				for (int index = 0; index < 40; index++) begin
					@(negedge clock);
					data_in  = DSIZE'((index * 2) + 1);
					write_en = 1'b1;
					@(negedge clock);
					write_en = 1'b0;
				end
			end

			// ----------------------------------------------------
			// CONSUMER
			// Request output data at 8 reads per 10 cycles.
			// ----------------------------------------------------
			begin : consumer

				// Give the design some time to receive data.
				repeat (5) @(posedge clock);
				while (output_count < 80) begin
					for (int cycle = 0; cycle < 10; cycle++) begin
						@(negedge clock);
						// Read on 8 of every 10 cycles.
						if ((cycle != 8) && (cycle != 9))
							read_en = 1'b1;
						else
							read_en = 1'b0;
						#1;
						// A valid alternating output occurs whenever
						// the DUT actually reads one of its FIFOs.
						if (dut.even_read_en || dut.odd_read_en) begin
							check_output(expected[output_count]);
							output_count++;
						end
                        @(posedge clock);
					end
				end

				@(negedge clock);
				read_en = 1'b0;
			end
		join

		if (output_count != 80) begin
			$error(
				"Expected 80 outputs, got %0d",
				output_count
			);
			errors++;
		end

		if (errors == 0)
			$display("TEST 1: Even-first input pattern PASSED");
		else
			$display(
				"TEST 1: Even-first input pattern FAILED with %0d errors",
				errors
			);

	endtask

	// ============================================================
	// TEST 2:
	// Odd values arrive first, then even values.
	// Opposite FIFO buildup from Test 1.
	// ============================================================
	task automatic test_odd_first;
		reset_design();

		for (int index = 0; index < 80; index++) begin
			expected[index] = DSIZE'(index);
		end

		fork

			// ----------------------------------------------------
			// PRODUCER
			// First 40 odd, then 40 even.
			// ----------------------------------------------------
			begin : producer
				for (int index = 0; index < 40; index++) begin
					@(negedge clock);
					data_in  = DSIZE'((index * 2) + 1);
					write_en = 1'b1;
					@(negedge clock);
					write_en = 1'b0;
				end
				for (int index = 0; index < 40; index++) begin
					@(negedge clock);
					data_in  = DSIZE'(index * 2);
					write_en = 1'b1;
					@(negedge clock);
					write_en = 1'b0;
				end
			end

			// ----------------------------------------------------
			// CONSUMER
			// 8 requested reads for every 10 cycles.
			// ----------------------------------------------------
			begin : consumer
				repeat (5) @(posedge clock);
				while (output_count < 80) begin
					for (int cycle = 0; cycle < 10; cycle++) begin
						@(negedge clock);
						if ((cycle != 8) && (cycle != 9))
							read_en = 1'b1;
						else
							read_en = 1'b0;
						#1;
						if (dut.even_read_en || dut.odd_read_en) begin
							check_output(expected[output_count]);
							output_count++;
						end
                        @(posedge clock);
					end
				end

				@(negedge clock);
				read_en = 1'b0;
			end
		join

		if (output_count != 80) begin
			$error(
				"Expected 80 outputs, got %0d",
				output_count
			);
			errors++;
		end

		if (errors == 0)
			$display("TEST 2: Odd-first input pattern PASSED");
		else
			$display(
				"TEST 2: Odd-first input pattern FAILED with %0d errors",
				errors
			);
	endtask


	// ============================================================
	// Select testcase from command line
	// ============================================================
	string testname;

	initial begin

		if (!$value$plusargs("TEST=%s", testname))
			testname = "even_first";

		case (testname)

			"even_first": begin
				$fsdbDumpfile("test1_even_first.fsdb");
				$fsdbDumpvars(0, "+mda");
				test_even_first();
			end

			"odd_first": begin
				$fsdbDumpfile("test2_odd_first.fsdb");
				$fsdbDumpvars(0, "+mda");
				test_odd_first();
			end

			default: begin
				$display("ERROR: Unknown testcase '%s'", testname);
				$display("Use:");
				$display("  +TEST=even_first");
				$display("  +TEST=odd_first");
			end
		endcase

		$finish;
	end
endmodule
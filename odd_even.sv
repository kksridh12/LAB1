
// Description - 


module odd_even #(parameter DSIZE = 8,
                  parameter ASIZE = 6,
                  parameter ASYNC = 0) (

    input  logic                clock,
    input  logic                reset,
    input  logic [DSIZE-1:0]    data_in,
    input  logic                write_en,
    input  logic                read_en,
    output logic [DSIZE-1:0]    data_out

);

   // Signals
   logic                 odd_write_en;
   logic                 odd_read_en;
   logic                 odd_wfull;
   logic                 odd_rempty;
   logic [DSIZE-1:0]     odd_rdata;
   logic [DSIZE-1:0]     odd_wdata;
   logic                 even_write_en;
   logic                 even_read_en;
   logic                 even_wfull;
   logic                 even_rempty;   
   logic [DSIZE-1:0]     even_rdata;
   logic [DSIZE-1:0]     even_wdata;

   logic                 odd_first_preflop;
   logic                 even_first_preflop;
   logic                 odd_first;
   logic                 even_first;

   typedef enum logic [1:0] { IDLE, EVEN, ODD, SPARE } STATE_TYPE;

   STATE_TYPE state, next_state;

   // Write logic
   always_comb begin
      case (data_in[0])
        1'b0 : begin even_wdata = data_in; even_write_en = write_en; odd_wdata = '0; odd_write_en = 1'b0; end
        1'b1 : begin odd_wdata  = data_in; odd_write_en  = write_en; even_wdata = '0; even_write_en = 1'b0; end
        default: begin 
            even_wdata = '0; even_write_en = 1'b0;
            odd_wdata  = '0; odd_write_en  = 1'b0;
        end
      endcase
   end

   // Odd FIFO 
   fifo #(DSIZE, ASIZE, ASYNC) u_odd_fifo  (.wclk(clock), .rclk(clock), 
                                            .rdata(odd_rdata), .wdata(odd_wdata),
                                            .wfull(odd_wfull), .rempty(odd_rempty),
                                            .winc(odd_write_en), .rinc(odd_read_en),
                                            .wrst_n(reset), .rrst_n(reset),
                                            .almost_wfull(), .almost_rempty());

   // Even FIFO
   fifo #(DSIZE, ASIZE, ASYNC) u_even_fifo (.wclk(clock), .rclk(clock), 
                                            .rdata(even_rdata), .wdata(even_wdata),
                                            .wfull(even_wfull), .rempty(even_rempty),
                                            .winc(even_write_en), .rinc(even_read_en),
                                            .wrst_n(reset), .rrst_n(reset),
                                            .almost_wfull(), .almost_rempty());

   // State machine for read
   always_ff @(posedge clock or negedge reset)
       if (!reset)                    state <= IDLE;
       else if (state != next_state)  state <= next_state;

   always_comb begin
       even_read_en = 1'b0;
       even_first_preflop = even_first;
       odd_first_preflop  = odd_first;
       odd_read_en = 1'b0;
       case (state) 
          IDLE:  begin 
                   next_state = IDLE;
                   if (even_rempty && odd_rempty) begin
                     if (even_write_en)     even_first_preflop = 1'b1;
                     else if (odd_write_en) odd_first_preflop  = 1'b1;
                   end 
                   else if (read_en & even_first) begin even_first_preflop = 1'b0; even_read_en = 1'b1; next_state = ODD; end
                   else if (read_en & odd_first)  begin even_first_preflop = 1'b0; odd_read_en  = 1'b1; next_state = EVEN; end
                 end
           EVEN: begin
                  odd_read_en = 1'b0;
                  if (read_en & !even_rempty) begin
                     if (!odd_rempty) begin
                        even_read_en = 1'b1; next_state = ODD;
                     end else begin
                        even_read_en = 1'b0; next_state = EVEN;
                     end
                  end else begin
                     even_read_en = 1'b0; next_state = EVEN;
                  end
                 end
           ODD:  begin
                  even_read_en = 1'b0;
                  if (read_en & !odd_rempty) begin
                     if (!even_rempty) begin
                        odd_read_en = 1'b1; next_state = EVEN;
                     end else begin
                        odd_read_en = 1'b0; next_state = ODD;
                     end
                  end else begin
                     odd_read_en = 1'b0; next_state = ODD;
                  end
                 end
           SPARE  : begin even_read_en = 1'b0; odd_read_en = 1'b0; next_state = IDLE; end
           default: begin even_read_en = 1'b0; odd_read_en = 1'b0; next_state = IDLE; end
       endcase
   end

   always_ff @( posedge clock or negedge reset )
      if (!reset)   {odd_first,even_first} <= 2'b0;
      else          {odd_first,even_first} <= {odd_first_preflop,even_first_preflop};
      
   logic [DSIZE-1:0]  data_out_shdw;
   always_ff @(posedge clock or negedge reset) 
      if (!reset)            data_out_shdw <= '0;
      else if (even_read_en) data_out_shdw <= even_rdata;
      else if (odd_read_en)  data_out_shdw <= odd_rdata;
      else                   data_out_shdw <= data_out;

   always_comb begin
      if      (even_read_en) data_out = even_rdata;
      else if (odd_read_en)  data_out = odd_rdata;
      else                   data_out = data_out_shdw;
   end
   
endmodule
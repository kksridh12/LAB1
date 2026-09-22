


module wptr_full #(parameter ADDRSIZE = 4)
 (
    output logic                wfull,
    output logic                almost_wfull,
    output logic [ADDRSIZE-1:0] waddr,
    output logic [ADDRSIZE :0]  wptr,
    input  logic [ADDRSIZE :0]  wq2_rptr,
    input  logic                winc, 
    input  logic                wclk, 
    input  logic                wrst_n);
    
    logic [ADDRSIZE:0] wbin;
    logic [ADDRSIZE:0] wbin_af;
    logic [ADDRSIZE:0] rptr_bin;
    logic [ADDRSIZE:0] wgraynext, wbinnext, wbin_af_next, wgray_af_next;
    logic              wfull_val;
    logic              almost_wfull_val;


    // ALMOST is when FIFO is 3/4 EMPTY.
    localparam logic [ADDRSIZE:0] ALMOST = (ADDRSIZE == 2) ? 1 : ((1 << ADDRSIZE) / 4);
    
    // GRAYSTYLE2 pointer
    always_ff @(posedge wclk or negedge wrst_n)
       if (!wrst_n) {wbin, wptr, wbin_af} <= 0;
       else         {wbin, wptr, wbin_af} <= {wbinnext, wgraynext, wbin_af_next};
    
    // Memory write-address pointer (okay to use binary to address memory)
    always_comb begin
        waddr     = wbin[ADDRSIZE-1:0];
        wbinnext  = wbin + (winc & ~wfull);
        wgraynext = (wbinnext>>1) ^ wbinnext;
        wbin_af_next = wbinnext + ALMOST;
        wgray_af_next = (wbin_af_next>>1) ^ wbin_af_next; 
    end
    
    always_comb 
    begin
        rptr_bin = '0;
        rptr_bin[ADDRSIZE] = wq2_rptr[ADDRSIZE];
        for (int i = ADDRSIZE - 1; i >= 0; i--) begin
            rptr_bin[i] = rptr_bin[i + 1] ^ wq2_rptr[i];
        end
    end

    always_comb begin
        wfull_val          = (wgraynext == {~wq2_rptr[ADDRSIZE:ADDRSIZE-1], wq2_rptr[ADDRSIZE-2:0]});
        almost_wfull_val   = (wgray_af_next >= {~wq2_rptr[ADDRSIZE:ADDRSIZE-1], wq2_rptr[ADDRSIZE-2:0]} && 
                              rptr_bin < ALMOST);
    end

    always_ff @(posedge wclk or negedge wrst_n)
       if (!wrst_n) {wfull, almost_wfull} <= {1'b0, 1'b0};
       else         {wfull, almost_wfull} <= {wfull_val, almost_wfull_val};

endmodule
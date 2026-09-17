


module wptr_full #(parameter ADDRSIZE = 4)
 (
    output logic                wfull,
    output logic                almost_wfull,
    output logic [ADDRSIZE-1:0] waddr,
    output logic [ADDRSIZE :0]  wptr,
    output logic [ADDRSIZE :0]  wptr_ae,
    input  logic [ADDRSIZE :0]  wq2_rptr_af,
    input  logic [ADDRSIZE :0]  wq2_rptr,
    input  logic                winc, 
    input  logic                wclk, 
    input  logic                wrst_n);
    
    logic [ADDRSIZE:0] wbin;
    logic [ADDRSIZE:0] wgraynext, wbinnext, wbin_ae_next, wgray_ae_next;
    logic              wfull_val;
    logic              almost_wfull_val;

    // ALMOST is when FIFO is 3/4 EMPTY.
    localparam logic [ADDRSIZE:0] ALMOST = (ADDRSIZE == 2) ? 1 : ((1 << ADDRSIZE) / 4);
    
    // GRAYSTYLE2 pointer
    always_ff @(posedge wclk or negedge wrst_n)
       if (!wrst_n) {wbin, wptr, wptr_ae} <= 0;
       else         {wbin, wptr, wptr_ae} <= {wbinnext, wgraynext, wgray_ae_next};
    
    // Memory write-address pointer (okay to use binary to address memory)
    always_comb begin
        waddr     = wbin[ADDRSIZE-1:0];
        wbinnext  = wbin + (winc & ~wfull);
        wgraynext = (wbinnext>>1) ^ wbinnext;
        wbin_ae_next = wbinnext - ALMOST;
        wgray_ae_next = (wbin_ae_next>>1) ^ wbin_ae_next; 
    end
    
    //------------------------------------------------------------------
    // Simplified version of the three necessary full-tests:
    // assign wfull_val=((wgnext[ADDRSIZE] !=wq2_rptr[ADDRSIZE] ) &&
    // (wgnext[ADDRSIZE-1] !=wq2_rptr[ADDRSIZE-1]) &&
    // (wgnext[ADDRSIZE-2:0]==wq2_rptr[ADDRSIZE-2:0]));
    //------------------------------------------------------------------
    always_comb begin
        wfull_val          = (wgraynext == {~wq2_rptr[ADDRSIZE:ADDRSIZE-1], wq2_rptr[ADDRSIZE-2:0]});
        almost_wfull_val   = winc & (wgraynext == {~wq2_rptr_af[ADDRSIZE:ADDRSIZE-1], wq2_rptr_af[ADDRSIZE-2:0]});
    end
    always_ff @(posedge wclk or negedge wrst_n)
       if (!wrst_n) {wfull, almost_wfull} <= {1'b0, 1'b0};
       else         {wfull, almost_wfull} <= {wfull_val, almost_wfull_val};

endmodule
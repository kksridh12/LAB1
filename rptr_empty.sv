


module rptr_empty #(parameter ADDRSIZE = 4)
(
    output logic                rempty,
    output logic                almost_rempty,
    output logic [ADDRSIZE-1:0] raddr,
    output logic [ADDRSIZE :0]  rptr,
    input  logic [ADDRSIZE :0]  rq2_wptr,
    input  logic                rinc,
    input  logic                rclk,
    input  logic                rrst_n);
    
    logic [ADDRSIZE:0] rbin;
    logic [ADDRSIZE:0] wptr_bin;
    logic [ADDRSIZE:0] rbin_ae;
    logic [ADDRSIZE:0] rgraynext, rbinnext, rbin_ae_next, rgray_ae_next;
    logic rempty_val;
    logic almost_rempty_val;
    
    // ALMOST is when FIFO is 3/4 FULL.
    localparam logic [ADDRSIZE:0] ALMOST = (ADDRSIZE == 2) ? 1 : ((1 << ADDRSIZE) / 4);
    //-------------------
    // GRAYSTYLE2 pointer
    //-------------------
    always_ff @(posedge rclk or negedge rrst_n)
       if (!rrst_n) {rbin, rptr, rbin_ae} <= 0;
       else         {rbin, rptr, rbin_ae} <= {rbinnext, rgraynext, rbin_ae_next};
    
    // Memory read-address pointer (okay to use binary to address memory)
    always_comb begin
        raddr     = rbin[ADDRSIZE-1:0];
        rbinnext  = rbin + (rinc & ~rempty);
        rbin_ae_next = rbinnext + ALMOST;
        rgraynext = (rbinnext>>1) ^ rbinnext;
        rgray_ae_next = (rbin_ae_next>>1) ^ rbin_ae_next;
    end
    
    always_comb 
    begin
        wptr_bin = '0;
        wptr_bin[ADDRSIZE] = rq2_wptr[ADDRSIZE];
        for (int i = ADDRSIZE - 1; i >= 0; i--) begin
            wptr_bin[i] = wptr_bin[i + 1] ^ rq2_wptr[i];
        end
    end
    //---------------------------------------------------------------
    // FIFO empty when the next rptr == synchronized wptr or on reset
    //---------------------------------------------------------------
    always_comb begin
        rempty_val        = (rgraynext == rq2_wptr);
        almost_rempty_val = ((rgray_ae_next >= rq2_wptr) && (rgraynext != 0)) || (wptr_bin < ALMOST);
    end

    always_ff @(posedge rclk or negedge rrst_n)
       if (!rrst_n) {rempty, almost_rempty} <= {1'b1, 1'b1};
       else         {rempty, almost_rempty} <= {rempty_val, almost_rempty_val};

endmodule



module rptr_empty #(parameter ADDRSIZE = 4)
(
    output logic                rempty,
    output logic                almost_rempty,
    output logic [ADDRSIZE-1:0] raddr,
    output logic [ADDRSIZE :0]  rptr,
    output logic [ADDRSIZE :0]  rptr_ae,
    input  logic [ADDRSIZE :0]  rq2_wptr,
    input  logic [ADDRSIZE :0]  rq2_wptr_ae,
    input  logic                rinc,
    input  logic                rclk,
    input  logic                rrst_n);
    
    logic [ADDRSIZE:0] rbin;
    logic [ADDRSIZE:0] rgraynext, rbinnext, rbin_ae_next, rgray_ae_next;
    logic rempty_val;
    logic almost_rempty_val;
    
    // ALMOST EMPTY is when FIFO is 1/4 empty.
    localparam logic [ADDRSIZE:0] ALMOST_EMPTY = (ADDRSIZE == 2) ? 1 : ((1 << ADDRSIZE) / 4);
    //-------------------
    // GRAYSTYLE2 pointer
    //-------------------
    always_ff @(posedge rclk or negedge rrst_n)
       if (!rrst_n) {rbin, rptr, rptr_ae} <= 0;
       else {rbin, rptr, rptr_ae} <= {rbinnext, rgraynext, rgray_ae_next};
    
    // Memory read-address pointer (okay to use binary to address memory)
    always_comb begin
        raddr     = rbin[ADDRSIZE-1:0];
        rbinnext  = rbin + (rinc & ~rempty);
        rbin_ae_next = rbinnext - ALMOST_EMPTY;
        rgraynext = (rbinnext>>1) ^ rbinnext;
        rgray_ae_next = (rbin_ae_next>>1) ^ rbin_ae_next;
    end
    
    //---------------------------------------------------------------
    // FIFO empty when the next rptr == synchronized wptr or on reset
    //---------------------------------------------------------------
    always_comb begin
        rempty_val        = (rgraynext == rq2_wptr);
        almost_rempty_val = rinc && !rempty_val && (rgraynext == rq2_wptr_ae);
    end
        

    
    always_ff @(posedge rclk or negedge rrst_n)
       if (!rrst_n) {rempty, almost_rempty} <= {1'b1, 1'b0};
       else         {rempty, almost_rempty} <= {rempty_val, almost_rempty_val};

endmodule
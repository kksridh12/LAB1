


module rptr_empty #(parameter ADDRSIZE = 4)
(
    output logic                rempty,
    output logic [ADDRSIZE-1:0] raddr,
    output logic [ADDRSIZE :0]  rptr,
    input  logic [ADDRSIZE :0]  rq2_wptr,
    input  logic                rinc,
    input  logic                rclk,
    input  logic                rrst_n);
    
    logic [ADDRSIZE:0] rbin;
    logic [ADDRSIZE:0] rgraynext, rbinnext;
    logic rempty_val;
    
    //-------------------
    // GRAYSTYLE2 pointer
    //-------------------
    always_ff @(posedge rclk or negedge rrst_n)
       if (!rrst_n) {rbin, rptr} <= 0;
       else {rbin, rptr} <= {rbinnext, rgraynext};
    
    // Memory read-address pointer (okay to use binary to address memory)
    always_comb begin
        raddr     = rbin[ADDRSIZE-1:0];
        rbinnext  = rbin + (rinc & ~rempty);
        rgraynext = (rbinnext>>1) ^ rbinnext;
    end
    
    //---------------------------------------------------------------
    // FIFO empty when the next rptr == synchronized wptr or on reset
    //---------------------------------------------------------------
    always_comb
        rempty_val = (rgraynext == rq2_wptr);
    
    always_ff @(posedge rclk or negedge rrst_n)
       if (!rrst_n) rempty <= 1'b1;
       else rempty <= rempty_val;

endmodule
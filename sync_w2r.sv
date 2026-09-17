


module sync_w2r #(parameter ADDRSIZE = 4)
 (
    output logic [ADDRSIZE:0] rq2_wptr,
    output logic [ADDRSIZE:0] rq2_wptr_ae,
    input  logic [ADDRSIZE:0] wptr,
    input  logic [ADDRSIZE:0] wptr_ae,
    input  logic              rclk,
    input  logic              rrst_n);
    
    logic [ADDRSIZE:0] rq1_wptr;
    logic [ADDRSIZE:0] rq1_wptr_ae;
    
    always_ff @(posedge rclk or negedge rrst_n)
       if (!rrst_n) {rq2_wptr,rq1_wptr} <= 0;
       else         {rq2_wptr,rq1_wptr} <= {rq1_wptr,wptr};

    always_ff @(posedge rclk or negedge rrst_n)
       if (!rrst_n) {rq2_wptr_ae,rq1_wptr_ae} <= 0;
       else         {rq2_wptr_ae,rq1_wptr_ae} <= {rq1_wptr_ae,wptr_ae};

endmodule
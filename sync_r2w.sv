


module sync_r2w #(parameter ADDRSIZE = 4)
(
    output logic [ADDRSIZE:0] wq2_rptr,
    output logic [ADDRSIZE:0] wq2_rptr_af,
    input  logic [ADDRSIZE:0] rptr,
    input  logic [ADDRSIZE:0] rptr_af,
    input  logic              wclk,
    input  logic              wrst_n);
    
    logic [ADDRSIZE:0] wq1_rptr;
    logic [ADDRSIZE:0] wq1_rptr_af;
    
    always_ff @(posedge wclk or negedge wrst_n)
       if (!wrst_n) {wq2_rptr,wq1_rptr} <= 0;
       else         {wq2_rptr,wq1_rptr} <= {wq1_rptr,rptr};

    always_ff @(posedge wclk or negedge wrst_n)
       if (!wrst_n) {wq2_rptr_af,wq1_rptr_af} <= 0;
       else         {wq2_rptr_af,wq1_rptr_af} <= {wq1_rptr_af,rptr_af};
endmodule
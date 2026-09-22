
interface mem_itf #(
    parameter DSIZE = 8,
    parameter ASIZE = 4
)
(); 
    logic [DSIZE-1:0]    rdata;
    logic [ASIZE-1:0]    waddr;
    logic [ASIZE-1:0]    raddr;
    logic                wfull;
    logic [DSIZE-1:0]    wdata;
    logic                winc;
    logic                wclk;
    logic                wrst_n;

    modport mem_witf (
        output            wfull,
        input             wdata,
        input             waddr,
        input             winc,
        input             wclk
    );

    modport mem_ritf (
        output            rdata,
        input             raddr
    );

endinterface

module fifo  #(parameter DSIZE = 8,
               parameter ASIZE = 4)
 (
    output logic [DSIZE-1:0]    rdata,
    output logic                wfull,
    output logic                almost_wfull,
    output logic                rempty,
    output logic                almost_rempty,
    input  logic [DSIZE-1:0]    wdata,
    input  logic                winc,
    input  logic                wclk,
    input  logic                wrst_n,
    input  logic                rinc,
    input  logic                rclk,
    input  logic                rrst_n);
    
    logic [ASIZE-1:0] waddr, raddr;
    logic [ASIZE:0]   wptr, rptr, wq2_rptr, rq2_wptr;
    
    //sync_r2w sync_r2w (.wq2_rptr(wq2_rptr), .rptr(rptr),
    //.wclk(wclk), .wrst_n(wrst_n));
    sync_r2w #(ASIZE) u_sync_r2w (.*);
    sync_w2r #(ASIZE) u_sync_w2r (.*);
    //sync_w2r sync_w2r (.rq2_wptr(rq2_wptr), .wptr(wptr),
    //.rclk(rclk), .rrst_n(rrst_n));
   
    mem_itf #(DSIZE, ASIZE) mem_if ();

    assign mem_if.wdata = wdata;
    assign mem_if.winc  = winc;
    assign mem_if.wclk  = wclk;
    assign wfull        = mem_if.wfull;
    assign rdata        = mem_if.rdata;

    fifomem #(DSIZE, ASIZE) u_fifomem (.mem_witf(mem_if.mem_witf), .mem_ritf(mem_if.mem_ritf));
    //fifomem #(DSIZE, ASIZE) fifomem
    //(.rdata(rdata), .wdata(wdata),
    //.waddr(waddr), .raddr(raddr),
    //.wclken(winc), .wfull(wfull),
    //.wclk(wclk));
    
    rptr_empty #(ASIZE) u_rptr_empty (.raddr (mem_if.raddr), .*);
    //rptr_empty #(ASIZE) rptr_empty
    //(.rempty(rempty),
    //.raddr(raddr),
    //.rptr(rptr), .rq2_wptr(rq2_wptr),
    //.rinc(rinc), .rclk(rclk),
    //.rrst_n(rrst_n));
    
    wptr_full #(ASIZE) u_wptr_full ( 
        .waddr (mem_if.waddr),
        .wfull (mem_if.wfull),
        .winc (mem_if.winc), 
        .wclk (mem_if.wclk),
        .*);
    //wptr_full #(ASIZE) wptr_full
    //(.wfull(wfull), .waddr(waddr),
    //.wptr(wptr), .wq2_rptr(wq2_rptr),
    //.winc(winc), .wclk(wclk),
    //.wrst_n(wrst_n));
endmodule
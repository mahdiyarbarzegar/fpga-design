`include "axi4lite_master_model.svh"

class axi4lite_master_model #(
    parameter int AXI_DATA_WIDTH,
    parameter int AXI_ADDR_WIDTH
);
    localparam int STRB_WIDTH = AXI_DATA_WIDTH / 8;
    localparam int TIMEOUT_CYCLES = 100;

    virtual axi4lite_bus_ifc #(
        .AXI_DATA_WIDTH(AXI_DATA_WIDTH),
        .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH)
    ).MASTER vif;

    function new(virtual axi4lite_bus_ifc #(
                 .AXI_DATA_WIDTH(AXI_DATA_WIDTH),
                 .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH)
                 ).MASTER vif);
        this.vif = vif;
    endfunction

    task reset_signals();
        vif.AWADDR  = '0;
        vif.AWPROT  = '0;
        vif.AWVALID = 1'b0;
        vif.WDATA   = '0;
        vif.WSTRB   = '0;
        vif.WVALID  = 1'b0;
        vif.BREADY  = 1'b0;
        vif.ARADDR  = '0;
        vif.ARPROT  = '0;
        vif.ARVALID = 1'b0;
        vif.RREADY  = 1'b0;
    endtask

    task write(input logic [AXI_ADDR_WIDTH-1:0] addr, input logic [AXI_DATA_WIDTH-1:0] data,
               input logic [STRB_WIDTH-1:0] strb, input axi4lite_write_mode_t mode = AW_THEN_W,
               output logic [1:0] resp, output axi4lite_result_t result);
        axi4lite_result_t aw_result, w_result, b_result;

        resp   = 2'bxx;
        result = AXI_TIMEOUT;

        case (mode)
            AW_THEN_W: begin
                send_aw(addr, aw_result);
                if (aw_result != AXI_SUCCESS) return;

                send_w(data, strb, w_result);
                if (w_result != AXI_SUCCESS) return;
            end
            W_THEN_AW: begin
                send_w(data, strb, w_result);
                if (w_result != AXI_SUCCESS) return;

                send_aw(addr, aw_result);
                if (aw_result != AXI_SUCCESS) return;
            end
            AW_AND_W: begin
                fork
                    send_aw(addr, aw_result);
                    send_w(data, strb, w_result);
                join

                if (aw_result != AXI_SUCCESS || w_result != AXI_SUCCESS) return;
            end
        endcase

        get_b(resp, b_result);
        if (b_result != AXI_SUCCESS) return;

        result = AXI_SUCCESS;
    endtask

    task read(input logic [AXI_ADDR_WIDTH-1:0] addr, output logic [AXI_DATA_WIDTH-1:0] data,
              output logic [1:0] resp, output axi4lite_result_t result);
        axi4lite_result_t ar_result, r_result;

        resp   = 2'bxx;
        result = AXI_TIMEOUT;

        send_ar(addr, ar_result);
        if (ar_result != AXI_SUCCESS) return;

        get_r(data, resp, r_result);
        if (r_result != AXI_SUCCESS) return;

        result = AXI_SUCCESS;
    endtask

    task send_aw(input logic [AXI_ADDR_WIDTH-1:0] addr, output axi4lite_result_t result);
        vif.AWADDR  = addr;
        vif.AWPROT  = 3'b000;
        vif.AWVALID = 1'b1;

        for (int cycles = 0; cycles < TIMEOUT_CYCLES; cycles = cycles + 1) begin
            @(posedge vif.ACLK);
            if (vif.AWREADY) begin
                vif.AWVALID = 1'b0;
                result      = AXI_SUCCESS;
                return;
            end
        end

        vif.AWVALID = 1'b0;
        result      = AXI_TIMEOUT;

        $error("AXI4-Lite AW channel timeout: addr=0x%0h after %0d cycles", addr, TIMEOUT_CYCLES);
    endtask

    task send_w(input logic [AXI_DATA_WIDTH-1:0] data, input logic [STRB_WIDTH-1:0] strb,
                output axi4lite_result_t result);
        vif.WDATA  = data;
        vif.WSTRB  = strb;
        vif.WVALID = 1'b1;

        for (int cycles = 0; cycles < TIMEOUT_CYCLES; cycles = cycles + 1) begin
            @(posedge vif.ACLK);
            if (vif.WREADY) begin
                vif.WVALID = 1'b0;
                result     = AXI_SUCCESS;
                return;
            end
        end

        vif.WVALID = 1'b0;
        result     = AXI_TIMEOUT;

        $error("AXI4-Lite W channel timeout: data=0x%0h, strb=0x%0h after %0d cycles", data, strb,
               TIMEOUT_CYCLES);
    endtask

    task get_b(output logic [1:0] resp, output axi4lite_result_t result);
        vif.BREADY = 1'b1;

        for (int cycles = 0; cycles < TIMEOUT_CYCLES; cycles = cycles + 1) begin
            @(posedge vif.ACLK);
            if (vif.BVALID) begin
                resp   = vif.BRESP;
                result = AXI_SUCCESS;
                return;
            end
        end

        vif.BREADY = 1'b0;
        resp       = 2'bxx;
        result     = AXI_TIMEOUT;

        $error("AXI4-Lite B channel timeout after %0d cycles", TIMEOUT_CYCLES);
    endtask

    task send_ar(input logic [AXI_ADDR_WIDTH-1:0] addr, output axi4lite_result_t result);
        vif.ARADDR  = addr;
        vif.ARPROT  = 3'b000;
        vif.ARVALID = 1'b1;

        for (int cycles = 0; cycles < TIMEOUT_CYCLES; cycles = cycles + 1) begin
            @(posedge vif.ACLK);
            if (vif.ARREADY) begin
                vif.ARVALID = 1'b0;
                result      = AXI_SUCCESS;
                return;
            end
        end

        vif.ARVALID = 1'b0;
        result      = AXI_TIMEOUT;

        $error("AXI4-Lite AR channel timeout: addr=0x%0h after %0d cycles", addr, TIMEOUT_CYCLES);
    endtask

    task get_r(output logic [AXI_DATA_WIDTH-1:0] data, output logic [1:0] resp,
               output axi4lite_result_t result);
        vif.RREADY = 1'b1;

        for (int cycles = 0; cycles < TIMEOUT_CYCLES; cycles = cycles + 1) begin
            @(posedge vif.ACLK);
            if (vif.RVALID) begin
                data       = vif.RDATA;
                resp       = vif.RRESP;
                vif.RREADY = 1'b0;
                result     = AXI_SUCCESS;
                return;
            end
        end
        do begin
            @(posedge vif.ACLK);
        end while (!vif.RVALID);

        vif.RREADY = 1'b0;
        data       = 'x;
        resp       = 2'bxx;
        result     = AXI_TIMEOUT;

        $error("AXI4-Lite R channel timeout after %0d cycles", TIMEOUT_CYCLES);
    endtask

endclass

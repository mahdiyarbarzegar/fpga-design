import axi4lite_reg_pkg::*;

module axi4_reg_bank #(
    parameter int        AXI_DATA_WIDTH,
    parameter int        AXI_ADDR_WIDTH,
    parameter int        NUM_REGS,
    parameter type       REG_DESC_T,
    parameter REG_DESC_T REG_MAP       [NUM_REGS] = '{default: '0}
) (
    input logic clk,
    input logic rst_n,

    axi4_reg_ifc.STORAGE reg_ifc_axi,
    axi4_reg_ifc.STORAGE reg_ifc_rtl
);

    initial begin
        assert (reg_ifc_rtl.CHANNELS == reg_ifc_rtl.NUM_REGS)
        else $error("The CHANNELS and NUM_REGS for the RTL-Register-Interface should be equal!");
    end

    localparam int STRB_WIDTH = AXI_DATA_WIDTH / 8;
    localparam int ADDR_LSB = $clog2(AXI_DATA_WIDTH / 8);
    localparam int INDEX_WIDTH = AXI_ADDR_WIDTH - ADDR_LSB;

    logic [AXI_DATA_WIDTH-1:0] regs[NUM_REGS];

    assign reg_ifc_rtl.regs = regs;

    genvar i;
    generate
        for (i = 0; i < NUM_REGS; i = i + 1) begin : i_reg

            assign reg_ifc_axi.regs[i] = (REG_MAP[i].access == REG_ACCESS_RW || REG_MAP[i].access == REG_ACCESS_R) ? regs[i] : '1;

            always_ff @(posedge clk) begin
                if (rst_n == 0) begin
                    regs[i] <= REG_MAP[i].def;
                end else begin
                    if (reg_ifc_rtl.wr_en[i]) begin
                        for (int b = 0; b < STRB_WIDTH; b++) begin
                            if (reg_ifc_rtl.wr_strb[i][b]) begin
                                regs[i][b*8+:8] <= reg_ifc_rtl.wr_data[i][b*8+:8];
                            end
                        end
                    end else if (reg_ifc_axi.wr_en[0] && reg_ifc_axi.wr_inx[0] == i) begin
                        if (REG_MAP[reg_ifc_axi.wr_inx[0]].access == REG_ACCESS_RW || REG_MAP[reg_ifc_axi.wr_inx[0]].access == REG_ACCESS_W) begin
                            for (int b = 0; b < STRB_WIDTH; b++) begin
                                if (reg_ifc_axi.wr_strb[0][b]) begin
                                    regs[i][b*8+:8] <= reg_ifc_axi.wr_data[0][b*8+:8];
                                end
                            end
                        end
                    end
                end
            end

        end
    endgenerate

endmodule : axi4_reg_bank

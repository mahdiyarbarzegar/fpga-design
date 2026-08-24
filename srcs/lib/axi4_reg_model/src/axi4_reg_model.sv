module axi4_reg_model #(
    parameter int DATA_WIDTH,
    parameter int ADDR_WIDTH
) (
    input logic clk,
    input logic rst_n,

    axi4_reg_ifc.STORAGE reg_ifc
);

    localparam int STRB_WIDTH = DATA_WIDTH / 8;
    localparam int ADDR_LSB = (DATA_WIDTH / 32) + 1;
    localparam int REG_ADDR_WIDTH = ADDR_WIDTH - ADDR_LSB;
    localparam int NUMBER_OF_REGS = 2 ** REG_ADDR_WIDTH;

    logic [DATA_WIDTH-1:0] regs[NUMBER_OF_REGS];

    task automatic write_reg(input logic [REG_ADDR_WIDTH-1:0] addr,
                             input logic [DATA_WIDTH-1:0] data, input logic [STRB_WIDTH-1:0] strb);
        for (int i = 0; i < STRB_WIDTH; i++) begin
            if (strb[i]) begin
                regs[addr][i*8+:8] <= data[i*8+:8];
            end
        end
    endtask

    assign reg_ifc.regs = regs;

    genvar i;
    generate
        for (i = 0; i < reg_ifc.NUM_REGS; i++) begin : i_reg
            always_ff @(posedge clk) begin
                if (!rst_n) begin
                    regs[i] <= '0;
                end
            end
        end
    endgenerate

    genvar g;
    for (g = 0; g < reg_ifc.CHANNELS; g++) begin : g_reg
        always_ff @(posedge clk) begin
            if (rst_n) begin
                if (reg_ifc.wr_en[g]) begin
                    write_reg(reg_ifc.wr_inx[g], reg_ifc.wr_data[g], reg_ifc.wr_strb[g]);
                end
            end
        end
    end
    generate
    endgenerate

endmodule : axi4_reg_model

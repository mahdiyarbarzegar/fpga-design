`ifndef AXI4LITE_MASTER_MASTER_SVH
`define AXI4LITE_MASTER_MASTER_SVH

typedef enum {
    AXI_SUCCESS,
    AXI_TIMEOUT
} axi4lite_result_t;

typedef enum {
    AW_THEN_W,
    W_THEN_AW,
    AW_AND_W
} axi4lite_write_mode_t;

`endif

package axi4lite_reg_pkg;

    typedef enum logic [1:0] {
        REG_ACCESS_RW = 2'b00,
        REG_ACCESS_R  = 2'b01,
        REG_ACCESS_W  = 2'b10
    } reg_access_t;

    `define DECLARE_REG_DESC_T(NAME, AW, DW) \
    typedef struct packed { \
        logic [AW-1:0] addr; \
        logic [DW-1:0] def; \
        reg_access_t   access; \
    } NAME;

endpackage

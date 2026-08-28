package pwm_gen_reg_pkg;

    `include "pwm_gen.vh"

    import axi4lite_reg_pkg::*;

    localparam int AXI_STRB_WIDTH = AXI_DATA_WIDTH / 8;

    `DECLARE_REG_DESC_T(pwm_reg_desc_t, AXI_ADDR_WIDTH, AXI_DATA_WIDTH)

    typedef enum int unsigned {
        REG_START                = 0,
        REG_STOP,
        REG_MODE,
        REG_PRESCALER,
        REG_AUTO_RELOAD_REGISTER,
        REG_CCR_CH,
        REG_CCR_VALUE_RB,
        REG_CCR_VALUE_W,

        NUM_REGS
    } pwm_reg_id_t;

    localparam pwm_reg_desc_t PWM_GEN_REGMAP[NUM_REGS] = '{
        REG_START: '{addr: 'h0, def: 'h0, access : REG_ACCESS_W},
        REG_STOP: '{addr: 'h4, def: 'h0, access : REG_ACCESS_RW},
        REG_MODE: '{addr: 'h8, def: 'h0, access : REG_ACCESS_RW},
        REG_PRESCALER: '{addr: 'hC, def: 'h0, access : REG_ACCESS_RW},
        REG_AUTO_RELOAD_REGISTER: '{addr: 'h10, def: 'h0, access : REG_ACCESS_RW},
        REG_CCR_CH: '{addr: 'h14, def: 'h0, access : REG_ACCESS_RW},
        REG_CCR_VALUE_RB: '{addr: 'h18, def: 'h0, access : REG_ACCESS_R},
        REG_CCR_VALUE_W: '{addr: 'h1C, def: '1, access : REG_ACCESS_W}
    };
endpackage

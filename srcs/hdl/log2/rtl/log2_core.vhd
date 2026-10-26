library ieee;
use ieee.std_logic_1164.all;

entity log2_core is
    generic(
        STRATEGY: string;
        USE_DSP: boolean;
        INPUT_DATA_WIDTH: positive;
        INPUT_FRACTION_WIDTH: positive;
        OUTPUT_DATA_WIDTH: positive;
        OUTPUT_FRACTION_WIDTH: positive;
        LUT_ADDR_SIZE: positive;
        USE_CLOCK_EN: boolean := false
    );
    port(
        clk: in std_logic;
        rst_n: in std_logic;
        ce: in std_logic;

        data_i: in std_logic_vector(INPUT_DATA_WIDTH - 1 downto 0);
        data_o: out std_logic_vector(OUTPUT_DATA_WIDTH - 1 downto 0);

        valid_i: in std_logic;
        valid_o: out std_logic
    );
end entity;

architecture core of log2_core is
begin

    log2_lut: if STRATEGY = "LUT" generate
        log2_lut: entity work.log2_fp_lut_core
            generic map(
                INPUT_DATA_WIDTH => INPUT_DATA_WIDTH,
                INPUT_FRACTION_WIDTH => INPUT_FRACTION_WIDTH,
                OUTPUT_DATA_WIDTH => OUTPUT_DATA_WIDTH,
                OUTPUT_FRACTION_WIDTH => OUTPUT_FRACTION_WIDTH,
                LUT_ADDR_SIZE => LUT_ADDR_SIZE,
                USE_CLOCK_EN => USE_CLOCK_EN
            )
            port map(
                clk => clk,
                rst_n => rst_n,
                ce => ce,
                data_i => data_i,
                data_o => data_o,
                valid_i => valid_i,
                valid_o => valid_o
            );
        end generate;

    log2_lut_lintrpl: if STRATEGY = "LUT_LINEAR_INTRPL" generate

        log2_lut_lintrpl_dsp: if USE_DSP = true generate
            log2_lut_lintrpl: entity work.log2_fp_lut_lintrpl_core(rtl_dsp)
                generic map(
                    INPUT_DATA_WIDTH => INPUT_DATA_WIDTH,
                    INPUT_FRACTION_WIDTH => INPUT_FRACTION_WIDTH,
                    OUTPUT_DATA_WIDTH => OUTPUT_DATA_WIDTH,
                    OUTPUT_FRACTION_WIDTH => OUTPUT_FRACTION_WIDTH,
                    LUT_ADDR_SIZE => LUT_ADDR_SIZE,
                    USE_CLOCK_EN => USE_CLOCK_EN
                )
                port map(
                    clk => clk,
                    rst_n => rst_n,
                    ce => ce,
                    data_i => data_i,
                    data_o => data_o,
                    valid_i => valid_i,
                    valid_o => valid_o
                );
            end generate;

            log2_lut_lintrpl_lut: if USE_DSP = false generate
                log2_lut_lintrpl: entity work.log2_fp_lut_lintrpl_core(rtl_lut)
                    generic map(
                        INPUT_DATA_WIDTH => INPUT_DATA_WIDTH,
                        INPUT_FRACTION_WIDTH => INPUT_FRACTION_WIDTH,
                        OUTPUT_DATA_WIDTH => OUTPUT_DATA_WIDTH,
                        OUTPUT_FRACTION_WIDTH => OUTPUT_FRACTION_WIDTH,
                        LUT_ADDR_SIZE => LUT_ADDR_SIZE,
                        USE_CLOCK_EN => USE_CLOCK_EN
                    )
                    port map(
                        clk => clk,
                        rst_n => rst_n,
                        ce => ce,
                        data_i => data_i,
                        data_o => data_o,
                        valid_i => valid_i,
                        valid_o => valid_o
                    );
                end generate;

        end generate;

end core;
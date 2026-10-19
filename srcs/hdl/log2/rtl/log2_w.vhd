library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity log2_w is
    generic(
        STRATEGY: string;
        INPUT_DATA_WIDTH: positive;
        INPUT_FRACTION_WIDTH: positive;
        OUTPUT_DATA_WIDTH: positive;
        OUTPUT_FRACTION_WIDTH: positive;
        LUT_ADDR_SIZE: positive
    );
    port(
        clk: in std_logic;
        rst_n: in std_logic;

        data_i: in std_logic_vector(INPUT_DATA_WIDTH - 1 downto 0);
        data_o: out std_logic_vector(OUTPUT_DATA_WIDTH - 1 downto 0);

        valid_i: in std_logic;
        valid_o: out std_logic
    );
end entity;

architecture lut_based of log2_w is

    component log2_fp_lut_core is
        generic(
            INPUT_DATA_WIDTH: positive;
            INPUT_FRACTION_WIDTH: positive;
            OUTPUT_DATA_WIDTH: positive;
            OUTPUT_FRACTION_WIDTH: positive;
            LUT_ADDR_SIZE: positive
        );
        port(
            clk: in std_logic;
            rst_n: in std_logic;

            data_i: in std_logic_vector(INPUT_DATA_WIDTH - 1 downto 0);
            data_o: out std_logic_vector(OUTPUT_DATA_WIDTH - 1 downto 0);

            valid_i: in std_logic;
            valid_o: out std_logic
        );
    end component;

    component log2_fp_lut_lintrpl_core is
        generic(
            INPUT_DATA_WIDTH: positive;
            INPUT_FRACTION_WIDTH: positive;
            OUTPUT_DATA_WIDTH: positive;
            OUTPUT_FRACTION_WIDTH: positive;
            LUT_ADDR_SIZE: positive
        );
        port(
            clk: in std_logic;
            rst_n: in std_logic;

            data_i: in std_logic_vector(INPUT_DATA_WIDTH - 1 downto 0);
            data_o: out std_logic_vector(OUTPUT_DATA_WIDTH - 1 downto 0);

            valid_i: in std_logic;
            valid_o: out std_logic
        );
    end component;

begin

    log2_lut: if STRATEGY = "LUT" generate
        log2_lut: log2_fp_lut_core
            generic map(
                INPUT_DATA_WIDTH => INPUT_DATA_WIDTH,
                INPUT_FRACTION_WIDTH => INPUT_FRACTION_WIDTH,
                OUTPUT_DATA_WIDTH => OUTPUT_DATA_WIDTH,
                OUTPUT_FRACTION_WIDTH => OUTPUT_FRACTION_WIDTH,
                LUT_ADDR_SIZE => LUT_ADDR_SIZE
            )
            port map(
                clk => clk,
                rst_n => rst_n,
                data_i => data_i,
                data_o => data_o,
                valid_i => valid_i,
                valid_o => valid_o
            );
        end generate;

    log2_lut_lintrpl: if STRATEGY = "LUT_LINEAR_INTRPL" generate
        log2_lut_lintrpl: log2_fp_lut_lintrpl_core
            generic map(
                INPUT_DATA_WIDTH => INPUT_DATA_WIDTH,
                INPUT_FRACTION_WIDTH => INPUT_FRACTION_WIDTH,
                OUTPUT_DATA_WIDTH => OUTPUT_DATA_WIDTH,
                OUTPUT_FRACTION_WIDTH => OUTPUT_FRACTION_WIDTH,
                LUT_ADDR_SIZE => LUT_ADDR_SIZE
            )
            port map(
                clk => clk,
                rst_n => rst_n,
                data_i => data_i,
                data_o => data_o,
                valid_i => valid_i,
                valid_o => valid_o
            );
        end generate;

end lut_based;

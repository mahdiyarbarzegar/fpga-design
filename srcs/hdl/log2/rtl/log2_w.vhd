library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity log2_w is
    generic(
        INPUT_DATA_WIDTH: positive := 16;
        INPUT_FRACTION_WIDTH: positive := 8;
        OUTPUT_DATA_WIDTH: positive := 13;
        OUTPUT_FRACTION_WIDTH: positive := 8;
        LUT_ADDR_SIZE: positive := 7
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
            INPUT_DATA_WIDTH: positive := 16;
            INPUT_FRACTION_WIDTH: positive := 8;
            OUTPUT_DATA_WIDTH: positive := 16;
            OUTPUT_FRACTION_WIDTH: positive := 8;
            LUT_ADDR_SIZE: positive := 7
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

end lut_based;

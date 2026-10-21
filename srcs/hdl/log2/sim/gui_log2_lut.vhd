library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;
use std.env.all;

library work;
use work.log2_pkg_utils.all;

entity gui_log2_lut is
end entity;

architecture sim of gui_log2_lut is

    constant INPUT_DATA_WIDTH: positive := 16;
    constant INPUT_FRACTION_WIDTH: positive := 8;
    constant OUTPUT_FRACTION_WIDTH: positive := 8;
    constant OUTPUT_DATA_WIDTH: positive := calc_out_data_width(INPUT_DATA_WIDTH,
        INPUT_FRACTION_WIDTH, OUTPUT_FRACTION_WIDTH);
    constant LUT_ADDR_SIZE: positive := 4;

    constant CLOCK_PERIOD: time := 10 ns;

    component log2_w is
        generic(
            STRATEGY: string;
            USE_DSP: boolean := true;
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

    signal clk: std_logic := '0';
    signal rst_n: std_logic := '0';
    signal input_value: unsigned(INPUT_DATA_WIDTH - 1 downto 0) := (others => '0');
    signal output_value: std_logic_vector(OUTPUT_DATA_WIDTH - 1 downto 0);
    signal log_result: signed(OUTPUT_DATA_WIDTH - 1 downto 0) := (others => '0');
    signal valid_i, valid_o: std_logic;

begin
    log2: log2_w
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
            data_i => std_logic_vector(input_value),
            data_o => output_value,
            valid_i => valid_i,
            valid_o => valid_o
        );

    log_result <= signed(output_value);

    clk <= not clk after CLOCK_PERIOD / 2;

    process
    begin
        rst_n <= '0';
        valid_i <= '0';

        input_value <= to_unsigned(1664, input_value'length); -- log2(6.5) = 2.7 -- 691
        -- input_value <= to_unsigned(65280, input_value'length); -- log2(255) = 7.99 -- 2045
        -- input_value <= to_unsigned(26, input_value'length); -- log2(0.1) = -3.32 -- 7347

        wait for 2 * CLOCK_PERIOD;

        wait until falling_edge(clk);
        wait until rising_edge(clk);
        rst_n <= '1';

        wait until falling_edge(clk);
        valid_i <= '1';

        wait until falling_edge(clk);
        valid_i <= '0';

        wait until valid_o = '1';

        wait for 2 * CLOCK_PERIOD;

        report "Testbench completed";
        finish;
    end process;
end sim;
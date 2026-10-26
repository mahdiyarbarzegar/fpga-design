library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;
use std.env.all;

library work;
use work.log2_pkg_utils.all;

entity gui_log2_native is
end entity;

architecture sim of gui_log2_native is

    constant INTERFACE_TYPE: string := "NATIVE";
    constant STRATEGY: string := "LUT_LINEAR_INTRPL"; --"LUT_LINEAR_INTRPL"
    constant USE_DSP: boolean := false;
    constant INPUT_DATA_WIDTH: positive := 16;
    constant INPUT_FRACTION_WIDTH: positive := 8;
    constant OUTPUT_FRACTION_WIDTH: positive := 8;
    constant OUTPUT_DATA_WIDTH: positive := calc_out_data_width(INPUT_DATA_WIDTH,
        INPUT_FRACTION_WIDTH, OUTPUT_FRACTION_WIDTH);
    constant LUT_ADDR_SIZE: positive := 6;

    constant CLOCK_PERIOD: time := 10 ns;

    signal clk: std_logic := '0';
    signal rst_n: std_logic := '0';
    signal input_value: unsigned(INPUT_DATA_WIDTH - 1 downto 0) := (others => '0');
    signal output_value: std_logic_vector(OUTPUT_DATA_WIDTH - 1 downto 0);
    signal log_result: signed(OUTPUT_DATA_WIDTH - 1 downto 0) := (others => '0');
    signal valid_i, valid_o: std_logic;

begin
    log2: entity work.log2_w
        generic map(
            INTERFACE_TYPE => INTERFACE_TYPE,
            STRATEGY => STRATEGY,
            USE_DSP => USE_DSP,
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
            valid_o => valid_o,
            s_axis_tdata => (others => '0'),
            s_axis_tkeep => (others => '0'),
            s_axis_tvalid => '0',
            m_axis_tready => '0'
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
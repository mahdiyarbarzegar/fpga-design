library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

library work;
use work.log2_pkg_utils.all;

entity log2_bus_axi4stream is
    generic(
        AXIS_DATA_WIDTH: positive;

        STRATEGY: string;
        USE_DSP: boolean;
        INPUT_DATA_WIDTH: positive;
        INPUT_FRACTION_WIDTH: positive;
        OUTPUT_DATA_WIDTH: positive;
        OUTPUT_FRACTION_WIDTH: positive;
        LUT_ADDR_SIZE: positive
    );
    port(
        clk: in std_logic;
        rst_n: in std_logic;

        s_axis_tdata: in std_logic_vector(AXIS_DATA_WIDTH - 1 downto 0);
        s_axis_tkeep: in std_logic_vector(AXIS_DATA_WIDTH / 8 - 1 downto 0);
        s_axis_tready: out std_logic;
        s_axis_tvalid: in std_logic;

        m_axis_tdata: out std_logic_vector(AXIS_DATA_WIDTH - 1 downto 0);
        m_axis_tkeep: out std_logic_vector(AXIS_DATA_WIDTH / 8 - 1 downto 0);
        m_axis_tready: in std_logic;
        m_axis_tvalid: out std_logic
    );
end entity;

architecture axis_ifc of log2_bus_axi4stream is
    constant INPUT_DATA_TKEEP_HIGH_WIDTH: positive := (INPUT_DATA_WIDTH + 7) / 8;
    constant OUTPUT_DATA_TKEEP_HIGH_WIDTH: positive := (OUTPUT_DATA_WIDTH + 7) / 8;

    constant EXPECTED_INPUT_TKEEP:
        std_logic_vector(AXIS_DATA_WIDTH / 8 - 1 downto 0) :=
        make_expected_axis_tkeep(AXIS_DATA_WIDTH / 8, INPUT_DATA_TKEEP_HIGH_WIDTH);

    signal core_data_in: std_logic_vector(INPUT_DATA_WIDTH - 1 downto 0);
    signal core_data_out: std_logic_vector(OUTPUT_DATA_WIDTH - 1 downto 0);
    signal core_valid_in, core_valid_out: std_logic;
    signal core_clock_en: std_logic;
begin

    log2_strategy: entity work.log2_core
        generic map(
            STRATEGY => STRATEGY,
            USE_DSP => USE_DSP,
            INPUT_DATA_WIDTH => INPUT_DATA_WIDTH,
            INPUT_FRACTION_WIDTH => INPUT_FRACTION_WIDTH,
            OUTPUT_DATA_WIDTH => OUTPUT_DATA_WIDTH,
            OUTPUT_FRACTION_WIDTH => OUTPUT_FRACTION_WIDTH,
            LUT_ADDR_SIZE => LUT_ADDR_SIZE,
            USE_CLOCK_EN => true
        )
        port map(
            clk => clk,
            rst_n => rst_n,
            ce => core_clock_en,
            data_i => core_data_in,
            data_o => core_data_out,
            valid_i => core_valid_in,
            valid_o => core_valid_out
        );

    s_axis_tready <= m_axis_tready when rst_n = '1' else '0';

    m_axis_tvalid <= core_valid_out;
    m_axis_tdata <= std_logic_vector(resize(signed(core_data_out), m_axis_tdata'length));
    m_axis_tkeep <= (OUTPUT_DATA_TKEEP_HIGH_WIDTH - 1 downto 0 => '1', others => '0');

    core_clock_en <= m_axis_tready;
    core_data_in <= s_axis_tdata(INPUT_DATA_WIDTH - 1 downto 0);
    core_valid_in <= s_axis_tvalid when (
        (s_axis_tkeep = EXPECTED_INPUT_TKEEP) and (core_clock_en = '1')) else '0';

end axis_ifc;

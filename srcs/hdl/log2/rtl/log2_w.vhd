library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity log2_w is
    generic(
        INTERFACE_TYPE: string := "NATIVE";
        AXIS_DATA_WIDTH: positive := 16;

        STRATEGY: string := "LUT";
        USE_DSP: boolean := true;
        INPUT_DATA_WIDTH: positive := 16;
        INPUT_FRACTION_WIDTH: positive := 8;
        OUTPUT_DATA_WIDTH: positive := 13;
        OUTPUT_FRACTION_WIDTH: positive := 8;
        LUT_ADDR_SIZE: positive := 6
    );
    port(
        clk: in std_logic;
        rst_n: in std_logic;

        data_i: in std_logic_vector(INPUT_DATA_WIDTH - 1 downto 0);
        data_o: out std_logic_vector(OUTPUT_DATA_WIDTH - 1 downto 0);
        valid_i: in std_logic;
        valid_o: out std_logic;

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

architecture lut_based of log2_w is

    ATTRIBUTE X_INTERFACE_INFO : STRING;
    ATTRIBUTE X_INTERFACE_PARAMETER : STRING;

    -- Declare the clk attributes
    ATTRIBUTE X_INTERFACE_INFO of clk: SIGNAL is "xilinx.com:signal:clock:1.0 clk CLK";
    ATTRIBUTE X_INTERFACE_PARAMETER of clk: SIGNAL is "ASSOCIATED_RESET rst_n, FREQ_HZ 100000000, FREQ_TOLERANCE_HZ 100";

    -- Declare the rst_n attributes
    ATTRIBUTE X_INTERFACE_INFO of rst_n: SIGNAL is "xilinx.com:signal:reset:1.0 rst_n RST";
    ATTRIBUTE X_INTERFACE_PARAMETER of rst_n: SIGNAL is "POLARITY ACTIVE_LOW";

    -- Declare the s-axis, m-axis attributes
    ATTRIBUTE X_INTERFACE_INFO of s_axis_tdata: SIGNAL is "xilinx.com:interface:axis:1.0 S_AXIS TDATA";
    ATTRIBUTE X_INTERFACE_INFO of s_axis_tkeep: SIGNAL is "xilinx.com:interface:axis:1.0 S_AXIS TKEEP";
    ATTRIBUTE X_INTERFACE_INFO of s_axis_tvalid: SIGNAL is "xilinx.com:interface:axis:1.0 S_AXIS TVALID";
    ATTRIBUTE X_INTERFACE_INFO of s_axis_tready: SIGNAL is "xilinx.com:interface:axis:1.0 S_AXIS TREADY";
    ATTRIBUTE X_INTERFACE_INFO of m_axis_tdata: SIGNAL is "xilinx.com:interface:axis:1.0 M_AXIS TDATA";
    ATTRIBUTE X_INTERFACE_INFO of m_axis_tkeep: SIGNAL is "xilinx.com:interface:axis:1.0 M_AXIS TKEEP";
    ATTRIBUTE X_INTERFACE_INFO of m_axis_tvalid: SIGNAL is "xilinx.com:interface:axis:1.0 M_AXIS TVALID";
    ATTRIBUTE X_INTERFACE_INFO of m_axis_tready: SIGNAL is "xilinx.com:interface:axis:1.0 M_AXIS TREADY";

    ATTRIBUTE X_INTERFACE_PARAMETER of s_axis_tdata: SIGNAL is "FREQ_HZ 100000000,HAS_TLAST 0,HAS_TKEEP 1,HAS_TSTRB 0,HAS_TREADY 1";
    ATTRIBUTE X_INTERFACE_PARAMETER of m_axis_tdata: SIGNAL is "FREQ_HZ 100000000,HAS_TLAST 0,HAS_TKEEP 1,HAS_TSTRB 0,HAS_TREADY 1";

begin

    native_bus: if INTERFACE_TYPE = "NATIVE" generate
        native_bus_core: entity work.log2_core
            generic map(
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
                ce => '1',
                data_i => data_i,
                data_o => data_o,
                valid_i => valid_i,
                valid_o => valid_o
            );
        end generate;

    axis_bus: if INTERFACE_TYPE = "AXI4_STREAM" generate
        axis_bus_core: entity work.log2_bus_axi4stream
            generic map(
                AXIS_DATA_WIDTH => AXIS_DATA_WIDTH,
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
                s_axis_tdata => s_axis_tdata,
                s_axis_tkeep => s_axis_tkeep,
                s_axis_tready => s_axis_tready,
                s_axis_tvalid => s_axis_tvalid,
                m_axis_tdata => m_axis_tdata,
                m_axis_tkeep => m_axis_tkeep,
                m_axis_tready => m_axis_tready,
                m_axis_tvalid => m_axis_tvalid
            );
        end generate;

end lut_based;

library ieee;
use ieee.std_logic_1164.all;

entity sync_fifo_w is
    generic(
        DEPTH: positive := 16;
        WIDTH: positive := 16
    );
    port(
        clk: in std_logic;
        rst: in std_logic;

        wr_en_i: in std_logic;
        wr_data_i: in std_logic_vector(WIDTH - 1 downto 0);

        rd_en_i: in std_logic;
        rd_data_o: out std_logic_vector(WIDTH - 1 downto 0);

        full_o: out std_logic;
        empty_o: out std_logic
    );
end entity;

architecture structural of sync_fifo_w is

    ATTRIBUTE X_INTERFACE_INFO: STRING;
    ATTRIBUTE X_INTERFACE_PARAMETER: STRING;

    -- Declare the clk attributes
    ATTRIBUTE X_INTERFACE_INFO of clk: SIGNAL is "xilinx.com:signal:clock:1.0 clk CLK";
    ATTRIBUTE X_INTERFACE_PARAMETER of clk: SIGNAL is "ASSOCIATED_RESET rst_n, FREQ_HZ 100000000, FREQ_TOLERANCE_HZ 100";

    -- Declare the rst_n attributes
    ATTRIBUTE X_INTERFACE_INFO of rst: SIGNAL is "xilinx.com:signal:reset:1.0 rst RST";
    ATTRIBUTE X_INTERFACE_PARAMETER of rst: SIGNAL is "POLARITY ACTIVE_HIGH";

    component sync_fifo is
        generic(
            DEPTH: positive;
            WIDTH: positive
        );
        port(
            clk: in std_logic;
            rst: in std_logic;

            wr_en_i: in std_logic;
            wr_data_i: in std_logic_vector(WIDTH - 1 downto 0);

            rd_en_i: in std_logic;
            rd_data_o: out std_logic_vector(WIDTH - 1 downto 0);

            full_o: out std_logic;
            empty_o: out std_logic
        );
    end component;
begin
    sync_fifo_ins: sync_fifo
        generic map(
            DEPTH => DEPTH,
            WIDTH => WIDTH
        )
        port map(
            clk => clk,
            rst => rst,
            wr_en_i => wr_en_i,
            wr_data_i => wr_data_i,
            rd_en_i => rd_en_i,
            rd_data_o => rd_data_o,
            full_o => full_o,
            empty_o => empty_o
        );
end architecture;

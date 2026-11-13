library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;

entity tb_sync_fifo is
end entity;

architecture sim of tb_sync_fifo is
    constant WIDTH: positive := 16;
    constant DEPTH: positive := 16;
    constant CLK_PERIOD: time := 10 ns;

    signal clk: std_logic := '1';
    signal rst: std_logic := '1';
    signal wr_en, rd_en: std_logic := '0';
    signal full, empty: std_logic;
    signal wr_data, rd_data: std_logic_vector(WIDTH - 1 downto 0);

begin

    sync_fifo_16w16d_ins: entity work.sync_fifo_16w16d
        port map(
            clk => clk,
            rst => rst,
            wr_en_i => wr_en,
            wr_data_i => wr_data,
            rd_en_i => rd_en,
            rd_data_o => rd_data,
            full_o => full,
            empty_o => empty
        );

    clk <= not clk after CLK_PERIOD / 2;

    process
    begin

        wait for 2 * CLK_PERIOD;
        wait until falling_edge(clk);
        rst <= '0';

        for i in 0 to DEPTH - 1 loop
            wait until falling_edge(clk);

            wr_en <= '1';
            wr_data <= std_logic_vector(to_unsigned(i, wr_data'length));

            wait until falling_edge(clk);

            wr_en <= '0';
        end loop;

        for i in 0 to DEPTH - 1 loop
            wait until falling_edge(clk);

            rd_en <= '1';

            wait until falling_edge(clk);

            rd_en <= '0';
        end loop;

        finish;

    end process;

end architecture;
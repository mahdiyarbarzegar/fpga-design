library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity sync_fifo is
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
end entity;

architecture rtl of sync_fifo is
    type mem_t is array (0 to DEPTH - 1) of std_logic_vector(WIDTH - 1 downto 0);

    signal mem: mem_t;
    signal counter: integer range 0 to DEPTH;
    signal wr_ptr, rd_ptr: integer range 0 to DEPTH - 1;
    signal full, empty: std_logic;
    signal rd_data_r: std_logic_vector(WIDTH - 1 downto 0);
begin

    full <= '1' when (counter = DEPTH) else '0';
    empty <= '1' when (counter = 0) else '0';

    process(clk)
    begin
        if rising_edge(clk) then

            if wr_en_i = '1' and full = '0' then
                mem(wr_ptr) <= wr_data_i;
                wr_ptr <= 0 when (wr_ptr = DEPTH - 1) else wr_ptr + 1;
            end if;

            if rd_en_i = '1' and empty = '0' then
                rd_data_r <= mem(rd_ptr);
                rd_ptr <= 0 when (rd_ptr = DEPTH - 1) else rd_ptr + 1;
            end if;

            if wr_en_i = '1' and rd_en_i = '0' and full = '0' then
                counter <= counter + 1;
            elsif wr_en_i = '0' and rd_en_i = '1' and empty = '0' then
                counter <= counter - 1;
            end if;

            if rst = '1' then
                counter <= 0;
                wr_ptr <= 0;
                rd_ptr <= 0;
                rd_data_r <= (others => '0');
            end if;

        end if;
    end process;

    full_o <= full;
    empty_o <= empty;
    rd_data_o <= rd_data_r;

end architecture;

library ieee;
use ieee.std_logic_1164.all;

entity array_multiplier_w is
    generic(
        DATA_WIDTH: positive := 32
    );
    port (
        sign: in std_logic;
        a_i: in std_logic_vector(DATA_WIDTH - 1 downto 0);
        b_i: in std_logic_vector(DATA_WIDTH - 1 downto 0);
        m_o: out std_logic_vector(2 * DATA_WIDTH - 1 downto 0)
    );
end entity;

architecture rtl of array_multiplier_w is
    component array_multiplier is
        generic (
            MUL_SIZE: positive := 4
        );
        port (
            sign: in std_logic;
            a_in: in std_logic_vector(MUL_SIZE - 1 downto 0);
            b_in: in std_logic_vector(MUL_SIZE - 1 downto 0);
            m_out: out std_logic_vector(2 * MUL_SIZE - 1 downto 0)
        );
    end component;
begin

    mul: array_multiplier
        generic map(
            MUL_SIZE => DATA_WIDTH
        )
        port map(
            sign => sign,
            a_in => a_i,
            b_in => b_i,
            m_out => m_o
        );

end rtl;

library ieee;
use ieee.std_logic_1164.all;

entity array_multiplier is
    generic (
        MUL_SIZE: positive := 4
    );
    port (
        sign: in std_logic;
        a_in: in std_logic_vector(MUL_SIZE - 1 downto 0);
        b_in: in std_logic_vector(MUL_SIZE - 1 downto 0);
        m_out: out std_logic_vector(2 * MUL_SIZE - 1 downto 0)
    );
end entity;

architecture rtl of array_multiplier is
    constant MID_SIZE: positive := 2 * MUL_SIZE;

    type vector_array_t is
        array (natural range<>) of std_logic_vector(MID_SIZE - 1 downto 0);

    type double_vector_array_t is
        array (natural range<>) of std_logic_vector(2 * MID_SIZE - 1 downto 0);

    signal a, b, c: vector_array_t(0 to MID_SIZE);
    signal p: double_vector_array_t(0 to MID_SIZE);

    component mul_slice is
        port (
            ai: in std_logic;
            bi: in std_logic;
            pi: in std_logic;
            ci: in std_logic;
            ao: out std_logic;
            bo: out std_logic;
            po: out std_logic;
            co: out std_logic
        );
    end component;
begin

    a(0) <= (MID_SIZE - 1 downto MUL_SIZE => a_in(MUL_SIZE - 1)) & a_in
        when sign = '1' else
        (MID_SIZE - 1 downto MUL_SIZE => '0') & a_in;

    b(0) <= (MID_SIZE - 1 downto MUL_SIZE => b_in(MUL_SIZE - 1)) & b_in
        when sign = '1' else
        (MID_SIZE - 1 downto MUL_SIZE => '0') & b_in;

    c(0) <= (others => '0');

    p(0) <= (others => '0');

    mul_row: for i in 0 to MID_SIZE - 1 generate
        mul_col: for j in 0 to MID_SIZE - 1 generate
            mul: mul_slice
                port map(
                    ai => a(j)(i),
                    bi => b(i)(j),
                    pi => p(i)(i + j),
                    ci => c(j)(i),
                    ao => a(j + 1)(i),
                    bo => b(i + 1)(j),
                    po => p(i + 1)(i + j),
                    co => c(j + 1)(i)
                );
            end generate mul_col;

            p(i + 1)(MID_SIZE + i) <= c(MID_SIZE)(i);
            m_out(i) <= p(i + 1)(i);

        end generate mul_row;

end rtl;
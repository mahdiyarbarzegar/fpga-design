library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity carry_predictor is
    generic(
        CARRY_WIDTH: positive := 4
    );
    port(
        cin: in std_logic;
        p: in std_logic_vector(CARRY_WIDTH - 1 downto 0);
        g: in std_logic_vector(CARRY_WIDTH - 1 downto 0);
        cout: out std_logic_vector(CARRY_WIDTH - 1 downto 0)
    );
end entity;

architecture behavioral of carry_predictor is
    signal c: std_logic_vector(CARRY_WIDTH downto 0);
begin

    c(0) <= cin;
    cout <= c(CARRY_WIDTH downto 1);

    cp_slice: for i in 0 to CARRY_WIDTH - 1 generate
        c(i + 1) <= (p(i) and c(i)) or g(i);
        end generate;
end behavioral;
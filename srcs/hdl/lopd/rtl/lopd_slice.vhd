library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;
use ieee.std_logic_misc.all;

entity lopd_slice is
    generic (
        DATA_WIDTH: integer := 4
    );
    port (
        d_i: in std_logic_vector(DATA_WIDTH - 1 downto 0);
        d_o: out std_logic_vector(integer(ceil(log2(real(DATA_WIDTH - 1)))) - 1 downto 0);
        z_o: out std_logic
    );
end entity;

architecture behave of lopd_slice is
begin

    z_o <= not or_reduce(d_i);

    process(all)
    begin
        d_o <= (others => '0');

        for i in DATA_WIDTH - 1 downto 0 loop
            if d_i(i) = '1' then
                d_o <= std_logic_vector(to_unsigned(i, d_o'length));
                exit;
            end if;
        end loop;
    end process;

end behave;
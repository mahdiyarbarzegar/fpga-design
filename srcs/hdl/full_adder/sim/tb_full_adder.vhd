library ieee;
use ieee.std_logic_1164.all;
use std.env.all;

entity tb_full_adder is
end tb_full_adder;

architecture sim of tb_full_adder is
    signal a, b, cin, y, cout: std_logic;
    signal res: std_logic_vector(1 downto 0);

    component full_adder is
        port (
            in1: in std_logic;
            in2: in std_logic;
            cin: in std_logic;
            sum: out std_logic;
            cout: out std_logic
        );
    end component;
begin

    fa: full_adder
        port map (
            in1 => a,
            in2 => b,
            cin => cin,
            sum => y,
            cout => cout
        );

    res <= cout & y;

    process
    begin
        a <= '1';
        b <= '0';
        cin <= '1';
        wait for 10 ns;

        report "in1: " & std_logic'image(a) &
            ", in2: " & std_logic'image(b) &
            ", cin: " & std_logic'image(cin) &
            " -> sum: " & std_logic'image(y) &
            ", cout: " & std_logic'image(cout);

        if res = "10" then
            report "successfull result!";
        else
            report "wrong result!";
        end if;

        wait;
    end process;
end sim;
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_ripple_carry_adder is
end entity;

architecture sim of tb_ripple_carry_adder is
    constant BUS_WIDTH: positive := 8;

    signal add_sub_b, sign, z, n, c, v: std_logic;
    signal a, b, y: unsigned(BUS_WIDTH - 1 downto 0);
    signal y_slv: std_logic_vector(BUS_WIDTH - 1 downto 0);

    component ripple_carry_adder_w is
        generic(
            BUS_WIDTH: positive := 32
        );
        port(
            add_sub_b: in std_logic;
            sign: in std_logic;
            a_i: in std_logic_vector(BUS_WIDTH - 1 downto 0);
            b_i: in std_logic_vector(BUS_WIDTH - 1 downto 0);
            y_o: out std_logic_vector(BUS_WIDTH - 1 downto 0);
            z: out std_logic;
            n: out std_logic;
            c: out std_logic;
            v: out std_logic
        );
    end component;
begin

    adder: ripple_carry_adder_w
        generic map(
            BUS_WIDTH => BUS_WIDTH
        )
        port map (
            add_sub_b => add_sub_b,
            sign => sign,
            a_i => std_logic_vector(a),
            b_i => std_logic_vector(b),
            y_o => y_slv,
            z => z,
            n => n,
            c => c,
            v => v
        );

    y <= unsigned(y_slv);

    process
    begin
        add_sub_b <= '0';
        sign <= '0';
        a <= to_unsigned(12, a'length);
        b <= to_unsigned(24, b'length);
        wait for 10 ns;
        report "in1: " & integer'image(to_integer(a)) &
            ", in2: " & integer'image(to_integer(b)) &
            " -> in1 + in2: " & integer'image(to_integer(y)) &
            ", z:" & std_logic'image(z) &
            "-n:" & std_logic'image(n) &
            "-c:" & std_logic'image(c) &
            "-v:" & std_logic'image(v);

        if y = to_unsigned(36, y'length) then
            report "successfull result!";
        else
            report "wrong result!";
        end if;

        add_sub_b <= '1';
        sign <= '0';
        a <= to_unsigned(110, a'length);
        b <= to_unsigned(24, b'length);
        wait for 10 ns;
        report "in1: " & integer'image(to_integer(a)) &
            ", in2: " & integer'image(to_integer(b)) &
            " -> in1 - in2: " & integer'image(to_integer(y)) &
            ", z:" & std_logic'image(z) &
            "-n:" & std_logic'image(n) &
            "-c:" & std_logic'image(c) &
            "-v:" & std_logic'image(v);

        if y = to_unsigned(86, y'length) then
            report "successfull result!";
        else
            report "wrong result!";
        end if;

        add_sub_b <= '0';
        sign <= '0';
        a <= to_unsigned(110, a'length);
        b <= to_unsigned(220, b'length);
        wait for 10 ns;
        report "in1: " & integer'image(to_integer(a)) &
            ", in2: " & integer'image(to_integer(b)) &
            " -> in1 + in2: " & integer'image(to_integer(y)) &
            ", z:" & std_logic'image(z) &
            "-n:" & std_logic'image(n) &
            "-c:" & std_logic'image(c) &
            "-v:" & std_logic'image(v);

        if c /= '1' then
            report "wrong result!";
        else
            report "successfull result!";
        end if;

        add_sub_b <= '1';
        sign <= '0';
        a <= to_unsigned(110, a'length);
        b <= to_unsigned(220, b'length);
        wait for 10 ns;
        report "in1: " & integer'image(to_integer(a)) &
            ", in2: " & integer'image(to_integer(b)) &
            " -> in1 - in2: " & integer'image(to_integer(y)) &
            ", z:" & std_logic'image(z) &
            "-n:" & std_logic'image(n) &
            "-c:" & std_logic'image(c) &
            "-v:" & std_logic'image(v);

        if c /= '0' then
            report "wrong result!";
        else
            report "successfull result!";
        end if;

        wait;

    end process;

end architecture sim;
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity booth_multiplier is
    generic(
        MUL_WIDTH: positive := 4
    );
    port(
        clk: in std_logic;
        rst_n: in std_logic;
        start: in std_logic;
        sign: in std_logic;
        data_in1: in std_logic_vector(MUL_WIDTH - 1 downto 0);
        data_in2: in std_logic_vector(MUL_WIDTH - 1 downto 0);
        data_out: out std_logic_vector(2 * MUL_WIDTH - 1 downto 0);
        ready: out std_logic
    );
end entity;

architecture rtl of booth_multiplier is
    signal multiplicand: std_logic_vector(MUL_WIDTH downto 0);
    signal product: std_logic_vector(2 * MUL_WIDTH + 1 downto 0);
    signal running: std_logic;
    signal counter: natural range 0 to MUL_WIDTH;
    signal shift_right: std_logic;
    signal in1: std_logic_vector(MUL_WIDTH downto 0);
    signal sum_result: std_logic_vector(MUL_WIDTH downto 0);
    signal sub_result: std_logic_vector(MUL_WIDTH downto 0);
    signal booth_state: std_logic_vector(1 downto 0);
begin

    in1 <= data_in1(MUL_WIDTH - 1) & data_in1
        when sign = '1' else
        '0' & data_in1;

    sum_result <= std_logic_vector(
        unsigned(product(2 * MUL_WIDTH + 1 downto MUL_WIDTH + 1)) + unsigned(multiplicand));

    sub_result <= std_logic_vector(
        unsigned(product(2 * MUL_WIDTH + 1 downto MUL_WIDTH + 1)) - unsigned(multiplicand));

    data_out <= product(2 * MUL_WIDTH downto 1);
    booth_state <= product(1 downto 0);

    process (clk)
    begin
        if rising_edge(clk) then
            if counter = MUL_WIDTH then
                ready <= '1';
                running <= '0';
            else
                if running = '1' then
                    if shift_right = '0' and booth_state = "01" then
                        product <= sum_result & product(MUL_WIDTH downto 0);
                        shift_right <= '1';
                    elsif shift_right = '0' and booth_state = "10" then
                        product <= sub_result & product(MUL_WIDTH downto 0);
                        shift_right <= '1';
                    else
                        shift_right <= '0';
                        product <= product(2 * MUL_WIDTH + 1) & product(
                            2 * MUL_WIDTH + 1 downto 1);
                        counter <= counter + 1;
                    end if;
                end if;
            end if;

            if running = '0' and start = '1' then
                multiplicand <= in1;
                product <= (2 * MUL_WIDTH + 1 downto MUL_WIDTH + 1 => '0') & data_in2 & '0';
                running <= '1';
                ready <= '0';
                counter <= 0;
                shift_right <= '0';
            end if;

            if rst_n = '0' then
                multiplicand <= (others => '0');
                product <= (others => '0');
                ready <= '1';
                running <= '0';
                counter <= 0;
                shift_right <= '0';
            end if;
        end if;
    end process;
end rtl;
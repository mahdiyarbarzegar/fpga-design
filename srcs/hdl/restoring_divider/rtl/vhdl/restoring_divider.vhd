library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity restoring_divider is
    generic (
        DIV_WIDTH: positive := 32
    );
    port(
        clk: in std_logic;
        rst_n: in std_logic;
        start: in std_logic;
        sign: in std_logic;
        in1: in std_logic_vector(DIV_WIDTH - 1 downto 0);
        in2: in std_logic_vector(DIV_WIDTH - 1 downto 0);
        q: out std_logic_vector(DIV_WIDTH - 1 downto 0);
        r: out std_logic_vector(DIV_WIDTH - 1 downto 0);
        ready: out std_logic
    );
end entity;

architecture rtl of restoring_divider is
    type States is (S_IDLE, S_STARTING, S_LOADING, S_RUNNING);

    signal a_reg, b_reg, a_mux, sub_out: std_logic_vector(DIV_WIDTH - 1 downto 0);
    signal q_cnt: unsigned(DIV_WIDTH - 1 downto 0);
    signal sub_flag_z, sub_flag_n, sub_flag_c, sub_flag_v: std_logic;
    signal in1_sign, in2_sign: std_logic;

    signal state, next_state: States;
    signal a_sel: std_logic;
    signal a_reg_en, b_reg_en: std_logic;
    signal add_sub: std_logic;
    signal q_cnt_en, q_cnt_rst: std_logic;
    signal q_neg: std_logic;

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

    rca: ripple_carry_adder_w
        generic map(
            BUS_WIDTH => DIV_WIDTH
        )
        port map(
            add_sub_b => not add_sub,
            sign => sign,
            a_i => a_reg,
            b_i => b_reg,
            y_o => sub_out,
            z => sub_flag_z,
            n => sub_flag_n,
            c => sub_flag_c,
            v => sub_flag_v
        );

    a_mux <= in1 when a_sel = '1' else sub_out;
    in1_sign <= in1(DIV_WIDTH - 1);
    in2_sign <= in2(DIV_WIDTH - 1);
    q <= std_logic_vector((not q_cnt) + 1) when q_neg = '1' else std_logic_vector(q_cnt);
    r <= a_reg;

    process(clk)
    begin
        if rising_edge(clk) then
            if a_reg_en = '1' then
                a_reg <= a_mux;
            end if;

            if b_reg_en = '1' then
                b_reg <= in2;
            end if;

            if q_cnt_en = '1' then
                q_cnt <= q_cnt + 1;
            end if;

            if q_cnt_rst = '1' then
                q_cnt <= (others => '0');
            end if;

            if rst_n = '0' then
                a_reg <= (others => '0');
                b_reg <= (others => '0');
                q_cnt <= (others => '0');
            end if;
        end if;
    end process;

    add_sub <= (in1_sign xor in2_sign) when sign = '1' else '0';
    q_neg <= (in1_sign xor in2_sign) when sign = '1' else '0';

    process(all)
        variable stop: std_logic;
    begin
        -- Default control values
        ready     <= '0';
        a_sel     <= '0';
        a_reg_en  <= '0';
        b_reg_en  <= '0';
        q_cnt_rst <= '0';
        q_cnt_en  <= '0';

        stop := '0';

        case state is
            when S_IDLE =>
                ready <= '1';

            when S_STARTING =>
                q_cnt_rst <= '1';

            when S_LOADING =>
                a_sel <= '1';
                a_reg_en <= '1';
                b_reg_en <= '1';

            when S_RUNNING =>
                stop := (in1_sign xor sub_flag_n) when sign = '1' else not sub_flag_c;

                ready <= stop;
                q_cnt_en <= not stop;
                a_reg_en <= not stop;

            when others =>
                ready <= '1';

        end case;
    end process;

    process(clk)
    begin
        if rising_edge(clk) then
            state <= next_state;

            if rst_n = '0' then
                state <= S_IDLE;
            end if;
        end if;
    end process;

    process(all)
    begin
        next_state <= state;

        case state is
            when S_IDLE =>
                if start = '1' then
                    next_state <= S_STARTING;
                end if;

            when S_STARTING =>
                if start = '0' then
                    next_state <= S_LOADING;
                end if;

            when S_LOADING =>
                next_state <= S_RUNNING;

            when S_RUNNING =>
                if ready = '1' then
                    next_state <= S_IDLE;
                end if;

            when others =>
                next_state <= S_IDLE;
        end case;
    end process;

end rtl;

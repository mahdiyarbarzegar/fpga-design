library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;
use ieee.std_logic_misc.all;

entity log2_fp_lut_lintrpl_core is
    generic(
        INPUT_DATA_WIDTH: positive;
        INPUT_FRACTION_WIDTH: positive;
        OUTPUT_DATA_WIDTH: positive;
        OUTPUT_FRACTION_WIDTH: positive;
        LUT_ADDR_SIZE: positive
    );
    port(
        clk: in std_logic;
        rst_n: in std_logic;

        data_i: in std_logic_vector(INPUT_DATA_WIDTH - 1 downto 0);
        data_o: out std_logic_vector(OUTPUT_DATA_WIDTH - 1 downto 0);

        valid_i: in std_logic;
        valid_o: out std_logic
    );
end entity;

architecture rtl_lut of log2_fp_lut_lintrpl_core is

    constant INPUT_INTEGER_WIDTH: positive := INPUT_DATA_WIDTH - INPUT_FRACTION_WIDTH;
    constant OUTPUT_INTEGER_WIDTH: positive := OUTPUT_DATA_WIDTH - OUTPUT_FRACTION_WIDTH;
    constant REMAIN_MANTISSA_WIDTH: positive := INPUT_DATA_WIDTH - LUT_ADDR_SIZE - 1;
    constant MUL_RESULT_WIDTH: positive := REMAIN_MANTISSA_WIDTH + OUTPUT_FRACTION_WIDTH;

    component log2_fp_lut_gen_dual_port is
        generic (
            ADDR_WIDTH: positive := 7;
            DATA_WIDTH: positive := 8
        );
        port(
            index: in std_logic_vector(ADDR_WIDTH - 1 downto 0);
            data: out std_logic_vector(DATA_WIDTH - 1 downto 0);
            data_n: out std_logic_vector(DATA_WIDTH downto 0)
        );
    end component;

    component lopd is
        generic(
            INPUT_DATA_WIDTH: integer := 32;
            LOPD_SLICE_DATA_WIDTH: integer := 4;
            OUTPUT_DATA_WIDTH: integer := 5
        );
        port(
            clk: in std_logic;
            rst_n: in std_logic;
            d_i: in std_logic_vector(INPUT_DATA_WIDTH - 1 downto 0);
            d_o: out std_logic_vector(OUTPUT_DATA_WIDTH - 1 downto 0);
            z_o: out std_logic
        );
    end component;

    -- Stage 1 Signals
    signal valid_s1: std_logic;
    signal data_s1: std_logic_vector(INPUT_DATA_WIDTH - 1 downto 0);

    -- Stage 2 Signals
    signal valid_s2: std_logic;
    signal data_s2: std_logic_vector(INPUT_DATA_WIDTH - 1 downto 0);
    signal data_lop_s2: std_logic_vector(
        integer(ceil(log2(real(INPUT_DATA_WIDTH - 1)))) - 1 downto 0);
    signal data_lop_zflag_s2: std_logic;

    -- Stage 3 Signals
    signal valid_s3: std_logic;
    signal exponent_k_s3: signed(OUTPUT_INTEGER_WIDTH - 1 downto 0);
    signal mantissa_index_s3: std_logic_vector(LUT_ADDR_SIZE - 1 downto 0);
    signal mantissa_remain_s3: std_logic_vector(REMAIN_MANTISSA_WIDTH - 1 downto 0);
    signal mantissa_log_s3: std_logic_vector(OUTPUT_FRACTION_WIDTH - 1 downto 0);
    signal mantissa_log_n_s3: std_logic_vector(OUTPUT_FRACTION_WIDTH downto 0);
    signal mantissa_diff_s3: std_logic_vector(OUTPUT_FRACTION_WIDTH - 1 downto 0);

    -- Stage 4 Signals
    signal valid_s4: std_logic;
    signal exponent_k_s4: signed(OUTPUT_INTEGER_WIDTH - 1 downto 0);
    signal mantissa_remain_s4: std_logic_vector(REMAIN_MANTISSA_WIDTH - 1 downto 0);
    signal mantissa_log_s4: std_logic_vector(OUTPUT_FRACTION_WIDTH - 1 downto 0);
    signal mantissa_diff_s4: std_logic_vector(OUTPUT_FRACTION_WIDTH - 1 downto 0);
    signal mul_result_s4: unsigned(MUL_RESULT_WIDTH - 1 downto 0);

    -- Stage 5 Signals
    signal valid_s5: std_logic;
    signal exponent_k_s5: signed(OUTPUT_INTEGER_WIDTH - 1 downto 0);
    signal mantissa_remain_s5: std_logic_vector(REMAIN_MANTISSA_WIDTH - 1 downto 0);
    signal mantissa_log_s5, mantissa_diff_s5: std_logic_vector(OUTPUT_FRACTION_WIDTH - 1 downto 0);
    signal mul_result_s5: std_logic_vector(OUTPUT_FRACTION_WIDTH - 1 downto 0);
    signal mantissa_add_result_s5: std_logic_vector(OUTPUT_FRACTION_WIDTH downto 0);

    -- Stage 6 Signals
    signal valid_s6: std_logic;
    signal calc_result_s6: std_logic_vector(OUTPUT_DATA_WIDTH - 1 downto 0);

    -- Wires
    signal position: integer;
    signal norm_mantissa: std_logic_vector(INPUT_DATA_WIDTH - 1 downto 0);
    signal exponent_k_added: signed(OUTPUT_INTEGER_WIDTH - 1 downto 0);

begin

    lut_gen: log2_fp_lut_gen_dual_port
        generic map(
            ADDR_WIDTH => LUT_ADDR_SIZE,
            DATA_WIDTH => OUTPUT_FRACTION_WIDTH
        )
        port map(
            index => mantissa_index_s3,
            data => mantissa_log_s3,
            data_n => mantissa_log_n_s3
        );

    lopd_ins: lopd
        generic map(
            INPUT_DATA_WIDTH => INPUT_DATA_WIDTH,
            LOPD_SLICE_DATA_WIDTH => 4,
            OUTPUT_DATA_WIDTH => integer(ceil(log2(real(INPUT_DATA_WIDTH - 1))))
        )
        port map(
            clk => clk,
            rst_n => rst_n,
            d_i => data_i,
            d_o => data_lop_s2,
            z_o => data_lop_zflag_s2
        );

    position <= to_integer(unsigned(data_lop_s2));
    norm_mantissa <= std_logic_vector(shift_left(unsigned(data_s2), data_s2'length - position - 1));

    mantissa_diff_s3 <= std_logic_vector(
        resize(unsigned(mantissa_log_n_s3) - unsigned(('0' & mantissa_log_s3)),
            mantissa_diff_s3'length));

    mul_result_s4 <= unsigned(mantissa_remain_s4) * unsigned(mantissa_diff_s4);

    mantissa_add_result_s5 <= std_logic_vector(
        ('0' & unsigned(mul_result_s5)) + ('0' & unsigned(mantissa_log_s5)));

    exponent_k_added <= exponent_k_s5 + mantissa_add_result_s5(OUTPUT_FRACTION_WIDTH);

    data_o <= calc_result_s6;
    valid_o <= valid_s6;

    process(clk)
    begin
        if rising_edge(clk) then

            ----------------------------------- Stage 1
            if valid_i = '0' or or_reduce(data_i) = '0' then
                valid_s1 <= '0';
            else
                valid_s1 <= '1';
            end if;

            data_s1 <= data_i;

            ----------------------------------- Stage 2
            valid_s2 <= valid_s1;
            data_s2 <= data_s1;

            ----------------------------------- Stage 3
            valid_s3 <= valid_s2;
            exponent_k_s3 <= to_signed(integer(position) - integer(INPUT_FRACTION_WIDTH),
                exponent_k_s3'length);

            mantissa_index_s3 <= norm_mantissa(
                norm_mantissa'length - 2 downto norm_mantissa'length - LUT_ADDR_SIZE - 1);

            mantissa_remain_s3 <= norm_mantissa(REMAIN_MANTISSA_WIDTH - 1 downto 0);

            ----------------------------------- Stage 4
            valid_s4 <= valid_s3;

            exponent_k_s4 <= exponent_k_s3;
            mantissa_log_s4 <= mantissa_log_s3;
            mantissa_diff_s4 <= mantissa_diff_s3;
            mantissa_remain_s4 <= mantissa_remain_s3;

            ----------------------------------- Stage 5
            valid_s5 <= valid_s4;

            exponent_k_s5 <= exponent_k_s4;
            mantissa_log_s5 <= mantissa_log_s4;
            mul_result_s5 <= std_logic_vector(
                mul_result_s4(MUL_RESULT_WIDTH - 1 downto REMAIN_MANTISSA_WIDTH));

            ----------------------------------- Stage 6
            valid_s6 <= valid_s5;

            calc_result_s6 <= std_logic_vector(exponent_k_added) & mantissa_add_result_s5(
                OUTPUT_FRACTION_WIDTH - 1 downto 0);


            if rst_n = '0' then
                valid_s1 <= '0';
                valid_s2 <= '0';
                valid_s3 <= '0';
                valid_s4 <= '0';
                valid_s5 <= '0';
                valid_s6 <= '0';
                data_s1 <= (others => '0');
                data_s2 <= (others => '0');
                exponent_k_s3 <= (others => '0');
                exponent_k_s4 <= (others => '0');
                exponent_k_s5 <= (others => '0');
                mantissa_index_s3 <= (others => '0');
                mantissa_remain_s3 <= (others => '0');
                mantissa_log_s4 <= (others => '0');
                mantissa_diff_s4 <= (others => '0');
                mantissa_remain_s4 <= (others => '0');
                mantissa_log_s5 <= (others => '0');
                mantissa_remain_s5 <= (others => '0');
                mul_result_s5 <= (others => '0');
                calc_result_s6 <= (others => '0');
            end if;

        end if;
    end process;

end rtl_lut;

architecture rtl_dsp of log2_fp_lut_lintrpl_core is

    constant INPUT_INTEGER_WIDTH: positive := INPUT_DATA_WIDTH - INPUT_FRACTION_WIDTH;
    constant OUTPUT_INTEGER_WIDTH: positive := OUTPUT_DATA_WIDTH - OUTPUT_FRACTION_WIDTH;
    constant REMAIN_MANTISSA_WIDTH: positive := INPUT_DATA_WIDTH - LUT_ADDR_SIZE - 1;
    constant MUL_RESULT_WIDTH: positive := REMAIN_MANTISSA_WIDTH + OUTPUT_FRACTION_WIDTH;
    constant DSP48E1_A_PORT_WIDTH: positive := OUTPUT_FRACTION_WIDTH + 2;
    constant DSP48E1_B_PORT_WIDTH: positive := REMAIN_MANTISSA_WIDTH + 1;
    constant DSP48E1_C_PORT_WIDTH: positive := MUL_RESULT_WIDTH + 1;
    constant DSP48E1_D_PORT_WIDTH: positive := OUTPUT_FRACTION_WIDTH + 2;
    constant DSP48E1_P_PORT_WIDTH: positive := maximum(
        maximum(DSP48E1_A_PORT_WIDTH, DSP48E1_D_PORT_WIDTH) + 1 + DSP48E1_B_PORT_WIDTH,
        DSP48E1_C_PORT_WIDTH) + 1;

    component log2_fp_lut_gen_dual_port is
        generic (
            ADDR_WIDTH: positive := 7;
            DATA_WIDTH: positive := 8
        );
        port(
            index: in std_logic_vector(ADDR_WIDTH - 1 downto 0);
            data: out std_logic_vector(DATA_WIDTH - 1 downto 0);
            data_n: out std_logic_vector(DATA_WIDTH downto 0)
        );
    end component;

    component lopd is
        generic(
            INPUT_DATA_WIDTH: integer := 32;
            LOPD_SLICE_DATA_WIDTH: integer := 4;
            OUTPUT_DATA_WIDTH: integer := 5
        );
        port(
            clk: in std_logic;
            rst_n: in std_logic;
            d_i: in std_logic_vector(INPUT_DATA_WIDTH - 1 downto 0);
            d_o: out std_logic_vector(OUTPUT_DATA_WIDTH - 1 downto 0);
            z_o: out std_logic
        );
    end component;

    component log2_dsp_slice is
        generic (
            A_WIDTH: positive;
            B_WIDTH: positive;
            C_WIDTH: positive;
            D_WIDTH: positive;
            P_WIDTH: positive
        );
        port (
            clk: in std_logic;
            a: in std_logic_vector(A_WIDTH - 1 downto 0);
            b: in std_logic_vector(B_WIDTH - 1 downto 0);
            c: in std_logic_vector(C_WIDTH - 1 downto 0);
            d: in std_logic_vector(D_WIDTH - 1 downto 0);
            p: out std_logic_vector(P_WIDTH - 1 downto 0)
        );
    end component;

    -- Stage 1 Signals
    signal valid_s1: std_logic;
    signal data_s1: std_logic_vector(INPUT_DATA_WIDTH - 1 downto 0);

    -- Stage 2 Signals
    signal valid_s2: std_logic;
    signal data_s2: std_logic_vector(INPUT_DATA_WIDTH - 1 downto 0);
    signal data_lop_s2: std_logic_vector(
        integer(ceil(log2(real(INPUT_DATA_WIDTH - 1)))) - 1 downto 0);
    signal data_lop_zflag_s2: std_logic;

    -- Stage 3 Signals
    signal valid_s3: std_logic;
    signal exponent_k_s3: signed(OUTPUT_INTEGER_WIDTH - 1 downto 0);
    signal mantissa_index_s3: std_logic_vector(LUT_ADDR_SIZE - 1 downto 0);
    signal mantissa_remain_s3: std_logic_vector(REMAIN_MANTISSA_WIDTH - 1 downto 0);
    signal mantissa_log_s3: std_logic_vector(OUTPUT_FRACTION_WIDTH - 1 downto 0);
    signal mantissa_log_n_s3: std_logic_vector(OUTPUT_FRACTION_WIDTH downto 0);

    -- Stage 4 Signals
    signal valid_s4: std_logic;
    signal exponent_k_s4: signed(OUTPUT_INTEGER_WIDTH - 1 downto 0);

    -- Stage 5 Signals
    signal valid_s5: std_logic;
    signal exponent_k_s5: signed(OUTPUT_INTEGER_WIDTH - 1 downto 0);
    signal mantissa_add_result_s5: std_logic_vector(OUTPUT_FRACTION_WIDTH downto 0);
    signal dsp_slice_result_s5: std_logic_vector(DSP48E1_P_PORT_WIDTH - 1 downto 0);

    -- Stage 6 Signals
    signal valid_s6: std_logic;
    signal calc_result_s6: std_logic_vector(OUTPUT_DATA_WIDTH - 1 downto 0);

    -- Wires
    signal position: integer;
    signal norm_mantissa, norm_mantissa_remain: std_logic_vector(INPUT_DATA_WIDTH - 1 downto 0);
    signal exponent_k_added: signed(OUTPUT_INTEGER_WIDTH - 1 downto 0);

begin

    lut_gen: log2_fp_lut_gen_dual_port
        generic map(
            ADDR_WIDTH => LUT_ADDR_SIZE,
            DATA_WIDTH => OUTPUT_FRACTION_WIDTH
        )
        port map(
            index => mantissa_index_s3,
            data => mantissa_log_s3,
            data_n => mantissa_log_n_s3
        );

    lopd_ins: lopd
        generic map(
            INPUT_DATA_WIDTH => INPUT_DATA_WIDTH,
            LOPD_SLICE_DATA_WIDTH => 4,
            OUTPUT_DATA_WIDTH => integer(ceil(log2(real(INPUT_DATA_WIDTH - 1))))
        )
        port map(
            clk => clk,
            rst_n => rst_n,
            d_i => data_i,
            d_o => data_lop_s2,
            z_o => data_lop_zflag_s2
        );

    dsp_slice: log2_dsp_slice
        generic map(
            A_WIDTH => DSP48E1_A_PORT_WIDTH,
            B_WIDTH => DSP48E1_B_PORT_WIDTH,
            C_WIDTH => DSP48E1_C_PORT_WIDTH,
            D_WIDTH => DSP48E1_D_PORT_WIDTH,
            P_WIDTH => DSP48E1_P_PORT_WIDTH
        )
        port map(
            clk => clk,
            a => std_logic_vector(resize(unsigned(mantissa_log_s3), DSP48E1_A_PORT_WIDTH)),
            b => std_logic_vector(resize(unsigned(mantissa_remain_s3), DSP48E1_B_PORT_WIDTH)),
            c => std_logic_vector(
                resize(unsigned(mantissa_log_s3), DSP48E1_C_PORT_WIDTH) sll REMAIN_MANTISSA_WIDTH),
            d => std_logic_vector(resize(unsigned(mantissa_log_n_s3), DSP48E1_D_PORT_WIDTH)),
            p => dsp_slice_result_s5
        );

    position <= to_integer(unsigned(data_lop_s2));
    norm_mantissa <= std_logic_vector(shift_left(unsigned(data_s2), data_s2'length - position - 1));
    norm_mantissa_remain <= std_logic_vector(
        shift_left(unsigned(data_s2), data_s2'length - position + LUT_ADDR_SIZE));

    mantissa_add_result_s5 <= dsp_slice_result_s5(
        MUL_RESULT_WIDTH downto MUL_RESULT_WIDTH - OUTPUT_FRACTION_WIDTH);

    exponent_k_added <= exponent_k_s5 + mantissa_add_result_s5(OUTPUT_FRACTION_WIDTH);

    data_o <= calc_result_s6;
    valid_o <= valid_s6;

    process(clk)
    begin
        if rising_edge(clk) then

            ----------------------------------- Stage 1
            if valid_i = '0' or or_reduce(data_i) = '0' then
                valid_s1 <= '0';
            else
                valid_s1 <= '1';
            end if;

            data_s1 <= data_i;

            ----------------------------------- Stage 2
            valid_s2 <= valid_s1;
            data_s2 <= data_s1;

            ----------------------------------- Stage 3
            valid_s3 <= valid_s2;
            exponent_k_s3 <= to_signed(integer(position) - integer(INPUT_FRACTION_WIDTH),
                exponent_k_s3'length);

            mantissa_index_s3 <= norm_mantissa(
                norm_mantissa'length - 2 downto norm_mantissa'length - LUT_ADDR_SIZE - 1);

            mantissa_remain_s3 <= norm_mantissa_remain(
                norm_mantissa_remain'length - 1 downto norm_mantissa_remain'length - REMAIN_MANTISSA_WIDTH);

            ----------------------------------- Stage 4
            valid_s4 <= valid_s3;

            exponent_k_s4 <= exponent_k_s3;

            ----------------------------------- Stage 5
            valid_s5 <= valid_s4;

            exponent_k_s5 <= exponent_k_s4;

            ----------------------------------- Stage 6
            valid_s6 <= valid_s5;

            calc_result_s6 <= std_logic_vector(exponent_k_added) & mantissa_add_result_s5(
                OUTPUT_FRACTION_WIDTH - 1 downto 0);

            if rst_n = '0' then
                valid_s1 <= '0';
                valid_s2 <= '0';
                valid_s3 <= '0';
                valid_s4 <= '0';
                valid_s5 <= '0';
                valid_s6 <= '0';
                data_s1 <= (others => '0');
                data_s2 <= (others => '0');
                exponent_k_s3 <= (others => '0');
                exponent_k_s4 <= (others => '0');
                exponent_k_s5 <= (others => '0');
                mantissa_index_s3 <= (others => '0');
                mantissa_remain_s3 <= (others => '0');
                calc_result_s6 <= (others => '0');
            end if;

        end if;
    end process;

end rtl_dsp;
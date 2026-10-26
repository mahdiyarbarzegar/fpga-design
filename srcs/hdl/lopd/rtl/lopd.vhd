library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;
use ieee.std_logic_misc.all;

entity lopd is
    generic(
        INPUT_DATA_WIDTH: integer := 32;
        LOPD_SLICE_DATA_WIDTH: integer := 4;
        OUTPUT_DATA_WIDTH: integer := 5;
        USE_CLOCK_EN: boolean := false
    );
    port(
        clk: in std_logic;
        rst_n: in std_logic;
        ce: in std_logic;
        d_i: in std_logic_vector(INPUT_DATA_WIDTH - 1 downto 0);
        d_o: out std_logic_vector(OUTPUT_DATA_WIDTH - 1 downto 0);
        z_o: out std_logic
    );
end entity;

architecture rtl of lopd is

    constant LOPD_SLICE_INDEX_WIDTH: positive := integer(
        ceil(log2(real(LOPD_SLICE_DATA_WIDTH - 1))));
    constant NUMBER_OF_LOPD_SLICES: positive := INPUT_DATA_WIDTH / LOPD_SLICE_DATA_WIDTH;

    component lopd_slice is
        generic (
            DATA_WIDTH: integer := 4
        );
        port (
            d_i: in std_logic_vector(DATA_WIDTH - 1 downto 0);
            d_o: out std_logic_vector(integer(ceil(log2(real(DATA_WIDTH - 1)))) - 1 downto 0);
            z_o: out std_logic
        );
    end component;

    subtype lopd_index_t is std_logic_vector(LOPD_SLICE_INDEX_WIDTH - 1 downto 0);
    subtype lopd_index_offset_t is std_logic_vector(OUTPUT_DATA_WIDTH - 1 downto 0);
    type lopd_array_slice_index_t is array (integer range <>) of lopd_index_t;
    type lopd_array_slice_index_offset_t is array (integer range <>) of lopd_index_offset_t;

    signal lopd_slice_index: lopd_array_slice_index_t(0 to NUMBER_OF_LOPD_SLICES - 1);
    signal lopd_slice_index_ofsset_reg: lopd_array_slice_index_offset_t(
        0 to NUMBER_OF_LOPD_SLICES - 1);
    signal lopd_slice_zflag, lopd_slice_zflag_reg: std_logic_vector(
        NUMBER_OF_LOPD_SLICES - 1 downto 0);
begin

    assert (INPUT_DATA_WIDTH mod LOPD_SLICE_DATA_WIDTH) = 0
        report "INPUT_DATA_WIDTH / LOPD_SLICE_DATA_WIDTH must be an integer"
        severity failure;

    dut_slice: for i in NUMBER_OF_LOPD_SLICES - 1 downto 0 generate

        lopd_slice_dut: lopd_slice
            generic map(
                DATA_WIDTH => LOPD_SLICE_DATA_WIDTH
            )
            port map(
                d_i => d_i((i + 1) * LOPD_SLICE_DATA_WIDTH - 1 downto i * LOPD_SLICE_DATA_WIDTH),
                d_o => lopd_slice_index(i),
                z_o => lopd_slice_zflag(i)
            );

            process(clk)
            begin
                if rising_edge(clk) then
                    if (not USE_CLOCK_EN) or ce = '1' then
                        lopd_slice_index_ofsset_reg(i) <= std_logic_vector(
                            unsigned(lopd_slice_index(i)) + to_unsigned(
                                i * LOPD_SLICE_DATA_WIDTH, lopd_slice_index_ofsset_reg(i)'length));
                        lopd_slice_zflag_reg(i) <= lopd_slice_zflag(i);
                    end if;

                    if rst_n = '0' then
                        lopd_slice_index_ofsset_reg(i) <= (others => '0');
                        lopd_slice_zflag_reg(i) <= '1';
                    end if;
                end if;
            end process;
        end generate dut_slice;

    process(clk)
    begin
        if rising_edge(clk) then
            if (not USE_CLOCK_EN) or ce = '1' then
                d_o <= (others => '0');

                for i in NUMBER_OF_LOPD_SLICES - 1 downto 0 loop
                    if lopd_slice_zflag_reg(i) = '0' then
                        d_o <= lopd_slice_index_ofsset_reg(i);
                        exit;
                    end if;
                end loop;

                z_o <= and_reduce(lopd_slice_zflag_reg);
            end if;

            if rst_n = '0' then
                d_o <= (others => '0');
                z_o <= '1';
            end if;
        end if;
    end process;
end rtl;
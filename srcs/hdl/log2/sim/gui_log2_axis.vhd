library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;
use std.env.all;

library work;
use work.log2_pkg_utils.all;
use work.axi4stream_model.all;

entity gui_log2_axis is
end entity;

architecture sim of gui_log2_axis is

    constant INTERFACE_TYPE: string := "AXI4_STREAM";
    constant STRATEGY: string := "LUT_LINEAR_INTRPL"; --"LUT_LINEAR_INTRPL"
    constant USE_DSP: boolean := false;
    constant INPUT_DATA_WIDTH: positive := 16;
    constant INPUT_FRACTION_WIDTH: positive := 8;
    constant OUTPUT_FRACTION_WIDTH: positive := 8;
    constant OUTPUT_DATA_WIDTH: positive := calc_out_data_width(INPUT_DATA_WIDTH,
        INPUT_FRACTION_WIDTH, OUTPUT_FRACTION_WIDTH);
    constant LUT_ADDR_SIZE: positive := 7;
    constant AXIS_DATA_WIDTH: positive := 16;

    constant INPUT_DATA_TKEEP_HIGH_WIDTH: positive := (INPUT_DATA_WIDTH + 7) / 8;
    constant OUTPUT_DATA_TKEEP_HIGH_WIDTH: positive := (OUTPUT_DATA_WIDTH + 7) / 8;

    constant CLOCK_PERIOD: time := 10 ns;

    signal clk: std_logic := '0';
    signal rst_n: std_logic := '0';

    signal s_axis_tdata: std_logic_vector(AXIS_DATA_WIDTH - 1 downto 0) := (others => '0');
    signal s_axis_tkeep: std_logic_vector(AXIS_DATA_WIDTH / 8 - 1 downto 0) := (others => '0');
    signal s_axis_tready: std_logic;
    signal s_axis_tvalid: std_logic := '0';

    signal m_axis_tdata: std_logic_vector(AXIS_DATA_WIDTH - 1 downto 0);
    signal m_axis_tkeep: std_logic_vector(AXIS_DATA_WIDTH / 8 - 1 downto 0);
    signal m_axis_tready: std_logic := '0';
    signal m_axis_tvalid: std_logic;

begin

    log2: entity work.log2_w
        generic map(
            INTERFACE_TYPE => INTERFACE_TYPE,
            AXIS_DATA_WIDTH => AXIS_DATA_WIDTH,
            STRATEGY => STRATEGY,
            USE_DSP => USE_DSP,
            INPUT_DATA_WIDTH => INPUT_DATA_WIDTH,
            INPUT_FRACTION_WIDTH => INPUT_FRACTION_WIDTH,
            OUTPUT_DATA_WIDTH => OUTPUT_DATA_WIDTH,
            OUTPUT_FRACTION_WIDTH => OUTPUT_FRACTION_WIDTH,
            LUT_ADDR_SIZE => LUT_ADDR_SIZE
        )
        port map(
            clk => clk,
            rst_n => rst_n,
            data_i => (others => '0'),
            valid_i => '0',
            s_axis_tdata => s_axis_tdata,
            s_axis_tkeep => s_axis_tkeep,
            s_axis_tready => s_axis_tready,
            s_axis_tvalid => s_axis_tvalid,
            m_axis_tdata => m_axis_tdata,
            m_axis_tkeep => m_axis_tkeep,
            m_axis_tready => m_axis_tready,
            m_axis_tvalid => m_axis_tvalid
        );

    clk <= not clk after CLOCK_PERIOD / 2;

    stimulus: process
        variable send_data: std_logic_vector(AXIS_DATA_WIDTH - 1 downto 0);
        variable send_keep: std_logic_vector(AXIS_DATA_WIDTH / 8 - 1 downto 0);
    begin
        rst_n <= '0';

        wait for 2 * CLOCK_PERIOD;

        rst_n <= '1';

        wait for 2 * CLOCK_PERIOD;

        for i in 1 to 10 loop
            send_data := std_logic_vector(to_unsigned(1664, send_data'length));
            send_keep := (INPUT_DATA_TKEEP_HIGH_WIDTH - 1 downto 0 => '1', others => '0');

            axis_send(clk, s_axis_tvalid, s_axis_tready, s_axis_tdata, s_axis_tkeep, send_data,
                send_keep);

            send_data := std_logic_vector(to_unsigned(65280, send_data'length));
            send_keep := (INPUT_DATA_TKEEP_HIGH_WIDTH - 1 downto 0 => '1', others => '0');

            axis_send(clk, s_axis_tvalid, s_axis_tready, s_axis_tdata, s_axis_tkeep, send_data,
                send_keep);

            send_data := std_logic_vector(to_unsigned(26, send_data'length));
            send_keep := (INPUT_DATA_TKEEP_HIGH_WIDTH - 1 downto 0 => '1', others => '0');

            axis_send(clk, s_axis_tvalid, s_axis_tready, s_axis_tdata, s_axis_tkeep, send_data,
                send_keep);
        end loop;

        wait;
    end process;

    monitor: process
        variable received_data: std_logic_vector(AXIS_DATA_WIDTH - 1 downto 0);
        variable received_keep: std_logic_vector(AXIS_DATA_WIDTH / 8 - 1 downto 0);
    begin
        wait until rst_n = '1';

        for i in 1 to 10 loop
            if i = 5 then
                wait for 5 * CLOCK_PERIOD;
            end if;

            axis_receive(clk, m_axis_tvalid, m_axis_tready, m_axis_tdata, m_axis_tkeep,
                received_data,
                received_keep);

            axis_receive(clk, m_axis_tvalid, m_axis_tready, m_axis_tdata, m_axis_tkeep,
                received_data,
                received_keep);

            axis_receive(clk, m_axis_tvalid, m_axis_tready, m_axis_tdata, m_axis_tkeep,
                received_data,
                received_keep);
        end loop;

        report "Testbench completed";
        finish;
    end process;

end sim;

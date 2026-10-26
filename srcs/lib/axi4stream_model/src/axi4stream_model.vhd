library ieee;
use ieee.std_logic_1164.all;

package axi4stream_model is
    procedure axis_send (
        signal clk: in std_logic;
        signal tvalid: out std_logic;
        signal tready: in std_logic;
        signal tdata: out std_logic_vector;
        signal tkeep: out std_logic_vector;
        constant data: in std_logic_vector;
        constant keep: in std_logic_vector;
        constant timeout_clk: in positive := 1000
    );

    procedure axis_receive (
        signal clk: in std_logic;
        signal tvalid: in std_logic;
        signal tready: out std_logic;
        signal tdata: in std_logic_vector;
        signal tkeep: in std_logic_vector;
        variable data: out std_logic_vector;
        variable keep: out std_logic_vector;
        constant timeout_clk: in positive := 1000
    );

    procedure axis_wait_cycles (
        signal clk: in std_logic;
        constant cycles: in natural
    );
end package axi4stream_model;

package body axi4stream_model is

    procedure axis_send (
        signal clk: in std_logic;
        signal tvalid: out std_logic;
        signal tready: in std_logic;
        signal tdata: out std_logic_vector;
        signal tkeep: out std_logic_vector;
        constant data: in std_logic_vector;
        constant keep: in std_logic_vector;
        constant timeout_clk: in positive := 1000
    ) is
        variable completed: boolean := false;
    begin
        assert data'length = tdata'length
            report "axis_send: data width does not match TDATA width"
            severity failure;

        assert keep'length = tkeep'length
            report "axis_send: keep width does not match TKEEP width"
            severity failure;

        wait until falling_edge(clk);

        tdata <= data;
        tkeep <= keep;
        tvalid <= '1';

        for cycle in 1 to timeout_clk loop
            wait until rising_edge(clk);
            if tready = '1' then
                completed := true;
                exit;
            end if;
        end loop;

        assert completed
            report "axis_send: timeout waiting for TREADY"
            severity failure;

        tvalid <= '0';
    end procedure;


    procedure axis_receive (
        signal clk: in std_logic;
        signal tvalid: in std_logic;
        signal tready: out std_logic;
        signal tdata: in std_logic_vector;
        signal tkeep: in std_logic_vector;
        variable data: out std_logic_vector;
        variable keep: out std_logic_vector;
        constant timeout_clk: in positive := 1000
    ) is
        variable completed: boolean := false;
    begin
        assert data'length = tdata'length
            report "axis_receive: data width does not match TDATA width"
            severity failure;

        assert keep'length = tkeep'length
            report "axis_receive: keep width does not match TKEEP width"
            severity failure;

        wait until falling_edge(clk);
        tready <= '1';

        for cycle in 1 to timeout_clk loop
            wait until rising_edge(clk);
            if tvalid = '1' then
                data := tdata;
                keep := tkeep;
                completed := true;
                exit;
            end if;
        end loop;

        assert completed
            report "axis_receive: timeout waiting for TVALID"
            severity failure;

        tready <= '0';
    end procedure;

    procedure axis_wait_cycles (
        signal clk: in std_logic;
        constant cycles: in natural
    ) is
    begin
        for cycle in 1 to cycles loop
            wait until rising_edge(clk);
        end loop;
    end procedure;

end package body axi4stream_model;
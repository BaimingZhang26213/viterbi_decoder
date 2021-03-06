--!
--! Copyright (C) 2011 - 2014 Creonic GmbH
--!
--! This file is part of the Creonic Viterbi Decoder, which is distributed
--! under the terms of the GNU General Public License version 2.
--!
--! @file
--! @brief  Viterbi decoder top entity, connecting all decoder units.
--! @author Markus Fehrenz
--! @date   2011/12/05
--!
--! @details
--! The AXI std_logic_vector input is mapped to an internal information type.
--! Further the correct output order is handled.
--!

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

library dec_viterbi;
use dec_viterbi.pkg_param.all;
use dec_viterbi.pkg_param_derived.all;
use dec_viterbi.pkg_types.all;
use dec_viterbi.pkg_components.all;
use dec_viterbi.pkg_trellis.all;


entity dec_viterbi is
	port(

	--
	-- The core only uses AXI4-Stream interfaces,
	-- based on AMBA4 AXI4-Stream Protocol with restrictions according to
	-- Xilinx Migration, described in Xilinx AXI Reference UG761 (v13.3).
	--

	aclk      : in std_logic;

	-- Synchronous reset, active low.
	aresetn   : in std_logic;


	--
	-- Slave (input) data signals
	-- Delivers the parity LLR values, one byte per LLR value.
	--
	s_axis_input_tvalid : in std_logic;
	s_axis_input_tdata  : in std_logic_vector(15 downto 0);
	s_axis_input_tuser  : in std_logic_vector(7 downto 0);
	s_axis_input_tready : out std_logic;


	--
	-- Master (output) data signals
	-- Delivers the decoded systematic (payload) bits.
	--
	m_axis_output_tvalid : out std_logic;
	m_axis_output_tdata  : out std_logic_vector(7 downto 0)
);
end entity dec_viterbi;


architecture rtl of dec_viterbi is

	alias clk is aclk;
	signal rst : std_logic;
	signal rst_dly : std_logic;
	
	-- split tdata into input array
	signal input : t_input_block;
	signal input_tllr : std_logic_vector(15 downto 0);

	-- buffer signals
	signal buffer_tdata  : std_logic_vector(15 downto 0);
	signal buffer_tvalid : std_logic;
	signal s_axis_input_tvalid_buffer: std_logic;

	-- branch signals
	signal branch_tvalid  : std_logic_vector(NUMBER_BRANCH_UNITS - 1 downto 0);
	signal branch_tdata   : t_branch;
	signal branch_tready  : std_logic_vector(NUMBER_BRANCH_UNITS - 1 downto 0);

	-- acs signals
	signal acs_tvalid     : std_logic_vector(NUMBER_TRELLIS_STATES - 1 downto 0);
	signal acs_tready     : std_logic_vector(NUMBER_TRELLIS_STATES - 1 downto 0);
	signal acs_dec_tdata  : std_logic_vector(NUMBER_TRELLIS_STATES - 1 downto 0);
	signal acs_prob_tdata : t_node;

	-- ram signals
	signal ram_tready                             : std_logic;
	signal ram_tvalid, ram_window_tuser, ram_last_tuser : std_logic_vector(1 downto 0);
	signal ram_tdata                                               : t_ram_rd_data;

	-- traceback signals
	signal traceback_tvalid, traceback_tdata : std_logic_vector(1 downto 0);
	signal traceback_tready : std_logic_vector(1 downto 0);
	signal traceback_last_tuser              : std_logic_vector(1 downto 0);

	-- reorder signals
	signal reorder_tready, reorder_tvalid : std_logic_vector(1 downto 0);
	signal reorder_tdata   : std_logic_vector(1 downto 0);
	signal reorder_last_tuser             : std_logic_vector(1 downto 0);

	-- output signals
	signal output_tready : std_logic_vector(1 downto 0);
	signal current_active : integer range 1 downto 0;
	signal m_axis_output_tready : std_logic := '1';
    begin

	--
	-- There is always one byte of data for each LLR value, even though each
	-- LLR value is represented with BW_LLR_INPUT bits. Hence, only
	-- BW_LLR_INPUT bits are extracted from the byte.
	--
	gen_input_assignment: for i in NUMBER_PARITY_BITS - 1 downto 0 generate
	begin
		input(1 - i) <= signed(buffer_tdata(8 * i + BW_LLR_INPUT - 1 downto 8 * i));
	end generate gen_input_assignment;

	rst <= not aresetn;

	------------------------------
	--- Portmapping components ---
	------------------------------

	-------------------------------------
	-- AXI4S input buffer
	--------------------------------------
	gen_llr : for i in NUMBER_PARITY_BITS - 1 downto 0 generate
	begin
    input_tllr(8 * i + BW_LLR_INPUT - 1) <= s_axis_input_tdata(8 * i + BW_LLR_INPUT - 2) when s_axis_input_tuser(i) = '0' else
	                                          '1';
	input_tllr(8 * i + BW_LLR_INPUT - 2 downto 8 * i + 1) <= (others =>'1') when s_axis_input_tuser(i) = '1' else
	                                                          NOT s_axis_input_tdata(8 * i + BW_LLR_INPUT - 3 downto 8 * i) when s_axis_input_tdata(8 * i + BW_LLR_INPUT - 2) = '1' else
	                                                          s_axis_input_tdata(8 * i + BW_LLR_INPUT - 3 downto 8 * i);
	input_tllr(8 * i) <= '1' when s_axis_input_tuser(i) = '1' else '0';
	end generate gen_llr;
	
	s_axis_input_tvalid_buffer <= s_axis_input_tvalid and (NOT rst_dly);
	inst_axi4s_buffer: axi4s_buffer
	generic map(
		DATA_WIDTH => 16
	)
	port map(
		clk => clk,
		rst => rst,

		input        => input_tllr,
		input_valid  => s_axis_input_tvalid_buffer,
		input_accept => s_axis_input_tready,

		output        => buffer_tdata,
		output_valid  => buffer_tvalid,
		output_accept => branch_tready(0)
	);

	-------------------------------------
	-- Branch metric unit
	--------------------------------------

	gen_branch_distance : for i in NUMBER_BRANCH_UNITS - 1 downto 0 generate
	begin
		inst_branch_distance : branch_distance
		generic map(
			EDGE_WEIGHT => std_logic_vector(to_unsigned(i, NUMBER_PARITY_BITS))
		)
		port map(
			clk => clk,
			rst => rst,

			s_axis_input_tvalid  => buffer_tvalid,
			s_axis_input_tdata   => input,
			s_axis_input_tready  => branch_tready(i),
	
			m_axis_output_tvalid => branch_tvalid(i),
			m_axis_output_tdata  => branch_tdata(i),
			m_axis_output_tready => acs_tready(0)
		);
	end generate gen_branch_distance;


	-------------------------------------
	-- ACS unit (path metric calculation)
	--------------------------------------

	gen_acs : for i in 0 to NUMBER_TRELLIS_STATES - 1 generate
		signal inbranch_tdata_low  : std_logic_vector(BW_BRANCH_RESULT - 1 downto 0);
		signal inbranch_tdata_high : std_logic_vector(BW_BRANCH_RESULT - 1 downto 0);
		signal inprev_tdata_low  : std_logic_vector(BW_MAX_PROBABILITY - 1 downto 0);
		signal inprev_tdata_high : std_logic_vector(BW_MAX_PROBABILITY - 1 downto 0);
	begin
		inbranch_tdata_low  <= branch_tdata(to_integer(unsigned(TRANSITIONS(i)(0))));
		inbranch_tdata_high <= branch_tdata(to_integer(unsigned(TRANSITIONS(i)(1))));
		inprev_tdata_low    <= acs_prob_tdata(to_integer(unsigned(PREVIOUS_STATES(i)(0))));
		inprev_tdata_high   <= acs_prob_tdata(to_integer(unsigned(PREVIOUS_STATES(i)(1))));

		inst_acs : acs
		generic map(
			initialize_value => INITIALIZE_TRELLIS(i)
		)
		port map(
			clk => clk,
			rst => rst,

			s_axis_inbranch_tvalid     => branch_tvalid(0),
			s_axis_inbranch_tdata_low  => inbranch_tdata_low,
			s_axis_inbranch_tdata_high => inbranch_tdata_high,
			s_axis_inbranch_tready     => acs_tready(i),
	
			s_axis_inprev_tvalid     => '1',
			s_axis_inprev_tdata_low  => inprev_tdata_low,
			s_axis_inprev_tdata_high => inprev_tdata_high,
			s_axis_inprev_tready     => open,
	
			m_axis_outprob_tvalid  => open,
			m_axis_outprob_tdata   => acs_prob_tdata(i),
			m_axis_outprob_tready  => '1',
	
			m_axis_outdec_tvalid   => acs_tvalid(i),
			m_axis_outdec_tdata    => acs_dec_tdata(i),
			m_axis_outdec_tready   => ram_tready
		);
	end generate gen_acs;


	-------------------------------
	-- Traceback
	-------------------------------

	inst_ram_ctrl : ram_ctrl
	port map (
		clk => clk,
		rst => rst,

		s_axis_input_tvalid => acs_tvalid(0),
		s_axis_input_tdata  => acs_dec_tdata,
		s_axis_input_tready => ram_tready,

		m_axis_output_tvalid       => ram_tvalid,
		m_axis_output_tdata        => ram_tdata,
		m_axis_output_tready       => traceback_tready,
		m_axis_output_window_tuser => ram_window_tuser,
		m_axis_output_last_tuser   => ram_last_tuser
	);


	gen_inst_trellis_traceback : for i in 1 downto 0 generate
	begin
		inst_trellis_traceback : trellis_traceback
		port map(
			clk => clk,
			rst => rst,
	
			s_axis_input_tvalid       => ram_tvalid(i),
			s_axis_input_tdata        => ram_tdata(i),
			s_axis_input_tready       => traceback_tready(i),
			s_axis_input_window_tuser => ram_window_tuser(i),
			s_axis_input_last_tuser   => ram_last_tuser(i),
	
			m_axis_output_tvalid     => traceback_tvalid(i),
			m_axis_output_tdata      => traceback_tdata(i),
			m_axis_output_last_tuser => traceback_last_tuser(i),
			m_axis_output_tready     => reorder_tready(i)
		);
	end generate gen_inst_trellis_traceback;


	-------------------------------
	-- Reverse output order
	-------------------------------

	gen_inst_reorder : for i in 1 downto 0 generate
	begin
		inst_reorder : reorder
		port map(
			clk => clk,
			rst => rst,
	
			s_axis_input_tvalid     => traceback_tvalid(i),
			s_axis_input_tdata      => traceback_tdata(i),
			s_axis_input_last_tuser => traceback_last_tuser(i),
			s_axis_input_tready     => reorder_tready(i),
	
			m_axis_output_tvalid     => reorder_tvalid(i),
			m_axis_output_tdata      => reorder_tdata(i),
			m_axis_output_last_tuser => reorder_last_tuser(i),
			m_axis_output_tready     => output_tready(i)
		);
	end generate gen_inst_reorder;


	------------------------------
	-- Recursive codes handling --
	------------------------------

	gen_inst_recursion : if FEEDBACK_POLYNOMIAL /= 0 generate
		signal reorder_recursion_tvalid : std_logic;
		signal reorder_recursion_tdata  : std_logic;
		signal recursion_tready         : std_logic;
	begin
		inst_recursion : recursion
		port map(
			clk => clk,
			rst => rst,
	
			s_axis_input_tvalid     => reorder_recursion_tvalid,
			s_axis_input_tdata      => reorder_recursion_tdata,
			s_axis_input_tready     => recursion_tready,
	
			m_axis_output_tvalid     => m_axis_output_tvalid,
			--m_axis_output_tdata      => m_axis_output_tdata,
			m_axis_output_tready     => m_axis_output_tready
		);

		-------------------------------
		-- Output interface handling
		-------------------------------

		reorder_recursion_tvalid <= '1' when reorder_tvalid(0) = '1' or reorder_tvalid(1) = '1' else
		                            '0';

		reorder_recursion_tdata  <= reorder_tdata(0) when current_active = 0 else
		                            reorder_tdata(1);

		output_tready(0) <= '1' when (current_active = 0) and m_axis_output_tready = '1' else
		                    '0';
		output_tready(1) <= '1' when (current_active = 1) and m_axis_output_tready = '1' else
		                    '0';
	end generate gen_inst_recursion;



	no_recursion: if FEEDBACK_POLYNOMIAL = 0 generate

		-------------------------------
		-- Output interface handling
		-------------------------------

		m_axis_output_tdata(0)  <= reorder_tdata(0) when current_active = 0 else
		                        reorder_tdata(1);

		m_axis_output_tvalid <= '1' when reorder_tvalid(0) = '1' or reorder_tvalid(1) = '1' else
		                        '0';

		output_tready(0) <= '1' when (current_active = 0) and m_axis_output_tready = '1' else
		                    '0';
		output_tready(1) <= '1' when (current_active = 1) and m_axis_output_tready = '1' else
		                    '0';
	end generate no_recursion;


	recursion : if FEEDBACK_POLYNOMIAL /= 0 generate
	begin
	end generate recursion;


	-- Check and merge reordering outputs and block if necessary.
	pr_reorder_tready : process(clk) is
	begin
	if rising_edge(clk) then
		if rst = '1' then
			current_active <= 0;
		else
			if reorder_tvalid(current_active) = '1' and m_axis_output_tready = '1' and reorder_last_tuser(current_active) = '1' then
				current_active <= 1 - current_active;
			end if;
		end if;
		rst_dly <= rst;
	end if;
	end process pr_reorder_tready;

end architecture rtl;

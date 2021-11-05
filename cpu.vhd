-- cpu.vhd: Simple 8-bit CPU (BrainLove interpreter)
-- Copyright (C) 2021 Brno University of Technology,
--                    Faculty of Information Technology
-- Author(s): DOPLNIT
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

-- ----------------------------------------------------------------------------
--                        Entity declaration
-- ----------------------------------------------------------------------------
entity cpu is
 port (
   CLK   : in std_logic;  -- hodinovy signal
   RESET : in std_logic;  -- asynchronni reset procesoru
   EN    : in std_logic;  -- povoleni cinnosti procesoru
 
   -- synchronni pamet ROM
   CODE_ADDR : out std_logic_vector(11 downto 0); -- adresa do pameti
   CODE_DATA : in std_logic_vector(7 downto 0);   -- CODE_DATA <- rom[CODE_ADDR] pokud CODE_EN='1'
   CODE_EN   : out std_logic;                     -- povoleni cinnosti
   
   -- synchronni pamet RAM
   DATA_ADDR  : out std_logic_vector(9 downto 0); -- adresa do pameti
   DATA_WDATA : out std_logic_vector(7 downto 0); -- ram[DATA_ADDR] <- DATA_WDATA pokud DATA_EN='1'
   DATA_RDATA : in std_logic_vector(7 downto 0);  -- DATA_RDATA <- ram[DATA_ADDR] pokud DATA_EN='1'
   DATA_WREN  : out std_logic;                    -- cteni z pameti (DATA_WREN='0') / zapis do pameti (DATA_WREN='1')
   DATA_EN    : out std_logic;                    -- povoleni cinnosti
   
   -- vstupni port
   IN_DATA   : in std_logic_vector(7 downto 0);   -- IN_DATA obsahuje stisknuty znak klavesnice pokud IN_VLD='1' a IN_REQ='1'
   IN_VLD    : in std_logic;                      -- data platna pokud IN_VLD='1'
   IN_REQ    : out std_logic;                     -- pozadavek na vstup dat z klavesnice
   
   -- vystupni port
   OUT_DATA : out  std_logic_vector(7 downto 0);  -- zapisovana data
   OUT_BUSY : in std_logic;                       -- pokud OUT_BUSY='1', LCD je zaneprazdnen, nelze zapisovat,  OUT_WREN musi byt '0'
   OUT_WREN : out std_logic                       -- LCD <- OUT_DATA pokud OUT_WREN='1' a OUT_BUSY='0'
 );
end cpu;


-- ----------------------------------------------------------------------------
--                      Architecture declaration
-- ----------------------------------------------------------------------------
architecture behavioral of cpu is

 -- zde dopiste potrebne deklarace signalu
 
	-- PC Programový èítaè
	signal PC_reg : std_logic_vector(11 downto 0);
	signal PC_inc : std_logic;
	signal PC_dec : std_logic;
	
	-- PTR Ukazatel do pamìti dat
	signal PTR_reg : std_logic_vector(9 downto 0);
	signal PTR_inc : std_logic;
	signal PTR_dec : std_logic;
	
	-- CNT Urèení zaèátku/konce cyklu while
	signal CNT_reg : std_logic_vector(11 downto 0);
	signal CNT_inc : std_logic;
	signal CNT_dec : std_logic;
	
	-- MX ktery ridi hodnotuu zapisovanou do pameti RAM
	signal MX_data_wdata : std_logic_vector(7 downto 0);
	signal selection : std_logic_vector(1 downto 0);
	
	type instruction_type is (
		iptr_inc,
		iptr_dec,
		ival_inc,
		ival_dec,
		ival_print,
		ival_get,
		iwhile_start,
		iwhile_break,
		iwhile_end,
		ichar_put,
		ichar_get,
		inst_end,
		iother
	);
	
	signal instruction : instruction_type;
	
	type FSM_state is (
		state_idle,
		state_fetch,
		state_decode,
		state_inc_ptr,
		state_dec_ptr,
		state_inc_read,
		state_inc_write, state_inc_write_1,
		state_dec_read,
		state_dec_write, state_dec_write_1,
		state_put_0, state_put_1,
		state_get_0, state_get_1,
		state_while_0, state_while_1, state_while_2, state_while_3,
		state_while_end_0, state_while_end_1, state_while_end_2, state_while_end_3, state_while_end_4, state_while_end_5,
		state_while_break_0, state_while_break_1, state_while_break_2,
		state_end,
		other
	);
	
	signal FSM_act_state : FSM_state := state_idle;
	signal FSM_next_state : FSM_state;

	
begin

	-- Programovy citac PC
	PC_counter: process (CLK, RESET, PC_inc, PC_dec)
	begin
		if RESET = '1' then
			PC_reg <= (others => '0');
		elsif rising_edge(CLK) then
			if PC_inc = '1' then
				PC_reg <= PC_reg + 1;
			elsif PC_dec = '1' then
				PC_reg <= PC_reg - 1;
			end if;
		end if;
	end process;
	
	CODE_ADDR <= PC_reg;
	
	-- Registr PTR
	PTR_counter: process (CLK, RESET, PTR_inc, PTR_dec)
	begin
		if RESET = '1' then
			PTR_reg <= (others => '0');
		elsif rising_edge(CLK) then
			if PTR_inc = '1' then
				PTR_reg <= PTR_reg + 1;
			elsif PTR_dec = '1' then
				PTR_reg <= PTR_reg - 1;
			end if;
		end if;
	end process;
	
	DATA_ADDR <= PTR_reg;
	
	-- Registr CNT
	CNT_counter: process (CLK, RESET, PTR_inc, PTR_dec)
	begin
		if RESET = '1' then
			CNT_reg <= (others => '0');
		elsif rising_edge(CLK) then
			if CNT_inc = '1' then
				CNT_reg <= CNT_reg + 1;
			elsif CNT_dec = '1' then
				CNT_reg <= CNT_reg - 1;
			end if;
		end if;
	end process;
	
	OUT_DATA <= DATA_RDATA;
	
	-- Multiplexor
	MX_data_wdata_processor : process (CLK, RESET)
	begin
		if RESET = '1' then
			MX_data_wdata <= (others => '0');
		elsif rising_edge(CLK) then
			case selection is
				when "00" => DATA_WDATA <= IN_DATA;
				when "01" => DATA_WDATA <= DATA_RDATA + 1;
				when "10" => DATA_WDATA <= DATA_RDATA - 1;
				when others => DATA_WDATA <= (others => '0');
			end case;
		end if;
	end process;
	
	-- Decoder
	process_decoder: process (CODE_DATA)
	begin
		case (CODE_DATA) is
			when X"3E" => instruction <= iptr_inc;
			when X"3C" => instruction <= iptr_dec;
			when X"2B" => instruction <= ival_inc;
			when X"2D" => instruction <= ival_dec;
			when X"2E" => instruction <= ichar_put;
			when X"2C" => instruction <= ichar_get;
			when X"5B" => instruction <= iwhile_start;
			when X"7E" => instruction <= iwhile_break;
			when X"5D" => instruction <= iwhile_end;
			when X"00" => instruction <= inst_end;
			when others => instruction <= iother;
		end case;
	end process;
	
	-- FSM aktualni stav
	FSM_act_state_processor : process (CLK, RESET, EN)
	begin
		if RESET = '1' then
			FSM_act_state <= state_idle;
		elsif rising_edge(CLK) and (EN = '1') then
			FSM_act_state <= FSM_next_state;
		end if;
	end process;
	
	-- FSM dalsi stav
	FSM_next_state_processor : process (CLK, RESET, EN, FSM_act_state, OUT_BUSY, IN_VLD, CODE_DATA, CNT_reg, DATA_RDATA)
	begin
		CODE_EN <= '0';
		DATA_EN <= '0';
		DATA_WREN <= '0';
		OUT_WREN <= '0';
		IN_REQ <= '0';
		PC_inc <= '0';
		PC_dec <= '0';
		PTR_inc <= '0';
		PTR_dec <= '0';
		CNT_inc <= '0';
		CNT_dec <= '0';
		selection <= "00";

		case FSM_act_state is
			
			when state_idle => FSM_next_state <= state_fetch;
			
			when state_fetch =>
				CODE_EN <= '1';
				FSM_next_state <= state_decode;
				
			when state_decode =>
				case instruction is
					when iptr_inc => FSM_next_state <= state_inc_ptr;
					when iptr_dec => FSM_next_state <= state_dec_ptr;
					when ival_inc => FSM_next_state <= state_inc_read;
					when ival_dec => FSM_next_state <= state_dec_read;
					when ichar_put => FSM_next_state <= state_put_0;
					when ichar_get => FSM_next_state <= state_get_0;
					when iwhile_start => FSM_next_state <= state_while_0;
					when iwhile_break => FSM_next_state <= state_inc_ptr;
					when iwhile_end => FSM_next_state <= state_while_end_0;
					when inst_end => FSM_next_state <= state_end;
					when others => FSM_next_state <= other;
				end case;
			
			-- ptr increment
			when state_inc_ptr =>
				PTR_inc <= '1';
				PC_inc <= '1';
				FSM_next_state <= state_fetch;
			
			-- ptr decrement
			when state_dec_ptr =>
				PTR_dec <= '1';
				PC_inc <= '1';
				FSM_next_state <= state_fetch;
				
			-- value increment
			when state_inc_read =>
				DATA_WREN <= '0';
				DATA_EN <= '1';
				FSM_next_state <= state_inc_write;
			when state_inc_write =>
				selection <= "01";
				FSM_next_state <= state_inc_write_1;
			when state_inc_write_1 =>
				DATA_EN <= '1';
				DATA_WREN <= '1';
				PC_inc <= '1';
				FSM_next_state <= state_fetch;
				
				
			-- value decrement
			when state_dec_read =>
				DATA_WREN <= '0';
				DATA_EN <= '1';
				FSM_next_state <= state_dec_write;
			when state_dec_write =>
				selection <= "10";
				FSM_next_state <= state_dec_write_1;
			when state_dec_write_1 =>
				DATA_EN <= '1';
				DATA_WREN <= '1';
				PC_inc <= '1';
				FSM_next_state <= state_fetch;
				
			-- put char
			when state_put_0 =>
				DATA_EN <= '1';
				DATA_WREN <= '0';
				FSM_next_state <= state_put_1;
			when state_put_1 =>
				if OUT_BUSY = '1' then
					FSM_next_state <= state_put_0;
				else
					OUT_WREN <= '1';
					PC_inc <= '1';
					FSM_next_state <= state_fetch;
				end if;
			
			-- get char
			when state_get_0 =>
				IN_REQ <= '1';
				selection <= "00";
				FSM_next_state <= state_get_1;
			when state_get_1 =>
				if IN_VLD /= '1' then
					FSM_next_state <= state_get_0;
				else
					DATA_EN <= '1';
					DATA_WREN <= '1';
					PC_inc <= '1';
					FSM_next_state <= state_fetch;
				end if;
				
			-- while start
			when state_while_0 =>
				DATA_EN <= '1';
				DATA_WREN <= '0';
				PC_inc <= '1';
				FSM_next_state <= state_while_1;
			when state_while_1 =>
				if DATA_RDATA /= (DATA_RDATA'range => '0') then
					FSM_next_state <= state_fetch;
				else 
					CNT_inc <= '1';
					FSM_next_state <= state_while_3;
				end if;
			when state_while_2 =>
				if CNT_reg = (CNT_reg'range =>'0') then
					FSM_next_state <= state_fetch;
				else
					if (instruction = iwhile_start) then
						CNT_inc <= '1';
					elsif (instruction = iwhile_end) then
						CNT_dec <= '1';
					end if;
					PC_inc <= '1';
					FSM_next_state <= state_while_3;
				end if;
			when state_while_3 =>
				CODE_EN <= '1';
				FSM_next_state <= state_while_2;
				
			-- while end
			when state_while_end_0 =>
				DATA_EN <= '1';
				DATA_WREN <= '0';
				FSM_next_state <= state_while_end_1;
			when state_while_end_1 =>
				if DATA_RDATA = (DATA_RDATA'range => '0') then
					PC_inc <= '1';
					FSM_next_state <= state_fetch;
				else
					CNT_inc <= '1';
					PC_dec <= '1';
					FSM_next_state <= state_while_end_4;
				end if;
			when state_while_end_2 =>
				if CNT_reg = (CNT_reg'range =>'0') then
					FSM_next_state <= state_fetch;
				else
					if (instruction = iwhile_end) then
						CNT_inc <= '1';
					elsif (instruction = iwhile_start) then
						CNT_dec <= '1';
					end if;
					FSM_next_state <= state_while_end_3;
				end if;
			when state_while_end_3 =>
				if CNT_reg = (CNT_reg'range =>'0') then
					PC_inc <= '1';
				else
					PC_dec <= '1';
				end if;
				FSM_next_state <= state_while_end_4;
			when state_while_end_4 =>
				CODE_EN <= '1';
				FSM_next_state <= state_while_end_2;
				
			-- while break
			when state_while_break_0 =>
				CNT_inc <= '1';
				PC_inc <= '1';
				FSM_next_state <= state_while_break_2;
			when state_while_break_1 =>
				if CNT_reg = (CNT_reg'range =>'0') then
					FSM_next_state <= state_fetch;
				else
					if CODE_DATA = X"5B" then
						CNT_inc <= '1';
					elsif CODE_DATA = X"5D" then
						CNT_dec <= '1';
					end if;
				end if;
				PC_inc <= '1';
				FSM_next_state <= state_while_break_2;
			when state_while_break_2 =>
				CODE_EN <= '1';
				FSM_next_state <= state_while_break_1;
				
			-- end
			when state_end =>
				FSM_next_state <= state_end;
			
			when other =>
				FSM_next_state <= state_fetch;
				PC_inc <= '1';
			when others =>
				FSM_next_state <= state_fetch;
				PC_inc <= '1';
				
		end case;
	end process;
 end behavioral;
 

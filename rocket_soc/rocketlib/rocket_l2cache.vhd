-----------------------------------------------------------------------------
--! @file
--! @copyright  Copyright 2015 GNSS Sensor Ltd. All right reserved.
--! @author     Sergey Khabarov - sergeykhbr@gmail.com
--! @brief      RISC-V "Rocket Core" with enabled L2-cache.
------------------------------------------------------------------------------
--! Standard library
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

--! Data transformation and math functions library
library commonlib;
use commonlib.types_common.all;

--! Technology definition library.
library techmap;
--! Technology constants definition.
use techmap.gencomp.all;

--! AMBA system bus specific library.
library ambalib;
--! AXI4 configuration constants.
use ambalib.types_amba4.all;

--! Rocket-chip specific library
library rocketlib;
--! TileLink interface description.
use rocketlib.types_rocket.all;


--! @brief   Rocket Chip Top-level with enabled L2-cache.
--! @param[in] xindex1 Cached Tile AXI master index
--! @param[in] xindex2 Uached Tile AXI master index
--! @param[in] rst     Reset.Active High. Usually assigned to button "Center".
--! @param[in] clk_sys System clock.
--! @param[in] clk_htif HTIF bus clock.
--! @param[in] msti    AXI System bus response.
--! @param[out] msto1  Cached Tile requests converted to AXI system bus.
--! @param[out] msto2  Uncached Tile requests converted to AXI system bus.
--! @param[in]  htifo  HTIF bus request bus. Device-to-Tile.
--! @param[out] htifi  HTIF bus response bus. Tile-to-Device
entity rocket_l2cache is 
generic (
    xindex1 : integer := 0;
    xindex2 : integer := 0
);
port 
( 
    rst      : in std_logic;
    clk_sys  : in std_logic;
    slvo     : in nasti_slave_in_type;
    msti     : in nasti_master_in_type;
    msto1    : out nasti_master_out_type;
    mstcfg1  : out nasti_master_config_type;
    msto2    : out nasti_master_out_type;
    mstcfg2  : out nasti_master_config_type;
    htifoi    : in host_out_type;
    htifio    : out host_in_type
);
  --! @}

end rocket_l2cache;

--! @brief Rocket-chip with L2-cache  architecture declaration.
architecture arch_rocket_l2cache of rocket_l2cache is

  constant xmstconfig1 : nasti_master_config_type := (
     xindex => xindex1,
     vid => VENDOR_GNSSSENSOR,
     did => RISCV_CACHED_TILELINK,
     descrtype => PNP_CFG_TYPE_MASTER,
     descrsize => PNP_CFG_MASTER_DESCR_BYTES
  );

  constant xmstconfig2 : nasti_master_config_type := (
     xindex => xindex2,
     vid => VENDOR_GNSSSENSOR,
     did => RISCV_UNCACHED_TILELINK,
     descrtype => PNP_CFG_TYPE_MASTER,
     descrsize => PNP_CFG_MASTER_DESCR_BYTES
  );

  signal rstn : std_logic;
  signal init_ena : std_logic;

  --! Multiplexed signal of the external HTIF requests and of the
  --! 'starter' module. 
  signal htifo_starter : host_out_type;
  signal htifo_mux : host_out_type;
  signal htifi_deser : host_in_type;
  signal clk_htif : std_logic;
      
  signal cpu2htif    : htif_serdes_in_type;
  signal htif2cpu    : htif_serdes_out_type;
  
  --! @brief   Rocket Cores hard-reset initialization module
  --! @details Everytime after hard reset Rocket core is in resetting
  --!          state. Module Uncore::HTIF implements writting into 
  --!          MRESET CSR-register (0x784) and not allowed to CPU start
  --!          execution. This reseting cycle is continuing upto external
  --!          write 0-value into this MRESET register.
  --! param[in]  core_idx  Recipient core index. Multicore not implemented yet.
  --! param[in]  clk   Clock sinal for the HTIFIO bus.
  --! param[in]  nrst  Module reset signal with the active Low level.
  --! param[in]  hosti HostIO interface input signals.
  --! param[out] hosto HostIO interface output signals.
  --! param[in]  srdi  HostIO serialized data input.
  --! param[out] srdo  HostIO serialized data output.
  component htif_serdes is
  generic (
     core_idx : integer := 0
  );
  port (
    clk   : in std_logic;
    nrst  : in std_logic;
    hostoi : in host_out_type;
    hostio : out host_in_type;
    srdi  : in htif_serdes_in_type;
    srdo  : out htif_serdes_out_type
  );
  end component;

  
  --! @brief   Hard-reset 'Uncore' initializer.
  --! @details Rocket-chip is constantly reseting after power-up to start
  --!          execution we must write into MRESET CSR register.
  component starter is port 
  (
    clk   : in std_logic;
    nrst  : in std_logic;
    i_host : in host_in_type;
    o_host : out host_out_type;
    o_init_ena : out std_logic
  );
  end component;
  
  --! @brief Rocket NoC Verilog implementation generated by SCALA.
  component Top
  port (
    clk : in std_logic;
    reset : in std_logic;
    io_host_clk : out std_logic;
    io_host_clk_edge : out std_logic;
    io_host_in_ready : out std_logic;
    io_host_in_valid : in std_logic;
    io_host_in_bits : in std_logic_vector(15 downto 0);
    io_host_out_ready : in std_logic;
    io_host_out_valid : out std_logic;
    io_host_out_bits : out std_logic_vector(15 downto 0);
    io_host_debug_stats_csr : out std_logic;
    io_mem_backup_ctrl_en : in std_logic;
    io_mem_backup_ctrl_in_valid : in std_logic;
    io_mem_backup_ctrl_out_ready : in std_logic;
    io_mem_backup_ctrl_out_valid : out std_logic;
    io_mem_0_aw_ready : in std_logic;
    io_mem_0_aw_valid : out std_logic;
    io_mem_0_aw_bits_addr : out std_logic_vector(31 downto 0);
    io_mem_0_aw_bits_len : out std_logic_vector(7 downto 0);
    io_mem_0_aw_bits_size : out std_logic_vector(2 downto 0);
    io_mem_0_aw_bits_burst : out std_logic_vector(1 downto 0);
    io_mem_0_aw_bits_lock : out std_logic;
    io_mem_0_aw_bits_cache : out std_logic_vector(3 downto 0);
    io_mem_0_aw_bits_prot : out std_logic_vector(2 downto 0);
    io_mem_0_aw_bits_qos : out std_logic_vector(3 downto 0);
    io_mem_0_aw_bits_region : out std_logic_vector(3 downto 0);
    io_mem_0_aw_bits_id : out std_logic_vector(CFG_ROCKET_ID_BITS-1 downto 0);
    io_mem_0_aw_bits_user : out std_logic;
    io_mem_0_w_ready : in std_logic;
    io_mem_0_w_valid : out std_logic;
    io_mem_0_w_bits_data : out std_logic_vector(127 downto 0);
    io_mem_0_w_bits_last : out std_logic;
    io_mem_0_w_bits_strb : out std_logic_vector(15 downto 0);
    io_mem_0_w_bits_user : out std_logic;
    io_mem_0_b_ready : out std_logic;
    io_mem_0_b_valid : in std_logic;
    io_mem_0_b_bits_resp : in std_logic_vector(1 downto 0);
    io_mem_0_b_bits_id : in std_logic_vector(CFG_ROCKET_ID_BITS-1 downto 0);
    io_mem_0_b_bits_user : in std_logic;
    io_mem_0_ar_ready : in std_logic;
    io_mem_0_ar_valid : out std_logic;
    io_mem_0_ar_bits_addr : out std_logic_vector(31 downto 0);
    io_mem_0_ar_bits_len : out std_logic_vector(7 downto 0);
    io_mem_0_ar_bits_size : out std_logic_vector(2 downto 0);
    io_mem_0_ar_bits_burst : out std_logic_vector(1 downto 0);
    io_mem_0_ar_bits_lock : out std_logic;
    io_mem_0_ar_bits_cache : out std_logic_vector(3 downto 0);
    io_mem_0_ar_bits_prot : out std_logic_vector(2 downto 0);
    io_mem_0_ar_bits_qos : out std_logic_vector(3 downto 0);
    io_mem_0_ar_bits_region : out std_logic_vector(3 downto 0);
    io_mem_0_ar_bits_id : out std_logic_vector(CFG_ROCKET_ID_BITS-1 downto 0);
    io_mem_0_ar_bits_user : out std_logic;
    io_mem_0_r_ready : out std_logic;
    io_mem_0_r_valid : in std_logic;
    io_mem_0_r_bits_resp : in std_logic_vector(1 downto 0);
    io_mem_0_r_bits_data : in std_logic_vector(127 downto 0);
    io_mem_0_r_bits_last : in std_logic;
    io_mem_0_r_bits_id : in std_logic_vector(CFG_ROCKET_ID_BITS-1 downto 0);
    io_mem_0_r_bits_user : in std_logic;
    --! mmio 
    io_mmio_aw_ready : in std_logic;
    io_mmio_aw_valid : out std_logic;
    io_mmio_aw_bits_addr : out std_logic_vector(31 downto 0);
    io_mmio_aw_bits_len : out std_logic_vector(7 downto 0);
    io_mmio_aw_bits_size : out std_logic_vector(2 downto 0);
    io_mmio_aw_bits_burst : out std_logic_vector(1 downto 0);
    io_mmio_aw_bits_lock : out std_logic;
    io_mmio_aw_bits_cache : out std_logic_vector(3 downto 0);
    io_mmio_aw_bits_prot : out std_logic_vector(2 downto 0);
    io_mmio_aw_bits_qos : out std_logic_vector(3 downto 0);
    io_mmio_aw_bits_region : out std_logic_vector(3 downto 0);
    io_mmio_aw_bits_id : out std_logic_vector(CFG_ROCKET_ID_BITS-1 downto 0);
    io_mmio_aw_bits_user : out std_logic;
    io_mmio_w_ready : in std_logic;
    io_mmio_w_valid : out std_logic;
    io_mmio_w_bits_data : out std_logic_vector(CFG_NASTI_DATA_BITS-1 downto 0);
    io_mmio_w_bits_last : out std_logic;
    io_mmio_w_bits_strb : out std_logic_vector(15 downto 0);
    io_mmio_w_bits_user : out std_logic;
    io_mmio_b_ready : out std_logic;
    io_mmio_b_valid : in std_logic;
    io_mmio_b_bits_resp : in std_logic_vector(1 downto 0);
    io_mmio_b_bits_id : in std_logic_vector(CFG_ROCKET_ID_BITS-1 downto 0);
    io_mmio_b_bits_user : in std_logic;
    io_mmio_ar_ready : in std_logic;
    io_mmio_ar_valid : out std_logic;
    io_mmio_ar_bits_addr : out std_logic_vector(31 downto 0);
    io_mmio_ar_bits_len : out std_logic_vector(7 downto 0);
    io_mmio_ar_bits_size : out std_logic_vector(2 downto 0);
    io_mmio_ar_bits_burst : out std_logic_vector(1 downto 0);
    io_mmio_ar_bits_lock : out std_logic;
    io_mmio_ar_bits_cache : out std_logic_vector(3 downto 0);
    io_mmio_ar_bits_prot : out std_logic_vector(2 downto 0);
    io_mmio_ar_bits_qos : out std_logic_vector(3 downto 0);
    io_mmio_ar_bits_region : out std_logic_vector(3 downto 0);
    io_mmio_ar_bits_id : out std_logic_vector(CFG_ROCKET_ID_BITS-1 downto 0);
    io_mmio_ar_bits_user : out std_logic;
    io_mmio_r_ready : out std_logic;
    io_mmio_r_valid : in std_logic;
    io_mmio_r_bits_resp : in std_logic_vector(1 downto 0);
    io_mmio_r_bits_data : in std_logic_vector(CFG_NASTI_DATA_BITS-1 downto 0);
    io_mmio_r_bits_last : in std_logic;
    io_mmio_r_bits_id : in std_logic_vector(CFG_ROCKET_ID_BITS-1 downto 0);
    io_mmio_r_bits_user : in std_logic
    --init : in std_logic
  );
  end component;

begin

  mstcfg1 <= xmstconfig1;
  mstcfg2 <= xmstconfig2;

  rstn <= not rst;
  clk_htif <= clk_sys; -- clock htif not used in Scala generated sources when FPGA define enabled.
  
  ------------------------------------
  -- Hardware init and MRESET for the CPUs
  start0 : starter port map
  (
    clk    => clk_htif,
    nrst   => rstn,
    i_host => htifi_deser,
    o_host => htifo_starter,
    o_init_ena => init_ena
  );

  --! Starter HTIF bus has the highest priority because it is
  --! unreset CPU/Uncore at the very begining after hard-reset and then
  --! doesn't make any action.
  htifo_mux <= htifo_starter when init_ena = '1' else htifoi;
  
  serdes0 : htif_serdes generic map (
    core_idx => 0
  ) port map (
    clk   => clk_htif,
    nrst  => rstn,
    hostoi => htifo_mux,
    hostio => htifi_deser,
    srdi  => cpu2htif,
    srdo  => htif2cpu
  );
  htifio <= htifi_deser;

  ------------------------------------
  --! @brief NoC core instance.
  rocket0 : Top port map
  (
    clk                       => clk_sys,           --in
    reset                     => rst,               --in

    io_host_in_valid          => htif2cpu.valid,  --in
    io_host_in_ready          => cpu2htif.ready,  --out
    io_host_in_bits           => htif2cpu.bits,   --in[15:0]
    io_host_out_valid         => cpu2htif.valid,  --out
    io_host_out_ready         => htif2cpu.ready,  --in
    io_host_out_bits          => cpu2htif.bits,  --out[15:0] goes to Starter and Memory DeSerializer

    io_host_clk               => clk_htif,             --out
    io_host_clk_edge          => open,                 --out
    io_host_debug_stats_csr   => open, --out (unused)
    io_mem_backup_ctrl_en     => '0', --in
    io_mem_backup_ctrl_in_valid  => '0',--mem_bk_in_valid_delay, --in
    io_mem_backup_ctrl_out_ready => '0',--mem_bk_out_ready_delay,--in
    io_mem_backup_ctrl_out_valid => open,--mem_bk_out_valid_delay,--out

    --! mem 
    io_mem_0_aw_ready => msti.aw_ready,--in
    io_mem_0_aw_valid => msto1.aw_valid,--out
    io_mem_0_aw_bits_addr => msto1.aw_bits.addr,--out[31:0]
    io_mem_0_aw_bits_len => msto1.aw_bits.len,--out[7:0]
    io_mem_0_aw_bits_size => msto1.aw_bits.size,--out[2:0]
    io_mem_0_aw_bits_burst => msto1.aw_bits.burst,--out[1:0]
    io_mem_0_aw_bits_lock => msto1.aw_bits.lock,--out
    io_mem_0_aw_bits_cache => msto1.aw_bits.cache,--out[3:0]
    io_mem_0_aw_bits_prot => msto1.aw_bits.prot,--out[2:0]
    io_mem_0_aw_bits_qos => msto1.aw_bits.qos,--out[3:0]
    io_mem_0_aw_bits_region => msto1.aw_bits.region,--out[3:0]
    io_mem_0_aw_bits_id  => msto1.aw_id,--out[5:0]
    io_mem_0_aw_bits_user => msto1.aw_user,--out
    io_mem_0_w_ready => msti.w_ready,--in
    io_mem_0_w_valid  => msto1.w_valid,--out
    io_mem_0_w_bits_data => msto1.w_data,--out[127:0]
    io_mem_0_w_bits_last => msto1.w_last,--out
    io_mem_0_w_bits_strb => msto1.w_strb,--out[15:0]
    io_mem_0_w_bits_user => msto1.w_user,--out
    io_mem_0_b_ready => msto1.b_ready,--out
    io_mem_0_b_valid => msti.b_valid,--in
    io_mem_0_b_bits_resp => msti.b_resp,--in[1:0]
    io_mem_0_b_bits_id => msti.b_id,--in[5:0]
    io_mem_0_b_bits_user => msti.b_user,--in
    io_mem_0_ar_ready => msti.ar_ready,--in
    io_mem_0_ar_valid => msto1.ar_valid,--out
    io_mem_0_ar_bits_addr => msto1.ar_bits.addr,--out[31:0]
    io_mem_0_ar_bits_len => msto1.ar_bits.len,--out[7:0]
    io_mem_0_ar_bits_size => msto1.ar_bits.size,--out[2:0]
    io_mem_0_ar_bits_burst => msto1.ar_bits.burst,--out[1:0]
    io_mem_0_ar_bits_lock => msto1.ar_bits.lock,--out
    io_mem_0_ar_bits_cache => msto1.ar_bits.cache,--out[3:0]
    io_mem_0_ar_bits_prot => msto1.ar_bits.prot,--out[2:0]
    io_mem_0_ar_bits_qos => msto1.ar_bits.qos,--out[3:0]
    io_mem_0_ar_bits_region => msto1.ar_bits.region,--out[3:0]
    io_mem_0_ar_bits_id => msto1.ar_id,--out[5:0]
    io_mem_0_ar_bits_user => msto1.ar_user,--out
    io_mem_0_r_ready => msto1.r_ready,--out
    io_mem_0_r_valid => msti.r_valid,--in
    io_mem_0_r_bits_resp => msti.r_resp,--in[1:0]
    io_mem_0_r_bits_data => msti.r_data,--in[127:0]
    io_mem_0_r_bits_last => msti.r_last,--in
    io_mem_0_r_bits_id => msti.r_id,--in[5:0]
    io_mem_0_r_bits_user => msti.r_user,--in
    --! mmio 
    io_mmio_aw_ready => msti.aw_ready,--in
    io_mmio_aw_valid => msto2.aw_valid,--out
    io_mmio_aw_bits_addr => msto2.aw_bits.addr,--out[31:0]
    io_mmio_aw_bits_len => msto2.aw_bits.len,--out[7:0]
    io_mmio_aw_bits_size => msto2.aw_bits.size,--out[2:0]
    io_mmio_aw_bits_burst => msto2.aw_bits.burst,--out[1:0]
    io_mmio_aw_bits_lock => msto2.aw_bits.lock,--out
    io_mmio_aw_bits_cache => msto2.aw_bits.cache,--out[3:0]
    io_mmio_aw_bits_prot => msto2.aw_bits.prot,--out[2:0]
    io_mmio_aw_bits_qos => msto2.aw_bits.qos,--out[3:0]
    io_mmio_aw_bits_region => msto2.aw_bits.region,--out[3:0]
    io_mmio_aw_bits_id  => msto2.aw_id,--out[5:0]
    io_mmio_aw_bits_user => msto2.aw_user,--out
    io_mmio_w_ready => msti.w_ready,--in
    io_mmio_w_valid  => msto2.w_valid,--out
    io_mmio_w_bits_data => msto2.w_data,--out[127:0]
    io_mmio_w_bits_last => msto2.w_last,--out
    io_mmio_w_bits_strb => msto2.w_strb,--out[15:0]
    io_mmio_w_bits_user => msto2.w_user,--out
    io_mmio_b_ready => msto2.b_ready,--out
    io_mmio_b_valid => msti.b_valid,--in
    io_mmio_b_bits_resp => msti.b_resp,--in[1:0]
    io_mmio_b_bits_id => msti.b_id,--in[5:0]
    io_mmio_b_bits_user => msti.b_user,--in
    io_mmio_ar_ready => msti.ar_ready,--in
    io_mmio_ar_valid => msto2.ar_valid,--out
    io_mmio_ar_bits_addr => msto2.ar_bits.addr,--out[31:0]
    io_mmio_ar_bits_len => msto2.ar_bits.len,--out[7:0]
    io_mmio_ar_bits_size => msto2.ar_bits.size,--out[2:0]
    io_mmio_ar_bits_burst => msto2.ar_bits.burst,--out[1:0]
    io_mmio_ar_bits_lock => msto2.ar_bits.lock,--out
    io_mmio_ar_bits_cache => msto2.ar_bits.cache,--out[3:0]
    io_mmio_ar_bits_prot => msto2.ar_bits.prot,--out[2:0]
    io_mmio_ar_bits_qos => msto2.ar_bits.qos,--out[3:0]
    io_mmio_ar_bits_region => msto2.ar_bits.region,--out[3:0]
    io_mmio_ar_bits_id => msto2.ar_id,--out[5:0]
    io_mmio_ar_bits_user => msto2.ar_user,--out
    io_mmio_r_ready => msto2.r_ready,--out
    io_mmio_r_valid => msti.r_valid,--in
    io_mmio_r_bits_resp => msti.r_resp,--in[1:0]
    io_mmio_r_bits_data => msti.r_data,--in[127:0]
    io_mmio_r_bits_last => msti.r_last,--in
    io_mmio_r_bits_id => msti.r_id,--in[5:0]
    io_mmio_r_bits_user => msti.r_user--in
  );
  
 
end arch_rocket_l2cache;

-----------------------------------------------------------------------------
--! @file
--! @copyright  Copyright 2015 GNSS Sensor Ltd. All right reserved.
--! @author     Sergey Khabarov - sergeykhbr@gmail.com
--! @brief	Technology specific ROM Image with the Firmware
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
library techmap;
use techmap.gencomp.all;
use techmap.allmem.all;
library commonlib;
use commonlib.types_common.all;
library rocketlib;
use rocketlib.types_nasti.all;

entity RomImage_tech is
generic (
    memtech : integer := 0
);
port (
    clk       : in std_logic;
    address   : in global_addr_array_type;
    data      : out std_logic_vector(CFG_NASTI_DATA_BITS-1 downto 0)
);
end;

architecture arch_RomImage_tech of RomImage_tech is
begin

  genrom0 : if memtech = inferred or is_fpga(memtech) /= 0 generate
      infer0 : RomImage_inferred  generic map (
        hex_filename => "E:/Projects/VHDLProjects/rocket/fw_images/fwimage.hex"
      ) port map (clk, address, data);
  end generate;

end; 


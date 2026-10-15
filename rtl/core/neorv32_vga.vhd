-- ================================================================================ --
-- NEORV32 SoC - Native 320x200 @ 4bpp VGA Framebuffer & Palette Raster Controller    --
-- Resolution: Native 320x200 @ 4bpp upscaled 2xH/2xV to 640x480 @ 60Hz (Letterboxed) --
-- Target: Id Software DOOM (1993) Authentic Mode 13h Display Architecture            --
-- Features:                                                                        --
--   - 32,000 bytes dual-port Block RAM (Port A: CPU R/W, Port B: VGA scanout)       --
--   - Full Port A bus read-back support (eliminates read-modify-write traps)        --
--   - 256 x 12-bit RGB Color Lookup Table (Palette CLUT)                            --
--   - Authentic 320x200 active area centered with 40-line top/bottom borders        --
--   - 12-bit resistor DAC direct output (4-bit R, 4-bit G, 4-bit B, HSYNC, VSYNC)  --
-- ================================================================================ --

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity neorv32_vga is
  port (
    -- SoC Bus Clock & Reset
    clk_i       : in  std_ulogic; -- 50 MHz system clock
    rstn_i      : in  std_ulogic;

    -- MMIO / Wishbone Bus Slave for VRAM & Palette
    -- Addr range:
    --   0x00000 - 0x07CFF : Native 320x200 4bpp Framebuffer (32,000 bytes)
    --   0x10000 - 0x103FF : Palette RAM (256 entries * 4 bytes: [11:8]=R, [7:4]=G, [3:0]=B)
    --   0x10400           : Status / VSync Register ([0] = in_vblank)
    bus_addr_i  : in  std_ulogic_vector(16 downto 0);
    bus_wdata_i : in  std_ulogic_vector(31 downto 0);
    bus_ben_i   : in  std_ulogic_vector(3 downto 0);
    bus_we_i    : in  std_ulogic;
    bus_rdata_o : out std_ulogic_vector(31 downto 0);

    -- VGA Physical Interface (12-bit DAC + Sync)
    vga_red_o   : out std_ulogic_vector(3 downto 0);
    vga_green_o : out std_ulogic_vector(3 downto 0);
    vga_blue_o  : out std_ulogic_vector(3 downto 0);
    vga_hsync_o : out std_ulogic;
    vga_vsync_o : out std_ulogic
  );
end entity;

architecture rtl of neorv32_vga is

  -- 25 MHz pixel clock strobe from 100 MHz clk_i (div 4)
  signal pclk_cnt     : unsigned(1 downto 0) := (others => '0');
  signal pclk_tick    : std_ulogic;

  -- 640x480 @ 60 Hz Timing Parameters
  -- H: 640 active + 16 FP + 96 Sync + 48 BP = 800 total
  -- V: 480 active + 10 FP + 2 Sync + 33 BP = 525 total
  signal h_cnt        : integer range 0 to 799 := 0;
  signal v_cnt        : integer range 0 to 524 := 0;

  signal active_area  : boolean := false;
  signal active_doom  : boolean := false;
  signal hsync_reg    : std_ulogic := '1';
  signal vsync_reg    : std_ulogic := '1';
  signal in_vblank    : std_ulogic := '0';

  -- Framebuffer index calculation:
  -- 320x200 native resolution:
  --   Horizontal: 320 pixels across 640 active VGA clocks (2x horizontal scaling: pixel_x = h_cnt / 2)
  --   Vertical: 200 scanlines across 400 active lines centered in 480 (2x vertical scaling: pixel_y = (v_cnt - 40) / 2)
  --   Top/Bottom border: 40 black scanlines (v_cnt < 40 or v_cnt >= 440)
  signal pixel_x      : integer range 0 to 319 := 0;
  signal pixel_y      : integer range 0 to 199 := 0;
  signal vram_raddr   : unsigned(15 downto 0) := (others => '0');

  -- 64,000 bytes Framebuffer (Native 320x200 @ 8bpp Mode 13h: 16x RAMB36)
  type vram_t is array (0 to 63999) of std_ulogic_vector(7 downto 0);
  signal vram         : vram_t := (others => (others => '0'));
  attribute ram_style : string;
  attribute ram_style of vram : signal is "block";

  signal vram_rdata_b : std_ulogic_vector(7 downto 0) := (others => '0');
  signal vram_rdata_a : std_ulogic_vector(7 downto 0) := (others => '0');

  -- 256-entry x 12-bit RGB Color Palette (CLUT)
  type palette_t is array (0 to 255) of std_ulogic_vector(11 downto 0);
  signal palette_mem  : palette_t := (
    -- Default 16-color standard VGA palette fallback
    0  => x"000", -- 0: Black
    1  => x"00A", -- 1: Dark Blue
    2  => x"0A0", -- 2: Dark Green
    3  => x"0AA", -- 3: Dark Cyan
    4  => x"A00", -- 4: Dark Red
    5  => x"A0A", -- 5: Dark Magenta
    6  => x"A50", -- 6: Brown / Amber
    7  => x"AAA", -- 7: Light Grey
    8  => x"555", -- 8: Medium Grey
    9  => x"55F", -- 9: Bright Blue
    10 => x"5F5", -- 10: Bright Green
    11 => x"5FF", -- 11: Bright Cyan
    12 => x"F55", -- 12: Bright Red
    13 => x"F5F", -- 13: Bright Magenta
    14 => x"FF5", -- 14: Yellow
    15 => x"FFF", -- 15: White
    others => x"FFF"
  );
  signal rgb_color    : std_ulogic_vector(11 downto 0) := (others => '0');

  -- Pipelined signals matching BRAM & Palette latency (3 cycles at 100 MHz)
  signal vram_rdata_b_pipe : std_ulogic_vector(7 downto 0) := (others => '0');
  signal active_d1    : boolean := false;
  signal active_d2    : boolean := false;
  signal active_d3    : boolean := false;
  signal hsync_d1     : std_ulogic := '1';
  signal hsync_d2     : std_ulogic := '1';
  signal hsync_d3     : std_ulogic := '1';
  signal vsync_d1     : std_ulogic := '1';
  signal vsync_d2     : std_ulogic := '1';
  signal vsync_d3     : std_ulogic := '1';

begin

  -- Generate 25 MHz pixel enable tick from 100 MHz system clock (divide by 4)
  process(clk_i, rstn_i)
  begin
    if rstn_i = '0' then
      pclk_cnt <= (others => '0');
    elsif rising_edge(clk_i) then
      pclk_cnt <= pclk_cnt + 1;
    end if;
  end process;
  pclk_tick <= '1' when (pclk_cnt = "11") else '0';

  -- VGA Sync Generator (640x480 @ 60Hz standard timing)
  process(clk_i, rstn_i)
  begin
    if rstn_i = '0' then
      h_cnt       <= 0;
      v_cnt       <= 0;
      hsync_reg   <= '1';
      vsync_reg   <= '1';
      active_area <= false;
      in_vblank   <= '0';
    elsif rising_edge(clk_i) then
      if pclk_tick = '1' then
        -- Horizontal Counter
        if h_cnt = 799 then
          h_cnt <= 0;
          -- Vertical Counter
          if v_cnt = 524 then
            v_cnt <= 0;
          else
            v_cnt <= v_cnt + 1;
          end if;
        else
          h_cnt <= h_cnt + 1;
        end if;

        -- Horizontal Sync Pulse (active LOW: 656 to 751)
        if (h_cnt >= (640 + 16)) and (h_cnt < (640 + 16 + 96)) then
          hsync_reg <= '0';
        else
          hsync_reg <= '1';
        end if;

        -- Vertical Sync Pulse (active LOW: 490 to 491)
        if (v_cnt >= (480 + 10)) and (v_cnt < (480 + 10 + 2)) then
          vsync_reg <= '0';
        else
          vsync_reg <= '1';
        end if;

        -- Active Video Region
        if (h_cnt < 640) and (v_cnt < 480) then
          active_area <= true;
        else
          active_area <= false;
        end if;

        -- VBlank Flag for status register
        if (v_cnt >= 480) then
          in_vblank <= '1';
        else
          in_vblank <= '0';
        end if;
      end if;
    end if;
  end process;

  -- Native 320x200 @ 8bpp Centered Scanout Address Logic:
  --   Horizontal: 320 pixels (each pixel lasts 2 VGA clocks)
  --   Vertical: 200 lines (each line lasts 2 VGA scanlines, centered between line 40 and 439)
  process(h_cnt, v_cnt)
  begin
    if (h_cnt < 640) and (v_cnt >= 40) and (v_cnt < 440) then
      active_doom <= true;
      pixel_x     <= h_cnt / 2;
      pixel_y     <= (v_cnt - 40) / 2;
    else
      active_doom <= false;
      pixel_x     <= 0;
      pixel_y     <= 0;
    end if;
  end process;

  -- Linear byte address: 320 pixels per line, 1 byte per pixel
  vram_raddr <= to_unsigned(pixel_y * 320 + pixel_x, 16);

  -- Framebuffer Dual-Port Read / Write Process
  process(clk_i)
    variable byte_addr_w : integer range 0 to 65535;
    variable byte_addr_r : integer range 0 to 65535;
  begin
    if rising_edge(clk_i) then
      -- -------------------------------------------------------------
      -- Port A: CPU Bus Reads & Writes
      -- -------------------------------------------------------------
      if bus_addr_i(16) = '0' then
        byte_addr_r := to_integer(unsigned(bus_addr_i(15 downto 0)));
        if byte_addr_r < 64000 then
          vram_rdata_a <= vram(byte_addr_r);
        else
          vram_rdata_a <= (others => '0');
        end if;
      end if;

      if bus_we_i = '1' and bus_addr_i(16) = '0' then
        byte_addr_w := to_integer(unsigned(bus_addr_i(15 downto 0)));
        if byte_addr_w < 64000 then
          case bus_addr_i(1 downto 0) is
            when "00"   => vram(byte_addr_w) <= bus_wdata_i(7 downto 0);
            when "01"   => vram(byte_addr_w) <= bus_wdata_i(15 downto 8);
            when "10"   => vram(byte_addr_w) <= bus_wdata_i(23 downto 16);
            when others => vram(byte_addr_w) <= bus_wdata_i(31 downto 24);
          end case;
        end if;
      end if;

      -- -------------------------------------------------------------
      -- Port B: VGA Scanout Read (synchronous BRAM access)
      -- -------------------------------------------------------------
      if to_integer(vram_raddr) < 64000 then
        vram_rdata_b <= vram(to_integer(vram_raddr));
      else
        vram_rdata_b <= (others => '0');
      end if;
      vram_rdata_b_pipe <= vram_rdata_b;

      -- Pipeline active display enable matching the 3-cycle read latency (BRAM + Reg + CLUT)
      active_d1 <= active_area and active_doom;
      active_d2 <= active_d1;
      active_d3 <= active_d2;

      -- Pipeline sync pulses to match pixel data latency exactly
      hsync_d1  <= hsync_reg;
      hsync_d2  <= hsync_d1;
      hsync_d3  <= hsync_d2;
      vsync_d1  <= vsync_reg;
      vsync_d2  <= vsync_d1;
      vsync_d3  <= vsync_d2;
    end if;
  end process;

  -- Palette CLUT Write & Read Process
  process(clk_i)
    variable pal_idx : integer range 0 to 255;
  begin
    if rising_edge(clk_i) then
      -- Palette Write (Addr 0x10000 - 0x103FF)
      if bus_we_i = '1' and bus_addr_i(16) = '1' and bus_addr_i(15 downto 10) = "000000" then
        pal_idx := to_integer(unsigned(bus_addr_i(9 downto 2)));
        palette_mem(pal_idx) <= bus_wdata_i(11 downto 0);
      end if;

      -- Palette Lookup for raster scan (256-color lookup from pipelined 8bpp native pixel)
      rgb_color <= palette_mem(to_integer(unsigned(vram_rdata_b_pipe)));
    end if;
  end process;

  -- MMIO Bus Read Response
  process(bus_addr_i, in_vblank, vram_rdata_a)
  begin
    bus_rdata_o <= (others => '0');
    if bus_addr_i(16) = '0' then
      -- Replicate read byte across all 4 byte lanes for transparent unaligned lb/lbu support
      bus_rdata_o <= vram_rdata_a & vram_rdata_a & vram_rdata_a & vram_rdata_a;
    elsif bus_addr_i(16) = '1' and bus_addr_i(10) = '1' then
      -- Status register (0x10400): [0] in_vblank
      bus_rdata_o(0) <= in_vblank;
    end if;
  end process;

  -- Final DAC Output Mapping with Blanking & Letterbox Border
  vga_hsync_o <= hsync_d3;
  vga_vsync_o <= vsync_d3;

  vga_red_o   <= rgb_color(11 downto 8) when active_d3 else (others => '0');
  vga_green_o <= rgb_color(7 downto 4)  when active_d3 else (others => '0');
  vga_blue_o  <= rgb_color(3 downto 0)  when active_d3 else (others => '0');

end architecture;

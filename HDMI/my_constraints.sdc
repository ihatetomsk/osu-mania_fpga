create_clock -name "refclk" -period 20.000 [get_ports FPGA_CLK1_50]
derive_pll_clocks
derive_clock_uncertainty
# Timing constraints for the FPGA demo.
#
# Add this file to the project (Project -> Add/Remove Files in Project) so the
# Timing Analyzer knows what the clocks are. Without it Quartus assumes a 1 GHz
# default clock, reports enormous violations, and the Fmax number it gives you
# is meaningless.

# The board's 50 MHz oscillator.
create_clock -name CLOCK_50 -period 20.000 [get_ports CLOCK_50]

# The CPU runs on a divided clock, taken from a counter bit rather than a PLL.
# It has to be declared as a generated clock or the analyser will not know the
# CPU is running four times slower than the oscillator -- and the Fmax it
# reports for the processor would be wrong.
#
# If you change CLK_DIV_LOG2 in de1soc_top.v, change -divide_by to match:
#   CLK_DIV_LOG2 = 1  -> divide_by 2  (25 MHz),   counter bit cnt[0]
#   CLK_DIV_LOG2 = 2  -> divide_by 4  (12.5 MHz), counter bit cnt[1]
#   CLK_DIV_LOG2 = 3  -> divide_by 8  (6.25 MHz), counter bit cnt[2]
create_generated_clock -name cpu_clk \
    -source [get_ports CLOCK_50] -divide_by 4 \
    [get_registers {*u_clkdiv|cnt[1]}]

derive_clock_uncertainty

# Switches and buttons are driven by a human, and the LEDs and displays are
# read by one. Neither has a meaningful setup or hold requirement, so exclude
# them from analysis rather than letting them clutter the report. The switch
# and button inputs are synchronised inside mmio.v.
set_false_path -from [get_ports {SW[*] KEY[*]}] -to [all_registers]
set_false_path -from [all_registers] -to [get_ports {LEDR[*] HEX0[*] HEX1[*] HEX2[*] HEX3[*] HEX4[*] HEX5[*]}]

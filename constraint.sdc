# constraint.sdc for gcd_with_io
# Units
set_units -time ns -resistance kOhm -capacitance pF -voltage V -current uA

# ===========================================================================
# Clock Definition
# ===========================================================================
# Main system clock at pad[0]
create_clock -name sys_clk -period 20.0 [get_ports {pads[0]}]

# Clock uncertainty accounts for jitter, skew, and margin
set_clock_uncertainty 0.5 [get_clocks sys_clk]

# Clock latency (estimated source and network latency)
set_clock_latency -source 1.0 [get_clocks sys_clk]
set_clock_latency 1.5 [get_clocks sys_clk]

# Clock transition (max slew rate)
set_clock_transition 0.3 [get_clocks sys_clk]

# ===========================================================================
# Reset Path - Asynchronous
# ===========================================================================
# Reset (pads[1]) is asynchronous, so no timing requirements
set_false_path -from [get_ports {pads[1]}]

# ===========================================================================
# Input Constraints
# ===========================================================================
# Clock input (already defined above)
# pads[0] = clk

# Reset input (false path defined above)  
# pads[1] = reset

# Request valid signal
# pads[2] = req_val
set_input_delay 3.0 -clock sys_clk [get_ports {pads[2]}]

# Response ready signal
# pads[3] = resp_rdy
set_input_delay 3.0 -clock sys_clk [get_ports {pads[3]}]

# Define driving cell for all inputs
set_driving_cell -lib_cell sg13g2_IOPadIn -pin p2c [get_ports {pads[1] pads[2] pads[3]}]

# ===========================================================================
# Output Constraints
# ===========================================================================
# Request ready output
# pads[4] = req_rdy
set_output_delay 4.0 -clock sys_clk [get_ports {pads[4]}]
set_load 2.0 [get_ports {pads[4]}]

# Response valid output
# pads[5] = resp_val
set_output_delay 4.0 -clock sys_clk [get_ports {pads[5]}]
set_load 2.0 [get_ports {pads[5]}]

# Response message MSB
# pads[6] = resp_msg[15]
set_output_delay 5.0 -clock sys_clk [get_ports {pads[6]}]
set_load 2.0 [get_ports {pads[6]}]

# Response message LSB
# pads[7] = resp_msg[0]
set_output_delay 5.0 -clock sys_clk [get_ports {pads[7]}]
set_load 2.0 [get_ports {pads[7]}]

# ===========================================================================
# Design Constraints
# ===========================================================================
# Maximum fanout for all nets
set_max_fanout 16 [current_design]

# Maximum transition time (slew rate)
set_max_transition 1.0 [current_design]

# Maximum capacitance
set_max_capacitance 0.5 [current_design]

# ===========================================================================
# Virtual Clock for I/O Timing (Optional)
# ===========================================================================
# If external logic has different clock, create virtual clock
# create_clock -name vclk -period 20.0
# set_input_delay 3.0 -clock vclk [get_ports {pads[2] pads[3]}]
# set_output_delay 4.0 -clock vclk [get_ports {pads[4] pads[5] pads[6] pads[7]}]

# ===========================================================================
# Multi-Cycle Paths (if applicable)
# ===========================================================================
# GCD algorithm may take multiple cycles - uncomment if needed
# set_multicycle_path -setup 8 -from [get_pins gcd_core/*] -to [get_pins gcd_core/*]
# set_multicycle_path -hold 7 -from [get_pins gcd_core/*] -to [get_pins gcd_core/*]

# ===========================================================================
# Case Analysis for Unused Signals
# ===========================================================================
# If any control signals are tied to constant values, specify them here
# Example: set_case_analysis 0 [get_pins some_mux/sel]

# ===========================================================================
# Environment Conditions
# ===========================================================================
# Operating conditions are typically set in library files, but can be overridden
# set_operating_conditions -max slow_1p08V_125C -max_library slow_lib
# set_operating_conditions -min fast_1p32V_m55C -min_library fast_lib

puts "SDC constraints loaded successfully for gcd_with_io"
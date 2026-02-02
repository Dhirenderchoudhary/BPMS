#############################################################################
# BPMS Chip - Design Constraints (SDC)
# Blood Pressure Monitoring System
# For use with Cadence Genus / Innovus
#############################################################################

# Clock definition: 10 MHz (100ns period)
create_clock -name clk -period 100.0 [get_ports clk]

# Clock uncertainty
set_clock_uncertainty -setup 0.5 [get_clocks clk]
set_clock_uncertainty -hold 0.1 [get_clocks clk]

# Clock transition
set_clock_transition 0.2 [get_clocks clk]

#############################################################################
# Input Constraints
#############################################################################

# All inputs except clock and reset
set_input_delay -max 20.0 -clock clk [get_ports adc_data[*]]
set_input_delay -max 20.0 -clock clk [get_ports adc_valid]
set_input_delay -min 0.5  -clock clk [get_ports adc_data[*]]
set_input_delay -min 0.5  -clock clk [get_ports adc_valid]

# Reset input
set_input_delay -max 10.0 -clock clk [get_ports rst]
set_input_delay -min 0.5  -clock clk [get_ports rst]

#############################################################################
# Output Constraints
#############################################################################

# BP outputs
set_output_delay -max 20.0 -clock clk [get_ports systolic_bp[*]]
set_output_delay -max 20.0 -clock clk [get_ports diastolic_bp[*]]
set_output_delay -max 20.0 -clock clk [get_ports heart_rate[*]]
set_output_delay -min 0.5  -clock clk [get_ports systolic_bp[*]]
set_output_delay -min 0.5  -clock clk [get_ports diastolic_bp[*]]
set_output_delay -min 0.5  -clock clk [get_ports heart_rate[*]]

# Alert outputs
set_output_delay -max 20.0 -clock clk [get_ports bp_high_alert]
set_output_delay -max 20.0 -clock clk [get_ports bp_low_alert]
set_output_delay -max 20.0 -clock clk [get_ports measurement_done]
set_output_delay -min 0.5  -clock clk [get_ports bp_high_alert]
set_output_delay -min 0.5  -clock clk [get_ports bp_low_alert]
set_output_delay -min 0.5  -clock clk [get_ports measurement_done]

#############################################################################
# Design Rule Constraints
#############################################################################

# Maximum transition time (adjust for your technology)
set_max_transition 1.0 [current_design]

# Maximum fanout
set_max_fanout 20 [current_design]

# Maximum capacitance (adjust for your technology)
# set_max_capacitance 0.5 [current_design]

#############################################################################
# False Paths and Multicycle Paths
#############################################################################

# Reset is asynchronous - treat as false path for timing
set_false_path -from [get_ports rst]

#############################################################################
# Operating Conditions (example - update for your library)
#############################################################################

# set_operating_conditions -max slow -min fast

#############################################################################
# Area Constraint
#############################################################################

# Minimize area
set_max_area 0

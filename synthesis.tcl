#############################################################################
# BPMS Chip - Cadence Genus Synthesis Script
# Blood Pressure Monitoring System
#############################################################################

# Set design name
set DESIGN_NAME bp_monitor_system

# Set paths (modify these according to your environment)
set RTL_PATH "./design.v"
set OUTPUT_PATH "./synthesis_output"
set REPORTS_PATH "./reports"

# Create output directories
file mkdir $OUTPUT_PATH
file mkdir $REPORTS_PATH

#############################################################################
# Library Setup (Modify for your technology)
#############################################################################
# Example for a generic 45nm library - update with your actual library
# set_db init_lib_search_path {/path/to/your/library}
# set_db library {slow.lib fast.lib}

# For academic/demo purposes without real libraries:
puts "=============================================="
puts "BPMS Chip Synthesis - Cadence Genus"
puts "=============================================="
puts "NOTE: Update library paths for your technology"
puts "=============================================="

#############################################################################
# Read Design
#############################################################################
puts "\n>>> Reading RTL design..."

# Read Verilog source
read_hdl $RTL_PATH

# Elaborate design
elaborate $DESIGN_NAME

# Check for errors
check_design -unresolved

#############################################################################
# Design Constraints
#############################################################################
puts "\n>>> Applying design constraints..."

# Clock definition (10 MHz = 100ns period)
# Adjust frequency based on your requirements
set CLOCK_PERIOD 100.0
set CLOCK_NAME clk

create_clock -name $CLOCK_NAME -period $CLOCK_PERIOD [get_ports clk]

# Clock uncertainty (for timing margin)
set_clock_uncertainty 0.5 [get_clocks $CLOCK_NAME]

# Input/Output delays (adjust based on your system)
set INPUT_DELAY  [expr $CLOCK_PERIOD * 0.2]
set OUTPUT_DELAY [expr $CLOCK_PERIOD * 0.2]

set_input_delay  $INPUT_DELAY  -clock $CLOCK_NAME [all_inputs]
set_output_delay $OUTPUT_DELAY -clock $CLOCK_NAME [all_outputs]

# Don't apply delay to clock port
set_input_delay 0 -clock $CLOCK_NAME [get_ports clk]

# Reset is asynchronous input - give it more margin
set_input_delay [expr $CLOCK_PERIOD * 0.1] -clock $CLOCK_NAME [get_ports rst]

# Driving cell and load (generic - update for your library)
# set_driving_cell -lib_cell INVX1 [all_inputs]
# set_load 0.01 [all_outputs]

#############################################################################
# Synthesis Settings
#############################################################################
puts "\n>>> Configuring synthesis settings..."

# Set optimization effort
set_db syn_generic_effort high
set_db syn_map_effort high
set_db syn_opt_effort high

# Enable retiming for better performance (optional)
# set_db design:$DESIGN_NAME .retime true

# Area optimization
set_db design:$DESIGN_NAME .max_area 0

#############################################################################
# Synthesize
#############################################################################
puts "\n>>> Running synthesis..."

# Generic synthesis (technology independent)
syn_generic

# Technology mapping
syn_map

# Optimization
syn_opt

#############################################################################
# Reports
#############################################################################
puts "\n>>> Generating reports..."

# Timing report
report_timing > ${REPORTS_PATH}/timing.rpt
report_timing -max_paths 10 -nworst 3 > ${REPORTS_PATH}/timing_detailed.rpt

# Area report
report_area > ${REPORTS_PATH}/area.rpt

# Power report (if library supports it)
# report_power > ${REPORTS_PATH}/power.rpt

# Design statistics
report_gates > ${REPORTS_PATH}/gates.rpt

# Check for design rule violations
report_design_rules > ${REPORTS_PATH}/design_rules.rpt

# QoR Summary
report_qor > ${REPORTS_PATH}/qor.rpt

#############################################################################
# Write Outputs
#############################################################################
puts "\n>>> Writing output files..."

# Write synthesized netlist (Verilog)
write_hdl > ${OUTPUT_PATH}/${DESIGN_NAME}_synth.v

# Write constraints (SDC format)
write_sdc > ${OUTPUT_PATH}/${DESIGN_NAME}.sdc

# Write design database
write_design -innovus -basename ${OUTPUT_PATH}/${DESIGN_NAME}

#############################################################################
# Summary
#############################################################################
puts "\n=============================================="
puts "Synthesis Complete!"
puts "=============================================="
puts "Output files:"
puts "  Netlist:     ${OUTPUT_PATH}/${DESIGN_NAME}_synth.v"
puts "  Constraints: ${OUTPUT_PATH}/${DESIGN_NAME}.sdc"
puts "  Reports:     ${REPORTS_PATH}/"
puts "=============================================="

# Print final timing summary
puts "\nTiming Summary:"
report_timing -summary

# Print area summary
puts "\nArea Summary:"
report_area -summary

puts "\n>>> Ready for Innovus Place & Route"
puts "=============================================="

# Exit (comment out for interactive mode)
# exit

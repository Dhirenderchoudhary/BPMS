# BPMS Chip - Complete ASIC Flow (RTL to Tape-out)

## Table of Contents
1. [RTL Design](#1-rtl-design)
2. [Functional Simulation](#2-functional-simulation)
3. [Synthesis](#3-synthesis-cadence-genus)
4. [Floorplanning](#4-floorplanning-cadence-innovus)
5. [Power Planning](#5-power-planning)
6. [Placement](#6-placement)
7. [Clock Tree Synthesis](#7-clock-tree-synthesis-cts)
8. [Routing](#8-routing)
9. [Static Timing Analysis](#9-static-timing-analysis-sta)
10. [Physical Verification](#10-physical-verification)
11. [Signoff](#11-signoff)
12. [Tape-out](#12-tape-out)

---

## Flow Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        COMPLETE ASIC DESIGN FLOW                            │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│   FRONT-END (Logic Design)                                                  │
│   ┌─────────┐    ┌─────────┐    ┌─────────┐                                │
│   │ 1. RTL  │───►│ 2. SIM  │───►│ 3.SYNTH │                                │
│   │ design.v│    │testbench│    │ Genus   │                                │
│   └─────────┘    └─────────┘    └────┬────┘                                │
│                                      │                                      │
│   ───────────────────────────────────┼──────────────────────────────────── │
│                                      ▼                                      │
│   BACK-END (Physical Design)    Gate-Level                                  │
│                                 Netlist                                     │
│   ┌─────────┐    ┌─────────┐    ┌─────────┐    ┌─────────┐                 │
│   │4. FLOOR │───►│5. POWER │───►│6. PLACE │───►│ 7. CTS  │                 │
│   │  PLAN   │    │  PLAN   │    │         │    │         │                 │
│   └─────────┘    └─────────┘    └─────────┘    └────┬────┘                 │
│                                                     │                       │
│   ┌─────────┐    ┌─────────┐    ┌─────────┐    ┌───┴─────┐                 │
│   │12.TAPE  │◄───│11.SIGN  │◄───│10. DRC/ │◄───│8. ROUTE │                 │
│   │  OUT    │    │  OFF    │    │   LVS   │    │         │                 │
│   └─────────┘    └─────────┘    └─────────┘    └─────────┘                 │
│        │                             ▲                                      │
│        ▼                             │                                      │
│   ┌─────────┐                   ┌────┴────┐                                │
│   │ FOUNDRY │                   │ 9. STA  │                                │
│   │ (TSMC,  │                   │ Timing  │                                │
│   │ Samsung)│                   └─────────┘                                │
│   └─────────┘                                                              │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 1. RTL Design

### Purpose
Write synthesizable Verilog code describing the chip functionality.

### Tool
- Text Editor / VS Code

### Input
- Design specifications
- Architecture document

### Output
- `design.v` - RTL source code

### Your Files
```verilog
// design.v - Top module
module bp_monitor_system (
    input             clk,
    input             rst,
    input      [11:0] adc_data,
    input             adc_valid,
    output reg [7:0]  systolic_bp,
    output reg [7:0]  diastolic_bp,
    output reg [7:0]  heart_rate,
    output            bp_high_alert,
    output            bp_low_alert,
    output reg        measurement_done
);
```

### Status: COMPLETE

---

## 2. Functional Simulation

### Purpose
Verify RTL functionality before synthesis.

### Tool
- Icarus Verilog (open source)
- ModelSim/Questa (commercial)
- VCS (Synopsys)

### Commands
```bash
# Compile
iverilog -o bp_sim design.v testbench.v

# Run simulation
vvp bp_sim

# View waveforms
gtkwave bp_monitor.vcd
```

### Output
```
╔═══════════════════════════════════════════════════════════╗
║   Tests Passed:  7                                        ║
║   Tests Failed:  0                                        ║
║   STATUS: ALL TESTS PASSED ✓                             ║
╚═══════════════════════════════════════════════════════════╝
```

### Status: COMPLETE

---

## 3. Synthesis (Cadence Genus)

### Purpose
Convert RTL to gate-level netlist using standard cells.

### Tool
- Cadence Genus

### Input Files
| File | Description |
|------|-------------|
| `design.v` | RTL source |
| `constraints.sdc` | Timing constraints |
| `*.lib` | Technology library |

### Commands
```tcl
#===========================================
# synthesis.tcl
#===========================================

# Read technology library
set_db init_lib_search_path {/path/to/pdk/libs}
set_db library {slow.lib typical.lib fast.lib}

# Read design
read_hdl design.v
elaborate bp_monitor_system

# Apply constraints
read_sdc constraints.sdc

# OR manually:
create_clock -name clk -period 100 [get_ports clk]
set_input_delay 20 -clock clk [all_inputs]
set_output_delay 20 -clock clk [all_outputs]

# Synthesize
syn_generic
syn_map
syn_opt

# Reports
report_timing > reports/timing.rpt
report_area > reports/area.rpt
report_power > reports/power.rpt

# Export for Innovus
write_hdl > output/bp_monitor_system_synth.v
write_sdc > output/bp_monitor_system.sdc
write_design -innovus -basename output/bp_monitor_system
```

### Run Synthesis
```bash
genus -f synthesis.tcl
```

### Output Files
| File | Description |
|------|-------------|
| `*_synth.v` | Gate-level netlist |
| `*.sdc` | Timing constraints |
| `*.dat` | Innovus database |

### Key Reports to Check
```bash
# Timing - Slack should be positive
cat reports/timing.rpt

# Area - Gate count
cat reports/area.rpt
```

### Status: TO DO IN LAB

---

## 4. Floorplanning (Cadence Innovus)

### Purpose
Define chip area, aspect ratio, and I/O placement.

### Tool
- Cadence Innovus

### Start Innovus
```bash
innovus
```

### Commands
```tcl
#===========================================
# Step 4: Floorplanning
#===========================================

# Import design from Genus
read_db output/bp_monitor_system.dat

# OR import manually:
read_verilog output/bp_monitor_system_synth.v
read_lib /path/to/slow.lib
read_sdc output/bp_monitor_system.sdc

# Set design name
set_top_module bp_monitor_system

# Create floorplan
# -r = aspect ratio (width/height)
# 0.7 = core utilization (70%)
# 10 10 10 10 = margins (left, bottom, right, top) in microns
floorplan -r 1.0 0.7 10 10 10 10

# OR specify exact dimensions:
floorplan -d 200 200 10 10 10 10

# Place I/O pins
# Automatically:
assignIoPins

# Or manually:
editPin -side LEFT -pin clk
editPin -side LEFT -pin rst
editPin -side RIGHT -pin systolic_bp[*]
editPin -side RIGHT -pin diastolic_bp[*]

# Save floorplan
saveFPlan bp_monitor_system.fp

# View floorplan
gui_show
```

### Output
- Floorplan file (`.fp`)
- Die area defined
- I/O pins placed

---

## 5. Power Planning

### Purpose
Create power distribution network (VDD/VSS rings and stripes).

### Commands
```tcl
#===========================================
# Step 5: Power Planning
#===========================================

# Connect global power nets
globalNetConnect VDD -type pgpin -pin VDD -all
globalNetConnect VSS -type pgpin -pin VSS -all

# Add power rings around core
addRing -nets {VDD VSS} \
        -type core_rings \
        -width 3 \
        -spacing 1 \
        -layer {metal3 metal4} \
        -offset 2

# Add horizontal stripes
addStripe -nets {VDD VSS} \
          -layer metal4 \
          -width 2 \
          -spacing 2 \
          -set_to_set_distance 50 \
          -direction horizontal

# Add vertical stripes
addStripe -nets {VDD VSS} \
          -layer metal5 \
          -width 2 \
          -spacing 2 \
          -set_to_set_distance 50 \
          -direction vertical

# Special route (connect rings to stripes)
sroute -connect {corePin} \
       -layerChangeRange {metal1 metal5} \
       -nets {VDD VSS}

# Verify power connections
verifyConnectivity -type special -nets {VDD VSS}
```

### Output
- Power rings created
- Power stripes created
- All cells connected to power

---

## 6. Placement

### Purpose
Place standard cells in optimal locations.

### Commands
```tcl
#===========================================
# Step 6: Placement
#===========================================

# Set placement mode
setPlaceMode -congEffort high

# Run placement
place_design

# Check placement
checkPlace

# Optimize placement
optDesign -preCTS

# View placement
gui_show

# Report placement density
report_density

# Save placement
saveDesign bp_monitor_placed.enc
```

### Placement Optimization Goals
| Goal | Description |
|------|-------------|
| Timing | Place critical paths close |
| Congestion | Avoid routing hotspots |
| Power | Minimize wirelength |

---

## 7. Clock Tree Synthesis (CTS)

### Purpose
Build clock distribution network with minimal skew.

### Commands
```tcl
#===========================================
# Step 7: Clock Tree Synthesis
#===========================================

# Set CTS mode
setCTSMode -engine ck

# Specify clock tree constraints
create_ccopt_clock_tree_spec -file clock.spec

# OR use automatic:
set_ccopt_property target_skew 100ps
set_ccopt_property target_insertion_delay 500ps

# Build clock tree
ccopt_design

# Report clock tree
report_ccopt_clock_trees
report_ccopt_skew_groups

# Verify clock
report_clock_timing -type summary

# Post-CTS optimization
optDesign -postCTS

# Save design
saveDesign bp_monitor_cts.enc
```

### Clock Tree Report Example
```
Clock: clk
  Sinks: 156
  Max insertion delay: 450ps
  Max skew: 85ps ✓ (target: 100ps)
```

---

## 8. Routing

### Purpose
Connect all cells with metal wires.

### Commands
```tcl
#===========================================
# Step 8: Routing
#===========================================

# Set routing mode
setNanoRouteMode -drouteFixAntenna true
setNanoRouteMode -drouteAutoStop false

# Global routing (fast, approximate)
globalRoute

# Detailed routing (final metal connections)
detailRoute

# OR use combined command:
routeDesign

# Fix DRC violations
editRoute -fix_drc

# Search and repair
setNanoRouteMode -droutePostRouteSpreadWire true
routeDesign -viaOpt

# Verify routing
verifyConnectivity
verifyGeometry

# Report routing
report_route

# Save routed design
saveDesign bp_monitor_routed.enc
```

### Routing Layers (Example)
| Layer | Usage |
|-------|-------|
| Metal1 | Local routing |
| Metal2 | Horizontal |
| Metal3 | Vertical |
| Metal4 | Power stripes |
| Metal5 | Top-level power |

---

## 9. Static Timing Analysis (STA)

### Purpose
Verify timing without simulation.

### Tool
- Cadence Tempus
- Innovus built-in

### Commands
```tcl
#===========================================
# Step 9: Static Timing Analysis
#===========================================

# In Innovus:
setAnalysisMode -analysisType onChipVariation

# Report timing - Setup (max delay)
report_timing -max_paths 10 -path_type full_clock > reports/setup_timing.rpt

# Report timing - Hold (min delay)
report_timing -early -max_paths 10 > reports/hold_timing.rpt

# Timing summary
report_timing -summary

# Check all paths
timeDesign -postRoute -prefix postRoute

# Fix timing violations if any
optDesign -postRoute -hold
optDesign -postRoute -setup

# Save final design
saveDesign bp_monitor_final.enc
```

### What to Check
| Check | Requirement | Example |
|-------|-------------|---------|
| Setup Slack | ≥ 0 | +0.45 ns ✓ |
| Hold Slack | ≥ 0 | +0.12 ns ✓ |
| Max Transition | < limit | 0.8 ns ✓ |
| Max Capacitance | < limit | 0.1 pF ✓ |

### Timing Report Example
```
Path 1: PASSED
  Startpoint: adc_data[0] (input port)
  Endpoint: systolic_bp_reg[7] (rising edge-triggered flip-flop)
  Path Group: clk
  Path Type: max (Setup)
  
  Slack: +0.45 ns ✓
```

---

## 10. Physical Verification

### Purpose
Ensure layout meets foundry rules and matches netlist.

### Tools
- Cadence Pegasus
- Mentor Calibre
- Synopsys IC Validator

### 10.1 DRC (Design Rule Check)

**Purpose:** Verify layout follows foundry manufacturing rules.

**Rules Checked:**
| Rule | Description |
|------|-------------|
| Minimum width | Metal line width |
| Minimum spacing | Gap between metals |
| Via coverage | Metal overlap on vias |
| Density | Metal fill requirements |

```tcl
# In Innovus
verifyGeometry

# Or export and run external tool:
write_gds bp_monitor_system.gds

# Run Pegasus DRC
# pegasus -drc bp_monitor_system.gds
```

### 10.2 LVS (Layout vs Schematic)

**Purpose:** Verify layout matches the netlist.

```tcl
# Export files for LVS
write_gds bp_monitor_system.gds
write_netlist bp_monitor_system.sp -format spice

# Run LVS
# pegasus -lvs bp_monitor_system.gds bp_monitor_system.sp
```

### Expected Results
```
DRC Summary:
  Total errors: 0 ✓
  
LVS Summary:
  Devices matched: 1,234 / 1,234 ✓
  Nets matched: 567 / 567 ✓
  Result: CLEAN ✓
```

---

## 11. Signoff

### Purpose
Final verification before tape-out.

### Signoff Checks

| Check | Tool | Description |
|-------|------|-------------|
| Timing | Tempus | Multi-corner STA |
| Power | Voltus | IR drop analysis |
| DRC | Pegasus | Final rule check |
| LVS | Pegasus | Final netlist match |
| Antenna | Innovus | Antenna rule check |
| ERC | Pegasus | Electrical rule check |

### Multi-Corner Timing
```tcl
# Check timing at all corners
set_analysis_view -setup {slow_corner} -hold {fast_corner}

# Report multi-corner timing
report_timing -view slow_corner
report_timing -view fast_corner
```

### IR Drop Analysis
```tcl
# In Voltus
read_power_rails
analyze_power_rails -net VDD
analyze_power_rails -net VSS

# Check IR drop < 10% of VDD
report_power_rails -type ir_drop
```

### Final Checklist
| Item | Status |
|------|--------|
| Setup timing clean | - |
| Hold timing clean | - |
| DRC clean (0 errors) | - |
| LVS clean (matched) | - |
| Antenna clean | - |
| IR drop < 10% | - |
| All pins connected | - |

---

## 12. Tape-out

### Purpose
Final handoff to semiconductor foundry.

### Output Files
| File | Format | Description |
|------|--------|-------------|
| Layout | GDSII (.gds) | Final layout database |
| Netlist | Verilog/SPICE | For verification |
| LEF | .lef | Abstract view |
| DEF | .def | Design exchange format |
| SDC | .sdc | Timing constraints |

### Generate Final Files
```tcl
# Generate final GDSII
streamOut bp_monitor_system_final.gds -mapFile /path/to/gds.map

# Generate LEF
write_lef bp_monitor_system.lef

# Generate DEF
write_def bp_monitor_system.def

# Generate final netlist
write_netlist bp_monitor_system_final.v

# Package all files
# zip tape_out_package.zip *.gds *.lef *.def *.v *.sdc
```

### Tape-out Checklist
| Item | File | Status |
|------|------|--------|
| Final GDSII | bp_monitor_system.gds | - |
| Final netlist | bp_monitor_system.v | - |
| Timing constraints | bp_monitor_system.sdc | - |
| DRC/LVS reports | drc.rpt, lvs.rpt | - |
| Timing report | timing_signoff.rpt | - |
| Power report | power_signoff.rpt | - |

---

## Complete Flow Summary

| Step | Tool | Input | Output | Time |
|------|------|-------|--------|------|
| 1. RTL | VS Code | Specs | design.v | Done |
| 2. Simulation | Icarus | RTL + TB | Pass/Fail | Done |
| 3. Synthesis | Genus | RTL + SDC | Netlist | 1-2 hrs |
| 4. Floorplan | Innovus | Netlist | .fp | 30 min |
| 5. Power Plan | Innovus | Floorplan | Power grid | 30 min |
| 6. Placement | Innovus | Power plan | Placed DEF | 1 hr |
| 7. CTS | Innovus | Placed DEF | Clock tree | 1 hr |
| 8. Routing | Innovus | CTS | Routed DEF | 2-3 hrs |
| 9. STA | Tempus | Routed DEF | Timing rpt | 1 hr |
| 10. DRC/LVS | Pegasus | GDS | Clean rpt | 1-2 hrs |
| 11. Signoff | All | All | Signoff rpt | 2-3 hrs |
| 12. Tape-out | - | All | GDSII | - |

---

## For Your BPMS Project

### Current Status
```
[DONE] RTL Design      - design.v ready
[DONE] Simulation      - 7/7 tests pass
[TODO] Synthesis       - Do in lab with Genus
[TODO] Place & Route   - Do in lab with Innovus
[TODO] Signoff         - Final verification
[TODO] Tape-out        - Submit GDSII
```

### Estimated Lab Time
| Session | Tasks |
|---------|-------|
| Lab 1 | Synthesis (Genus) |
| Lab 2 | Floorplan + Power + Placement |
| Lab 3 | CTS + Routing |
| Lab 4 | STA + DRC/LVS + Signoff |

---

## Quick Reference Commands

```tcl
# ============ GENUS ============
genus -f synthesis.tcl
report_timing
report_area
write_design -innovus

# ============ INNOVUS ============
innovus
read_db design.dat
floorplan -r 1.0 0.7 10 10 10 10
addRing -nets {VDD VSS}
place_design
ccopt_design
routeDesign
verifyConnectivity
write_gds design.gds

# ============ VERIFICATION ============
verifyGeometry        # DRC
verifyConnectivity    # LVS
report_timing         # STA
```

---

## Final Deliverables

When complete, you will have:

1. **GDSII file** - Physical layout for fabrication
2. **Gate-level netlist** - Synthesized Verilog
3. **Timing reports** - Proof of timing closure
4. **DRC/LVS reports** - Proof of clean layout
5. **Power analysis** - Power consumption data

The BPMS chip design is ready for fabrication.

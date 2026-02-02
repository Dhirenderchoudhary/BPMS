# BPMS Chip - Blood Pressure Monitoring System

A synthesizable Verilog design for real-time blood pressure monitoring with FIR noise filtering, peak detection, heart rate calculation, and automatic alerts.

## Verification Status

```
╔═══════════════════════════════════════════════════════════╗
║   Tests Passed:  7                                        ║
║   Tests Failed:  0                                        ║
║   STATUS: ALL TESTS PASSED ✓                             ║
╚═══════════════════════════════════════════════════════════╝
```

## Project Structure

```
RealDsa/
├── design.v          # RTL design (synthesizable)
├── testbench.v       # Verification testbench
├── synthesis.tcl     # Cadence Genus synthesis script
├── constraints.sdc   # Timing constraints
├── bp_sim            # Compiled simulation executable
├── bp_monitor.vcd    # Waveform dump file
└── README.md         # This file
```

## Design Specifications

| Parameter | Value |
|-----------|-------|
| Clock Frequency | 10 MHz |
| ADC Width | 12 bits |
| BP Output Width | 8 bits (0-255 mmHg) |
| FIR Filter Taps | 8 |
| Measurement Window | 1200 samples (~12 sec) |

## Module Hierarchy

```
bp_monitor_system (Top)
├── fir_filter        - 8-tap moving average noise filter
├── adc_to_bp (x2)    - ADC to mmHg conversion
└── bp_alert          - High/Low BP alert generation
    (+ internal state machine for peak detection & HR calculation)
```

## Port Description

### Inputs
| Port | Width | Description |
|------|-------|-------------|
| clk | 1 | System clock (10 MHz) |
| rst | 1 | Active-high synchronous reset |
| adc_data | 12 | Raw ADC input from BP sensor |
| adc_valid | 1 | ADC data valid strobe |

### Outputs
| Port | Width | Description |
|------|-------|-------------|
| systolic_bp | 8 | Systolic BP in mmHg |
| diastolic_bp | 8 | Diastolic BP in mmHg |
| heart_rate | 8 | Heart rate in BPM |
| bp_high_alert | 1 | High BP warning (≥140/90) |
| bp_low_alert | 1 | Low BP warning (≤90/60) |
| measurement_done | 1 | Measurement complete pulse |

---

## Complete ASIC Flow

### Step 1: Simulation (Icarus Verilog)
```bash
cd /Users/nexus/Desktop/RealDsa
iverilog -o bp_sim design.v testbench.v
vvp bp_sim
```

### Step 2: View Waveforms (GTKWave)
```bash
brew install gtkwave   # If not installed
gtkwave bp_monitor.vcd
```

### Step 3: Synthesis (Cadence Genus)
```bash
genus -f synthesis.tcl
```

**Or interactively:**
```bash
genus
source synthesis.tcl
```

### Step 4: Place & Route (Cadence Innovus)
```bash
innovus
# Load the design from Genus output:
# read_db synthesis_output/bp_monitor_system.dat
```

### Step 5: Signoff
- Run DRC/LVS checks
- Static Timing Analysis (STA)
- Power analysis

---

## Alert Thresholds

| Condition | Systolic | Diastolic |
|-----------|----------|-----------|
| High BP | ≥ 140 mmHg | ≥ 90 mmHg |
| Normal | 91-139 mmHg | 61-89 mmHg |
| Low BP | ≤ 90 mmHg | ≤ 60 mmHg |

## Test Cases

| Test | Target | Measured | Status |
|------|--------|----------|--------|
| Normal BP | 120/80, 72 BPM | 117/82, 65 BPM | ✓ PASS |
| High BP | 150/95, 85 BPM | 145/99, 80 BPM | ✓ PASS |
| Low BP | 85/55, 65 BPM | 82/57, 60 BPM | ✓ PASS |
| Elevated | 135/88, 78 BPM | 131/91, 75 BPM | ✓ PASS |
| Tachycardia | 125/82, 110 BPM | 121/85, 100 BPM | ✓ PASS |
| Reset Recovery | 120/80, 72 BPM | 117/82, 65 BPM | ✓ PASS |

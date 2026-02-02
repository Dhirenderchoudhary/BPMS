# BPMS Chip - Complete Design Flow Documentation

## 1. System Overview

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    BPMS CHIP - BLOCK DIAGRAM                            │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│   ┌──────────┐    ┌─────────────┐    ┌──────────────┐                  │
│   │  Blood   │    │   12-bit    │    │              │                  │
│   │ Pressure ├───►│    ADC      ├───►│  adc_data    │                  │
│   │  Sensor  │    │  (External) │    │  adc_valid   │                  │
│   └──────────┘    └─────────────┘    └──────┬───────┘                  │
│                                             │                           │
│   ┌─────────────────────────────────────────▼───────────────────────┐  │
│   │                     bp_monitor_system                            │  │
│   │  ┌─────────────────────────────────────────────────────────────┐│  │
│   │  │                                                             ││  │
│   │  │  ┌────────────┐   ┌─────────────────────────────────────┐  ││  │
│   │  │  │            │   │         STATE MACHINE               │  ││  │
│   │  │  │ FIR Filter │   │  ┌──────┐  ┌───────────┐  ┌──────┐ │  ││  │
│   │  │  │  (8-tap)   ├──►│  │ IDLE │─►│ MEASURING │─►│ DONE │ │  ││  │
│   │  │  │            │   │  └──────┘  └───────────┘  └──────┘ │  ││  │
│   │  │  └────────────┘   │       │                       │     │  ││  │
│   │  │                   │       │  Peak Detection       │     │  ││  │
│   │  │                   │       │  HR Calculation       │     │  ││  │
│   │  │                   │       │  Min/Max Tracking     │     │  ││  │
│   │  │                   └───────┴───────────────────────┴─────┘  ││  │
│   │  │                                                             ││  │
│   │  │  ┌────────────┐   ┌────────────┐   ┌────────────────────┐  ││  │
│   │  │  │ adc_to_bp  │   │ adc_to_bp  │   │     bp_alert       │  ││  │
│   │  │  │ (systolic) │   │(diastolic) │   │  (high/low check)  │  ││  │
│   │  │  └─────┬──────┘   └─────┬──────┘   └─────────┬──────────┘  ││  │
│   │  │        │                │                    │              ││  │
│   │  └────────┴────────────────┴────────────────────┴──────────────┘│  │
│   │                                                                  │  │
│   └──────────────────────────────────────────────────────────────────┘  │
│              │              │            │          │         │         │
│              ▼              ▼            ▼          ▼         ▼         │
│        ┌──────────┐  ┌───────────┐  ┌─────────┐ ┌──────┐ ┌──────┐      │
│        │systolic  │  │diastolic  │  │heart    │ │high  │ │low   │      │
│        │_bp [7:0] │  │_bp [7:0]  │  │_rate[7:0│ │_alert│ │_alert│      │
│        └──────────┘  └───────────┘  └─────────┘ └──────┘ └──────┘      │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Signal Flow

```
Step 1: ADC Input (External)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Blood Pressure Sensor → ADC → adc_data[11:0] + adc_valid
                              (0-4095 range, 12-bit resolution)

Step 2: Noise Filtering
━━━━━━━━━━━━━━━━━━━━━━━
adc_data → FIR Filter (8-tap moving average) → filtered_data
           Removes high-frequency noise from sensor

Step 3: Peak Detection (During Measurement)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
filtered_data → Track running_max (systolic peak)
              → Track running_min (diastolic trough)
              → Count threshold crossings (heart rate)

Step 4: ADC to mmHg Conversion
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
running_max → adc_to_bp → systolic_bp (mmHg)
running_min → adc_to_bp → diastolic_bp (mmHg)

Step 5: Alert Generation
━━━━━━━━━━━━━━━━━━━━━━━━
systolic_bp, diastolic_bp → bp_alert → high_alert / low_alert
```

---

## 3. Module Details

### 3.1 FIR Filter (`fir_filter`)

**Purpose:** Remove high-frequency noise from the raw ADC signal

**Algorithm:** 8-tap Moving Average Filter
```
output = (tap0 + tap1 + tap2 + tap3 + tap4 + tap5 + tap6 + tap7) / 8
```

**Implementation:**
```
Clock Cycle:    1    2    3    4    5    6    7    8    9
─────────────────────────────────────────────────────────
Input:         S1   S2   S3   S4   S5   S6   S7   S8   S9
tap0:          S1   S2   S3   S4   S5   S6   S7   S8   S9
tap1:           0   S1   S2   S3   S4   S5   S6   S7   S8
tap2:           0    0   S1   S2   S3   S4   S5   S6   S7
...
tap7:           0    0    0    0    0    0    0   S1   S2
─────────────────────────────────────────────────────────
Output:        S1/8 avg  avg  avg  avg  avg  avg  avg  avg
```

**Verilog Key Code:**
```verilog
assign sum = tap0 + tap1 + tap2 + tap3 + tap4 + tap5 + tap6 + tap7;
data_out <= sum[WIDTH+2:3];  // Divide by 8 (shift right 3)
```

---

### 3.2 State Machine (Main Controller)

**States:**
```
┌──────────────────────────────────────────────────────────────┐
│                                                              │
│   ┌──────┐         ┌───────────┐         ┌──────┐           │
│   │      │ filter  │           │ 1200    │      │           │
│   │ IDLE │────────►│ MEASURING │────────►│ DONE │           │
│   │      │ _valid  │           │ samples │      │           │
│   └──┬───┘         └───────────┘         └──┬───┘           │
│      │                                       │               │
│      │              ┌───────────────────────┐│               │
│      │              │ In MEASURING state:   ││               │
│      │              │ • Count samples       ││               │
│      │              │ • Track max/min       ││               │
│      │              │ • Detect peaks for HR ││               │
│      │              └───────────────────────┘│               │
│      │                                       │               │
│      └───────────────────────────────────────┘               │
│                    (loop back)                               │
└──────────────────────────────────────────────────────────────┘
```

**Timing:**
- Sample Rate: ~100 samples/second (based on testbench)
- Measurement Window: 1200 samples = ~12 seconds
- Filter Warmup: First 16 samples ignored for min/max

---

### 3.3 Peak Detection (Systolic/Diastolic)

**Blood Pressure Waveform:**
```
Pressure                          Systolic Peak (Max)
(mmHg)                                  ▲
   ▲                                ┌───┴───┐
   │                            ┌───┘       └───┐
   │                        ┌───┘               └───┐
   │                    ┌───┘                       └───┐
   │  Diastolic (Min)  ─┘                               └───
   │        ▼
   └─────────────────────────────────────────────────────────► Time
         1 cardiac cycle (~0.8 sec at 72 BPM)
```

**Algorithm:**
```verilog
// Track maximum (systolic)
if (filtered_data > running_max)
    running_max <= filtered_data;

// Track minimum (diastolic)  
if (filtered_data < running_min)
    running_min <= filtered_data;
```

---

### 3.4 Heart Rate Calculation

**Method:** Count threshold crossings (peak detection)

```
Signal:     ────╱╲────╱╲────╱╲────╱╲────╱╲────
               ┃    ┃    ┃    ┃    ┃
Threshold: ────┃────┃────┃────┃────┃────────── 50% of range
               ┃    ┃    ┃    ┃    ┃
Crossings:     1    2    3    4    5  = 5 peaks in 12 sec

HR = peaks × 5 = 5 × 5 = 25 BPM (example)
Actual: ~14 peaks × 5 = 70 BPM (normal)
```

**Verilog Key Code:**
```verilog
// Threshold = midpoint of signal range
threshold <= running_min + ((running_max - running_min) >> 1);

// Count rising edge crossings
if (!above_thresh && filtered_data > threshold) begin
    above_thresh <= 1'b1;
end else if (above_thresh && filtered_data < threshold) begin
    above_thresh <= 1'b0;
    peak_count <= peak_count + 1'b1;  // Count peak
end
```

---

### 3.5 ADC to mmHg Conversion (`adc_to_bp`)

**Mapping:**
```
ADC Value:    0 ──────────────────────────────► 4095
              │                                  │
              ▼                                  ▼
BP (mmHg):   ~0 ──────────────────────────────► ~267

Formula: bp_mmhg = (adc_val × 67) >> 10
         (Approximates: adc / 15.3)
```

**Example Conversions:**
| ADC Value | Calculation | BP (mmHg) |
|-----------|-------------|-----------|
| 1836 | (1836 × 67) >> 10 | ~120 |
| 1224 | (1224 × 67) >> 10 | ~80 |
| 2295 | (2295 × 67) >> 10 | ~150 |

---

### 3.6 Alert Logic (`bp_alert`)

**Thresholds:**
```
                    LOW          NORMAL         HIGH
                     │              │              │
Systolic:    ────────┼──────────────┼──────────────┼────────
                   90 mmHg                      140 mmHg
                     │              │              │
Diastolic:   ────────┼──────────────┼──────────────┼────────
                   60 mmHg                       90 mmHg
```

**Logic:**
```verilog
assign high_alert = (systolic >= 140) || (diastolic >= 90);
assign low_alert  = (systolic <= 90)  || (diastolic <= 60);
```

---

## 4. Timing Diagram

```
Clock:      ┌──┐  ┌──┐  ┌──┐  ┌──┐  ┌──┐  ┌──┐  ┌──┐  ┌──┐
            ┘  └──┘  └──┘  └──┘  └──┘  └──┘  └──┘  └──┘  └──

adc_valid:  ────┐     ┌─────┐     ┌─────┐     ┌─────┐
                └─────┘     └─────┘     └─────┘     └─────

adc_data:   ──X──1500──X──1520──X──1480──X──1510──X────────
              
filter_out: ──X───0───X──750──X──1010──X──1125──X────────
                (warmup)

state:      ──IDLE──────MEASURING───────────────────DONE──

sample_cnt: ──0────────1────2────3────...────1199────0────

meas_done:  ──────────────────────────────────────┐    ┌──
                                                  └────┘

systolic:   ──120──────120──────────────────────┐
                                                └──145────
```

---

## 5. Design Specifications Summary

| Parameter | Value | Description |
|-----------|-------|-------------|
| Clock | 10 MHz | 100ns period |
| ADC Width | 12 bits | 0-4095 range |
| Output Width | 8 bits | 0-255 mmHg |
| Filter Taps | 8 | Moving average |
| Sample Count | 1200 | Per measurement |
| Warmup Samples | 16 | Filter settling |
| Measurement Time | ~12 sec | At 100 samples/sec |

---

## 6. Synthesis Considerations

### Synthesizable Constructs Used:
- Synchronous reset (active high)
- Single clock domain
- Registered outputs
- Fixed-point arithmetic only
- No latches (all regs in always @(posedge clk))
- Parameterized widths

### Critical Paths:
1. **FIR Accumulator:** 8 additions + shift
2. **ADC Conversion:** 1 multiply + shift
3. **Comparison Logic:** Alert threshold checks

### Estimated Resources:
| Resource | Estimate |
|----------|----------|
| Flip-Flops | ~300 |
| LUTs/Gates | ~800 |
| Multipliers | 2 (for adc_to_bp) |

---

## 7. Verification Coverage

| Test Case | Systolic | Diastolic | HR | Alert | Status |
|-----------|----------|-----------|-----|-------|--------|
| Normal | 120 | 80 | 72 | None | Pass |
| High BP | 150 | 95 | 85 | HIGH | Pass |
| Low BP | 85 | 55 | 65 | LOW | Pass |
| Elevated | 135 | 88 | 78 | - | Pass |
| Tachycardia | 125 | 82 | 110 | - | Pass |
| Reset | 120 | 80 | 72 | - | Pass |

---

## 8. ASIC Implementation Flow

```
┌─────────────────────────────────────────────────────────────┐
│                    ASIC DESIGN FLOW                         │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌─────────────┐                                           │
│  │ 1. RTL      │  design.v                                 │
│  │    Design   │  (complete)                               │
│  └──────┬──────┘                                           │
│         ▼                                                   │
│  ┌─────────────┐                                           │
│  │ 2. Simulate │  testbench.v - All tests pass            │
│  │    (Icarus) │                                           │
│  └──────┬──────┘                                           │
│         ▼                                                   │
│  ┌─────────────┐                                           │
│  │ 3. Synthesis│  Cadence Genus + synthesis.tcl            │
│  │    (Genus)  │  → Gate-level netlist                     │
│  └──────┬──────┘                                           │
│         ▼                                                   │
│  ┌─────────────┐                                           │
│  │ 4. Place &  │  Cadence Innovus                          │
│  │    Route    │  → Physical layout                        │
│  └──────┬──────┘                                           │
│         ▼                                                   │
│  ┌─────────────┐                                           │
│  │ 5. Signoff  │  DRC, LVS, STA, Power                     │
│  │             │  → Final verification                     │
│  └──────┬──────┘                                           │
│         ▼                                                   │
│  ┌─────────────┐                                           │
│  │ 6. Tape-out │  GDSII → Fabrication                      │
│  │             │                                           │
│  └─────────────┘                                           │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## 9. Quick Reference Commands

```bash
# Simulate
iverilog -o bp_sim design.v testbench.v && vvp bp_sim

# View waveforms
gtkwave bp_monitor.vcd

# Synthesize (Genus)
genus -f synthesis.tcl

# Check timing (in Genus)
report_timing -max_paths 10

# Check area (in Genus)
report_area
```

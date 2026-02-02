`timescale 1ns/1ps
//////////////////////////////////////////////////////////////////////////////
// BPMS Chip - Testbench
// Comprehensive verification for Blood Pressure Monitoring System
//////////////////////////////////////////////////////////////////////////////

module bp_monitor_tb;

    // Clock and reset
    reg clk;
    reg rst;
    
    // DUT signals
    reg  [11:0] adc_data;
    reg         adc_valid;
    wire [7:0]  systolic_bp;
    wire [7:0]  diastolic_bp;
    wire [7:0]  heart_rate;
    wire        bp_high_alert;
    wire        bp_low_alert;
    wire        measurement_done;

    // Test variables
    integer i;
    integer test_pass;
    integer test_fail;
    real pi;
    
    // Instantiate DUT
    bp_monitor_system uut (
        .clk             (clk),
        .rst             (rst),
        .adc_data        (adc_data),
        .adc_valid       (adc_valid),
        .systolic_bp     (systolic_bp),
        .diastolic_bp    (diastolic_bp),
        .heart_rate      (heart_rate),
        .bp_high_alert   (bp_high_alert),
        .bp_low_alert    (bp_low_alert),
        .measurement_done(measurement_done)
    );

    // Clock generation: 10 MHz (100ns period)
    initial begin
        clk = 0;
        forever #50 clk = ~clk;
    end
    
    // Initialize pi
    initial pi = 3.14159265358979;

    //=========================================================================
    // Task: Generate BP waveform signal
    // Simulates realistic blood pressure sensor ADC output
    //=========================================================================
    task generate_bp_waveform;
        input [7:0] target_systolic;   // Target systolic BP in mmHg
        input [7:0] target_diastolic;  // Target diastolic BP in mmHg
        input [7:0] target_hr;         // Target heart rate in BPM
        input integer num_samples;     // Number of samples to generate
        
        real t;
        real freq;
        real sys_adc, dia_adc;
        real amplitude, offset;
        real waveform;
        real noise;
        integer sample;
        integer seed;
        
        begin
            seed = 42;
            
            // Convert BP to ADC values (inverse of adc_to_bp)
            // bp = (adc * 67) >> 10, so adc = bp * 1024 / 67 ≈ bp * 15.3
            sys_adc = target_systolic * 15.3;
            dia_adc = target_diastolic * 15.3;
            
            amplitude = (sys_adc - dia_adc) / 2.0;
            offset = (sys_adc + dia_adc) / 2.0;
            
            // Heart rate to frequency (Hz)
            // At 100 samples/sec, period in samples = 6000/HR
            freq = target_hr / 60.0;
            
            $display("  Generating %0d samples...", num_samples);
            $display("  ADC range: %0.0f - %0.0f", dia_adc, sys_adc);
            
            for (sample = 0; sample < num_samples; sample = sample + 1) begin
                // Time in seconds (assuming 100 samples/sec)
                t = sample / 100.0;
                
                // Generate BP-like waveform using sine + harmonics
                // This creates a more realistic arterial pressure waveform
                waveform = $sin(2.0 * pi * freq * t);
                
                // Add second harmonic for sharper systolic peak
                waveform = waveform + 0.3 * $sin(4.0 * pi * freq * t);
                
                // Normalize to -1 to 1 range
                waveform = waveform / 1.3;
                
                // Add small random noise
                noise = ($random(seed) % 50) / 500.0;
                
                // Scale to ADC range
                adc_data = offset + (amplitude * waveform) + (noise * 20);
                
                // Clamp to 12-bit range
                if (adc_data > 4095) adc_data = 4095;
                if (adc_data < 0) adc_data = 0;
                
                // Pulse adc_valid
                adc_valid = 1;
                @(posedge clk);
                adc_valid = 0;
                @(posedge clk);
                @(posedge clk);  // Extra cycle for pipeline
            end
            
            // Allow time for measurement_done to propagate
            repeat(10) @(posedge clk);
        end
    endtask

    //=========================================================================
    // Task: Wait for measurement to complete
    //=========================================================================
    task wait_for_measurement;
        integer timeout_cnt;
        begin
            timeout_cnt = 0;
            while (measurement_done == 0 && timeout_cnt < 5000) begin
                @(posedge clk);
                timeout_cnt = timeout_cnt + 1;
            end
            if (timeout_cnt >= 5000)
                $display("  [WARN] Measurement wait timeout");
            @(posedge clk);
            @(posedge clk);
        end
    endtask

    //=========================================================================
    // Task: Display measurement results
    //=========================================================================
    task display_results;
        input [7:0] expected_sys;
        input [7:0] expected_dia;
        input [7:0] expected_hr;
        input integer tolerance;
        
        integer sys_err, dia_err, hr_err;
        integer pass;
        
        begin
            pass = 1;
            
            $display("\n  ┌─────────────────────────────────────────────────┐");
            $display("  │            MEASUREMENT RESULTS                  │");
            $display("  ├─────────────────────────────────────────────────┤");
            $display("  │ Systolic BP:    %3d mmHg (expected: %3d)       │", 
                     systolic_bp, expected_sys);
            $display("  │ Diastolic BP:   %3d mmHg (expected: %3d)       │", 
                     diastolic_bp, expected_dia);
            $display("  │ Heart Rate:     %3d BPM  (expected: %3d)       │", 
                     heart_rate, expected_hr);
            $display("  ├─────────────────────────────────────────────────┤");
            
            // Check alerts
            if (bp_high_alert)
                $display("  │ ⚠ HIGH BLOOD PRESSURE ALERT                    │");
            else if (bp_low_alert)
                $display("  │ ⚠ LOW BLOOD PRESSURE ALERT                     │");
            else
                $display("  │ ✓ Blood pressure in normal range               │");
            
            $display("  └─────────────────────────────────────────────────┘");
            
            // Validate results
            sys_err = (systolic_bp > expected_sys) ? 
                      (systolic_bp - expected_sys) : (expected_sys - systolic_bp);
            dia_err = (diastolic_bp > expected_dia) ? 
                      (diastolic_bp - expected_dia) : (expected_dia - diastolic_bp);
            hr_err = (heart_rate > expected_hr) ? 
                     (heart_rate - expected_hr) : (expected_hr - heart_rate);
            
            if (sys_err > tolerance || dia_err > tolerance || hr_err > 20) begin
                $display("  [FAIL] Results outside tolerance!");
                pass = 0;
            end else begin
                $display("  [PASS] Results within tolerance");
            end
            
            if (pass)
                test_pass = test_pass + 1;
            else
                test_fail = test_fail + 1;
        end
    endtask

    //=========================================================================
    // Main Test Sequence
    //=========================================================================
    initial begin
        // Initialize
        rst = 1;
        adc_data = 0;
        adc_valid = 0;
        test_pass = 0;
        test_fail = 0;
        
        // VCD dump for waveform viewing
        $dumpfile("bp_monitor.vcd");
        $dumpvars(0, bp_monitor_tb);
        
        $display("\n");
        $display("╔═══════════════════════════════════════════════════════════╗");
        $display("║     BPMS CHIP VERIFICATION TESTBENCH                      ║");
        $display("║     Blood Pressure Monitoring System                      ║");
        $display("╚═══════════════════════════════════════════════════════════╝");
        $display("");
        
        // Reset sequence
        #500;
        rst = 0;
        #500;
        
        //=====================================================================
        // TEST CASE 1: Normal Blood Pressure (120/80, 72 BPM)
        //=====================================================================
        $display("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
        $display("TEST CASE 1: Normal Blood Pressure");
        $display("Target: 120/80 mmHg, 72 BPM");
        $display("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
        
        generate_bp_waveform(120, 80, 72, 1200);
        wait_for_measurement();
        display_results(120, 80, 72, 20);
        
        // Check: should NOT have any alerts
        if (bp_high_alert || bp_low_alert) begin
            $display("  [WARN] Unexpected alert for normal BP!");
        end
        
        #2000;
        
        //=====================================================================
        // TEST CASE 2: High Blood Pressure (150/95, 85 BPM)
        //=====================================================================
        $display("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
        $display("TEST CASE 2: High Blood Pressure (Hypertension)");
        $display("Target: 150/95 mmHg, 85 BPM");
        $display("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
        
        generate_bp_waveform(150, 95, 85, 1200);
        wait_for_measurement();
        display_results(150, 95, 85, 20);
        
        // Check: should have HIGH alert
        if (!bp_high_alert) begin
            $display("  [WARN] Expected HIGH BP alert not triggered!");
        end else begin
            $display("  [PASS] HIGH BP alert correctly triggered");
        end
        
        #2000;
        
        //=====================================================================
        // TEST CASE 3: Low Blood Pressure (85/55, 65 BPM)
        //=====================================================================
        $display("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
        $display("TEST CASE 3: Low Blood Pressure (Hypotension)");
        $display("Target: 85/55 mmHg, 65 BPM");
        $display("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
        
        generate_bp_waveform(85, 55, 65, 1200);
        wait_for_measurement();
        display_results(85, 55, 65, 20);
        
        // Check: should have LOW alert
        if (!bp_low_alert) begin
            $display("  [WARN] Expected LOW BP alert not triggered!");
        end else begin
            $display("  [PASS] LOW BP alert correctly triggered");
        end
        
        #2000;
        
        //=====================================================================
        // TEST CASE 4: Elevated Blood Pressure (135/88, 78 BPM)
        //=====================================================================
        $display("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
        $display("TEST CASE 4: Elevated Blood Pressure");
        $display("Target: 135/88 mmHg, 78 BPM");
        $display("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
        
        generate_bp_waveform(135, 88, 78, 1200);
        wait_for_measurement();
        display_results(135, 88, 78, 20);
        
        #2000;
        
        //=====================================================================
        // TEST CASE 5: Tachycardia (125/82, 110 BPM)
        //=====================================================================
        $display("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
        $display("TEST CASE 5: High Heart Rate (Tachycardia)");
        $display("Target: 125/82 mmHg, 110 BPM");
        $display("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
        
        generate_bp_waveform(125, 82, 110, 1200);
        wait_for_measurement();
        display_results(125, 82, 110, 20);
        
        #2000;
        
        //=====================================================================
        // TEST CASE 6: Reset During Measurement
        //=====================================================================
        $display("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
        $display("TEST CASE 6: Reset Recovery Test");
        $display("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
        
        // Start measurement
        generate_bp_waveform(120, 80, 72, 600);  // Partial measurement
        
        // Apply reset mid-measurement
        $display("  Applying reset during measurement...");
        rst = 1;
        #200;
        rst = 0;
        #200;
        
        // Verify default values after reset
        if (systolic_bp == 120 && diastolic_bp == 80 && heart_rate == 72) begin
            $display("  [PASS] Reset to default values successful");
            test_pass = test_pass + 1;
        end else begin
            $display("  [FAIL] Reset did not restore defaults");
            test_fail = test_fail + 1;
        end
        
        // Complete a new measurement after reset
        $display("  Completing measurement after reset...");
        generate_bp_waveform(120, 80, 72, 1200);
        wait_for_measurement();
        display_results(120, 80, 72, 20);
        
        #2000;
        
        //=====================================================================
        // Test Summary
        //=====================================================================
        $display("\n");
        $display("╔═══════════════════════════════════════════════════════════╗");
        $display("║                    TEST SUMMARY                           ║");
        $display("╠═══════════════════════════════════════════════════════════╣");
        $display("║   Tests Passed: %2d                                        ║", test_pass);
        $display("║   Tests Failed: %2d                                        ║", test_fail);
        $display("║   Total Tests:  %2d                                        ║", test_pass + test_fail);
        $display("╠═══════════════════════════════════════════════════════════╣");
        
        if (test_fail == 0) begin
            $display("║   STATUS: ALL TESTS PASSED ✓                             ║");
        end else begin
            $display("║   STATUS: SOME TESTS FAILED ✗                            ║");
        end
        
        $display("╚═══════════════════════════════════════════════════════════╝");
        $display("");
        
        #5000;
        $finish;
    end

    //=========================================================================
    // Timeout Watchdog
    //=========================================================================
    initial begin
        #50_000_000;  // 50ms timeout
        $display("\n[ERROR] Simulation timeout!");
        $display("Check for hanging states or infinite loops.");
        $finish;
    end

    //=========================================================================
    // Measurement Complete Monitor
    //=========================================================================
    always @(posedge measurement_done) begin
        $display("\n  >>> Measurement complete at time %0t", $time);
    end

endmodule

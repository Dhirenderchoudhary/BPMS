`timescale 1ns/1ps
//////////////////////////////////////////////////////////////////////////////
// BPMS Chip - Blood Pressure Monitoring System
// Synthesizable Design for Cadence Genus
// Features: FIR Filtering, Peak Detection, Heart Rate Calculation, BP Alerts
//////////////////////////////////////////////////////////////////////////////

///////////////////////////////////////////////
// FIR Filter - 8-Tap Moving Average
// Synthesizable implementation
///////////////////////////////////////////////
module fir_filter #(
    parameter WIDTH = 12
)(
    input                  clk,
    input                  rst,
    input                  data_valid,
    input      [WIDTH-1:0] data_in,
    output reg [WIDTH-1:0] data_out,
    output reg             out_valid
);

    // 8-tap shift register
    reg [WIDTH-1:0] tap0, tap1, tap2, tap3, tap4, tap5, tap6, tap7;
    
    // Wider accumulator to prevent overflow (WIDTH + 3 bits for 8 taps)
    wire [WIDTH+2:0] sum;
    
    assign sum = tap0 + tap1 + tap2 + tap3 + tap4 + tap5 + tap6 + tap7;

    always @(posedge clk) begin
        if (rst) begin
            tap0 <= {WIDTH{1'b0}};
            tap1 <= {WIDTH{1'b0}};
            tap2 <= {WIDTH{1'b0}};
            tap3 <= {WIDTH{1'b0}};
            tap4 <= {WIDTH{1'b0}};
            tap5 <= {WIDTH{1'b0}};
            tap6 <= {WIDTH{1'b0}};
            tap7 <= {WIDTH{1'b0}};
            data_out <= {WIDTH{1'b0}};
            out_valid <= 1'b0;
        end else begin
            out_valid <= 1'b0;
            if (data_valid) begin
                // Shift register
                tap0 <= data_in;
                tap1 <= tap0;
                tap2 <= tap1;
                tap3 <= tap2;
                tap4 <= tap3;
                tap5 <= tap4;
                tap6 <= tap5;
                tap7 <= tap6;
                
                // Average = sum / 8 (right shift by 3)
                data_out <= sum[WIDTH+2:3];
                out_valid <= 1'b1;
            end
        end
    end
endmodule


///////////////////////////////////////////////
// ADC Value to mmHg Converter
// Linear scaling from 12-bit ADC to BP value
///////////////////////////////////////////////
module adc_to_bp #(
    parameter ADC_WIDTH = 12
)(
    input      [ADC_WIDTH-1:0] adc_val,
    output     [7:0]           bp_mmhg
);
    // Mapping: ADC value to BP in mmHg
    // Using: bp = (adc * 67) >> 10 for proper scaling
    wire [19:0] scaled;
    
    assign scaled = (adc_val * 8'd67) >> 10;
    
    // Clamp to valid BP range (30-250 mmHg)
    assign bp_mmhg = (scaled > 20'd250) ? 8'd250 : 
                     (scaled < 20'd30)  ? 8'd30  : scaled[7:0];
endmodule


///////////////////////////////////////////////
// BP Alert Module
// Generates alerts for abnormal blood pressure
///////////////////////////////////////////////
module bp_alert (
    input      [7:0] systolic,
    input      [7:0] diastolic,
    output           high_alert,
    output           low_alert
);
    // Thresholds (in mmHg)
    localparam SYS_HIGH  = 8'd140;
    localparam SYS_LOW   = 8'd90;
    localparam DIA_HIGH  = 8'd90;
    localparam DIA_LOW   = 8'd60;

    assign high_alert = (systolic >= SYS_HIGH) || (diastolic >= DIA_HIGH);
    assign low_alert  = (systolic <= SYS_LOW)  || (diastolic <= DIA_LOW);
endmodule


///////////////////////////////////////////////
// Top-Level: BP Monitor System
// Complete blood pressure monitoring chip
///////////////////////////////////////////////
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

    // Parameters
    localparam SAMPLE_CNT = 1200;
    
    // Internal signals
    wire [11:0] filtered_data;
    wire        filter_valid;
    wire [7:0]  peak_mmhg;
    wire [7:0]  trough_mmhg;
    
    // State machine states
    localparam IDLE       = 2'b00;
    localparam MEASURING  = 2'b01;
    localparam DONE       = 2'b10;
    
    reg [1:0] state;
    reg [15:0] sample_count;
    
    // Peak/Trough tracking (12-bit ADC values)
    reg [11:0] running_max;
    reg [11:0] running_min;
    reg [11:0] final_max;
    reg [11:0] final_min;
    
    // Heart rate calculation
    reg [11:0] prev_sample;
    reg [11:0] threshold;
    reg [7:0]  peak_count;
    reg        above_thresh;
    reg        thresh_valid;
    
    // FIR Filter for noise reduction
    fir_filter #(.WIDTH(12)) u_fir (
        .clk       (clk),
        .rst       (rst),
        .data_valid(adc_valid),
        .data_in   (adc_data),
        .data_out  (filtered_data),
        .out_valid (filter_valid)
    );
    
    // ADC to BP converters
    adc_to_bp u_sys_conv (
        .adc_val(final_max),
        .bp_mmhg(peak_mmhg)
    );
    
    adc_to_bp u_dia_conv (
        .adc_val(final_min),
        .bp_mmhg(trough_mmhg)
    );
    
    // Alert logic (combinational)
    bp_alert u_alert (
        .systolic  (systolic_bp),
        .diastolic (diastolic_bp),
        .high_alert(bp_high_alert),
        .low_alert (bp_low_alert)
    );

    // Main state machine and processing
    always @(posedge clk) begin
        if (rst) begin
            state <= IDLE;
            sample_count <= 16'd0;
            running_max <= 12'd0;
            running_min <= 12'hFFF;
            final_max <= 12'd1836;      // Default ~120 mmHg
            final_min <= 12'd1224;      // Default ~80 mmHg
            systolic_bp <= 8'd120;
            diastolic_bp <= 8'd80;
            heart_rate <= 8'd72;
            measurement_done <= 1'b0;
            prev_sample <= 12'd0;
            threshold <= 12'd2048;
            peak_count <= 8'd0;
            above_thresh <= 1'b0;
            thresh_valid <= 1'b0;
        end else begin
            measurement_done <= 1'b0;
            
            case (state)
                IDLE: begin
                    if (filter_valid) begin
                        state <= MEASURING;
                        sample_count <= 16'd1;
                        running_max <= 12'd0;      // Start fresh
                        running_min <= 12'hFFF;    // Start at max
                        prev_sample <= filtered_data;
                        peak_count <= 8'd0;
                        above_thresh <= 1'b0;
                        thresh_valid <= 1'b0;
                    end
                end
                
                MEASURING: begin
                    if (filter_valid) begin
                        sample_count <= sample_count + 1'b1;
                        prev_sample <= filtered_data;
                        
                        // Skip first 16 samples for filter warmup
                        if (sample_count > 16'd16) begin
                            // Track max/min after warmup
                            if (filtered_data > running_max)
                                running_max <= filtered_data;
                            if (filtered_data < running_min)
                                running_min <= filtered_data;
                        end
                        
                        // Calculate threshold after 100 samples
                        if (sample_count == 16'd100) begin
                            threshold <= running_min + ((running_max - running_min) >> 1);
                            thresh_valid <= 1'b1;
                        end
                        
                        // Peak detection for heart rate
                        if (thresh_valid) begin
                            if (!above_thresh && filtered_data > threshold) begin
                                above_thresh <= 1'b1;
                            end else if (above_thresh && filtered_data < threshold) begin
                                above_thresh <= 1'b0;
                                peak_count <= peak_count + 1'b1;
                            end
                        end
                        
                        // Check if measurement complete
                        if (sample_count >= SAMPLE_CNT - 1) begin
                            state <= DONE;
                            final_max <= running_max;
                            final_min <= running_min;
                        end
                    end
                end
                
                DONE: begin
                    // Update outputs
                    systolic_bp <= peak_mmhg;
                    diastolic_bp <= trough_mmhg;
                    
                    // Calculate heart rate: peaks * 5 (for 12-second window at 100 samples/sec)
                    if (peak_count > 8'd0)
                        heart_rate <= peak_count * 8'd5;
                    else
                        heart_rate <= 8'd72;
                    
                    measurement_done <= 1'b1;
                    
                    // Reset for next measurement
                    state <= IDLE;
                    sample_count <= 16'd0;
                    running_max <= 12'd0;
                    running_min <= 12'hFFF;
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule

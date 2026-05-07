# Caterpillar-Tech-Challenge-2026-AI-Diagnostic-Pipeline

## Overview

This is a complete MATLAB implementation of an AI/ML diagnostic pipeline for **diesel engine air leak detection and isolation**. The system uses physics-based residual signals from a Simulink engine model and applies a multi-layer architecture combining K-Means clustering, Gaussian Process classification, and temporal filtering.

## Key Features

- **Layer 3**: K-Means clustering on no-fault data to identify operating regimes and compute per-regime normalization tables
- **Layer 4**: 5-class Gaussian Process classifiers (one-vs-rest strategy) for leak zone classification
- **Layer 5**: Persistence filter with hysteresis to prevent false alerts from noise spikes
- **Layer 6**: Output engine that assembles human-readable diagnostic strings

## System Architecture

### Inputs
Three physics-based residual signals from a Simulink engine simulation:
- `r1`: Mass balance residual (MAF sensor vs compressor predicted flow)
- `r2`: Charge-air pressure ratio residual (compressor outlet vs intake manifold)
- `r3`: Exhaust energy balance residual (EGT + backpressure composite)

### Outputs
Four required diagnostic outputs:
1. **FLAG**: "LEAK DETECTED" / "NO LEAK" / "UNCERTAIN — MONITORING"
2. **CONFIDENCE**: Calibrated posterior probability with uncertainty bounds (e.g., "84% ± 5%")
3. **LOCATION**: Which diagnostic zone (A, B, C, or D)
4. **ACTION**: Specific physical inspection recommendation for the engineer

### Fault Zones
- **Zone 0**: No fault
- **Zone 1 (A)**: Leak between MAF sensor and turbocharger compressor inlet
- **Zone 2 (B)**: Leak in charge-air system (compressor outlet through CAC/intercooler to intake manifold)
- **Zone 3 (C)**: Exhaust leak pre-turbine (exhaust manifold → turbine inlet)
- **Zone 4 (D)**: Exhaust leak post-turbine (turbine outlet → aftertreatment → tailpipe)

## Files Included

### Training & Validation Scripts
1. **step1_check_training_data.m** — Load and inspect `training_data_raw.mat`
2. **step2_train_normalizer.m** — K-Means clustering + per-regime variance (saves `normalizer_params.mat`)
3. **step3_train_GP_classifier.m** — Train 5 binary GP classifiers (saves `GP_classifier.mat`)
4. **step4_test_single_prediction.m** — Manual test on 6 known residual patterns
5. **step5_run_full_pipeline_test.m** — End-to-end integration test on synthetic sequences
6. **step6_validate_performance.m** — Cross-validation, MDL computation, performance metrics

### Core Runtime Functions
- **predict_leak_zone.m** — Master prediction function (queries GPs, applies magnitude gate)
- **persistence_filter.m** — Temporal smoothing with persistence threshold + hysteresis
- **reset_persistence_filter.m** — Reset persistent state between simulation runs
- **assemble_output.m** — Assemble human-readable diagnostic strings

### Visualization & Integration
- **plot_residual_space.m** — 3D scatter plot of training data for presentations
- **GP_Classifier_Simulink_Block.m** — Copy this function into a Simulink MATLAB Function block

## Quick Start

### Prerequisites
- MATLAB R2021a or later
- Statistics and Machine Learning Toolbox

### Training Pipeline
```matlab
% 1. Verify training data
step1_check_training_data

% 2. Train normalizer (K-Means)
step2_train_normalizer

% 3. Train GP classifiers
step3_train_GP_classifier

% 4. Test on known cases
step4_test_single_prediction

% 5. Integration test
step5_run_full_pipeline_test

% 6. Performance validation
step6_validate_performance

% 7. Create presentation visuals
plot_residual_space
```

### Using in Simulink
1. Copy the contents of `GP_Classifier_Simulink_Block.m` into a MATLAB Function block
2. Make sure `GP_classifier.mat` and `normalizer_params.mat` are on the MATLAB path
3. Call `reset_persistence_filter()` before starting a new simulation
4. Wire residuals r1, r2, r3 and steady-state flag into the block
5. Connect outputs to displays and scopes

## Output Examples

### No Leak Detected
```
FLAG:       NO LEAK
CONFIDENCE: N/A
LOCATION:   None — no fault detected
ACTION:     Continue testing. All physics residuals within baseline bounds.
```

### Zone A Leak Detected
```
FLAG:       ⚠ LEAK DETECTED
CONFIDENCE: 87% ± 6%
LOCATION:   Zone A: Intake duct between MAF sensor and turbocharger compressor inlet
ACTION:     INSPECT: Intake ducting... [full recommendations]
```

### Uncertain (Monitoring)
```
FLAG:       ◉ UNCERTAIN — MONITORING
CONFIDENCE: 62% (insufficient for alert)
LOCATION:   Zone B: Charge-air system...
ACTION:     [Recommendations] | PENDING CONFIRMATION:...
```

## Configuration Parameters

Edit these constants in the source files to tune system behavior:

| Parameter | File | Default | Purpose |
|-----------|------|---------|---------|
| `MAGNITUDE_THRESHOLD` | predict_leak_zone.m | 2.0 | Raw residual magnitude gate |
| `P_HIGH` | predict_leak_zone.m | 0.70 | GP alert entry threshold |
| `N_PERSIST` | persistence_filter.m | 5 | Windows to confirm alert |
| `DECAY_RATE` | persistence_filter.m | 0.5 | Counter decay for inactive zones |
| `CLEAR_STREAK` | persistence_filter.m | 3 | No-fault windows to exit alert |

## Expected Performance

From validation on typical synthetic datasets:
- **Detection Rate**: >95% for faults above MDL
- **False Positive Rate**: <3%
- **Zone Isolation Rate**: >88%
- **Minimum Detectable Leak (MDL)**:
  - Zone A: ~7% flow loss
  - Zone B: ~5% flow loss
  - Zone C: ~8% flow loss
  - Zone D: ~10% flow loss

## Authors & References

Built for the **Caterpillar Tech Challenge 2026 — Problem Statement 3: Intake & Exhaust Air Leak Detection and Isolation**.

## License

Educational use. See competition guidelines.

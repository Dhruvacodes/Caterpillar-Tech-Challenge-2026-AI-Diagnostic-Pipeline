# Caterpillar-Tech-Challenge-2026-AI-Diagnostic-Pipeline

## Overview

This repository contains the complete AI/ML diagnostic pipeline for **diesel engine air leak detection and isolation**. The system detects leaks in four physical zones (intake, charge-air, exhaust pre-turbine, and exhaust post-turbine) using Gaussian Process classification on physics-based residuals from a Simulink engine model.

## Problem Statement

**Caterpillar Tech Challenge 2026 — Problem Statement 3: Intake & Exhaust Air Leak Detection and Isolation**

The pipeline must:
1. **Detect** whether a leak exists
2. **Isolate** which zone the leak is in (A, B, C, or D)
3. **Quantify** confidence with uncertainty bounds
4. **Recommend** specific physical inspection actions for field engineers

## Architecture

The AI pipeline is organized into **layers** (based on the Simulink residual generator outputs):

- **Layer 3**: K-Means clustering on no-fault data → per-regime variance normalization
- **Layer 4**: 5-class Gaussian Process (OvR) classification on normalized residuals
- **Layer 5**: Persistence filter (temporal smoothing + hysteresis)
- **Layer 6**: Output engine (assembles human-readable strings)

## Quick Start

### 1. Prepare Training Data
Create `training_data_raw.mat` with a matrix called `training_data`:
- Shape: `Nx4` (N = number of simulation scenarios)
- Columns: `[r1, r2, r3, zone_label]`
  - `r1` = Mass balance residual (MAF sensor vs compressor)
  - `r2` = Charge-air pressure ratio residual
  - `r3` = Exhaust energy balance residual
  - `zone_label` = 0 (no fault), 1 (Zone A), 2 (Zone B), 3 (Zone C), 4 (Zone D)
- Typical size: 120–200 rows with balanced class distribution

### 2. Run the Pipeline Steps (in order)

```matlab
step1_check_training_data        % Load & validate data
step2_train_normalizer           % K-Means + normalize
step3_train_GP_classifier        % Train 5 GPs
step4_test_single_prediction     % Manual API test
step5_run_full_pipeline_test     % Integration test
step6_validate_performance       % Cross-validation & MDL curves
plot_residual_space              % 3D visualization
```

### 3. Deploy to Simulink

Copy `GP_Classifier_Simulink_Block.m` into a MATLAB Function block in Simulink:

```
Residual Generator (from Layer 2)
        ↓
    [r1, r2, r3, is_steady_state]
        ↓
[GP_Classifier_Simulink_Block]
        ↓
[flag, confidence, zone_idx, p_vector]
        ↓
   Display blocks + Scope
```

## Files

### Training & Validation
| File | Purpose |
|------|---------|
| `step1_check_training_data.m` | Load & validate training data, check fault signatures |
| `step2_train_normalizer.m` | K-Means clustering (K=4), compute per-regime sigma table |
| `step3_train_GP_classifier.m` | Train 5 binary GP classifiers (one-vs-rest) |
| `step4_test_single_prediction.m` | Manual test on 6 known inputs |
| `step5_run_full_pipeline_test.m` | End-to-end integration test with synthetic sequences |
| `step6_validate_performance.m` | Cross-validation, MDL curves, false positive analysis |

### Runtime Functions
| File | Purpose |
|------|---------|
| `predict_leak_zone.m` | Core GP classification function (called every sample) |
| `persistence_filter.m` | Temporal smoothing + hysteresis (Layer 5) |
| `reset_persistence_filter.m` | Reset persistent state between runs |
| `assemble_output.m` | Convert numeric outputs to human-readable strings |

### Visualization & Simulation
| File | Purpose |
|------|---------|
| `plot_residual_space.m` | 3D scatter plot of training data in residual space |
| `GP_Classifier_Simulink_Block.m` | Simulink MATLAB Function block wrapper |

## Key Thresholds

| Parameter | Value | Notes |
|-----------|-------|-------|
| Magnitude gate | 2.0 (raw units) | Hard gate: `||r||` < 2.0 → no-fault |
| P_HIGH | 0.70 | GP probability entry threshold for alert |
| P_LOW | 0.40 | Hysteresis exit threshold (no-fault streak) |
| N_PERSIST | 5 | Windows required to confirm alert |
| DECAY_RATE | 0.5 | Per-window counter decay for inactive zones |

## Outputs

The system produces **four required outputs** at each time step:

1. **FLAG** (integer)
   - `0` = "NO LEAK"
   - `1` = "⚠ LEAK DETECTED"
   - `2` = "◉ UNCERTAIN — MONITORING"

2. **CONFIDENCE** (string)
   - Format: "84% ± 5%" (posterior probability ± 2σ)
   - Or: "N/A" if no fault

3. **LOCATION** (string)
   - Zone A, B, C, or D with physical description
   - Or: "None — no fault detected"

4. **ACTION** (string)
   - Specific field inspection instructions per zone
   - Includes diagnostic confirmation methods

## Expected Performance

On typical training data with **>95% class balance**, expect:

| Metric | Value |
|--------|-------|
| Overall detection rate | >95% |
| False positive rate | <3% |
| Zone isolation accuracy | >88% |
| Zone A MDL | ~7% flow loss |
| Zone B MDL | ~5% flow loss |
| Zone C MDL | ~8% flow loss |
| Zone D MDL | ~10% flow loss |

## Fault Signatures

The residuals exhibit distinct patterns for each zone:

- **Zone 0** (No Fault): `r1 ≈ 0, r2 ≈ 0, r3 ≈ 0`
- **Zone 1 (A)** (MAF-Compressor): `r1 << 0` (strongly negative)
- **Zone 2 (B)** (Charge-Air): `r2 << 0` (strongly negative)
- **Zone 3 (C)** (Pre-Turbine): `r3 >> 0` (strongly positive)
- **Zone 4 (D)** (Post-Turbine): `r3 > 0` (moderately positive)

## Troubleshooting

### "training_data_raw.mat not found"
Run Simulink data generation script to create training data.

### All predictions return Zone 0 (no fault)
Check magnitude gate threshold. If raw residuals have a different scale, adjust `MAGNITUDE_THRESHOLD` in `predict_leak_zone.m`.

### False positives too high (>5%)
- Increase `P_HIGH` threshold in `predict_leak_zone.m`
- Increase `N_PERSIST` in `persistence_filter.m`

### Low detection rate (<95%)
- Ensure training data has each zone well-represented (>10 examples each)
- Check that fault signatures match expected patterns (run `step1_check_training_data.m`)
- Verify Simulink residual generator is calibrated correctly

## References

- **Gaussian Process Classifier**: MATLAB `fitcgp()` (Statistics and Machine Learning Toolbox)
- **K-Means**: MATLAB `kmeans()` (Statistics and Machine Learning Toolbox)
- **One-vs-Rest Strategy**: 5 binary GPs, one per class (0–4)
- **Kernel**: Squared exponential (RBF) with automatic hyperparameter optimization

## MATLAB Requirements

- MATLAB R2021a or later
- Statistics and Machine Learning Toolbox
- (Optional) Simulink for real-time deployment

## Author

Built for **Caterpillar Tech Challenge 2026**

---

**For questions or issues**, check the inline code comments and the troubleshooting section above.

% ================================================================
% GP_Classifier_Simulink_Block.m
%
% PURPOSE: MATLAB Function block for Simulink integration. Wraps the
% complete AI diagnostic pipeline (GP classifier + persistence filter +
% output assembly) into a single callable function.
%
% FUNCTION SIGNATURE (Simulink MATLAB Function format):
%   [flag, confidence, conf_lo, conf_hi, zone_idx, ...
%    p_nofault, p_zoneA, p_zoneB, p_zoneC, p_zoneD] = ...
%       GP_Classifier_Simulink_Block(r1_raw, r2_raw, r3_raw, is_steady_state)
%
% INPUTS FROM SIMULINK:
%   r1_raw — scalar residual r1 from Layer 2 (MAF−compressor balance)
%   r2_raw — scalar residual r2 from Layer 2 (pressure ratio)
%   r3_raw — scalar residual r3 from Layer 2 (exhaust energy)
%   is_steady_state — boolean (1 if Layer 1 gate passed, 0 if transient)
%
% OUTPUTS TO SIMULINK:
%   flag — integer 0/1/2 (display in indicator)
%   confidence — scalar [0,1] (display in gauge)
%   conf_lo — lower bound of confidence interval (confidence − 2σ)
%   conf_hi — upper bound (confidence + 2σ)
%   zone_idx — integer 0−4 (display zone index)
%   p_nofault, p_zoneA, p_zoneB, p_zoneC, p_zoneD — individual probabilities (to Scope)
%
% SIMULINK SETUP REQUIRED:
%   1. GP_classifier.mat must be in MATLAB working directory or path
%   2. normalizer_params.mat must be in MATLAB working directory or path
%   3. predict_leak_zone.m must be on MATLAB path
%   4. persistence_filter.m must be on MATLAB path
%   5. Call reset_persistence_filter() from command line before each new
%      simulation run to reset persistent state
%
% SIMULINK WIRING INSTRUCTIONS:
%   Input ports:
%     - Port 1: r1_raw (scalar) from Residual Generator subsystem
%     - Port 2: r2_raw (scalar) from Residual Generator subsystem
%     - Port 3: r3_raw (scalar) from Residual Generator subsystem
%     - Port 4: is_steady_state (boolean) from Steady−State Gate subsystem
%
%   Output ports:
%     - Port 1: flag → Display block (show decision: 0/1/2)
%     - Port 2: confidence → Gauge/Display block
%     - Port 3: conf_lo → optional (for uncertainty bounds)
%     - Port 4: conf_hi → optional (for uncertainty bounds)
%     - Port 5: zone_idx → Display block (show zone 0−4)
%     - Ports 6−10: Probability vector → Mux → Scope for live visualization
%
% ================================================================

function [flag, confidence, conf_lo, conf_hi, zone_idx, ...
          p_nofault, p_zoneA, p_zoneB, p_zoneC, p_zoneD] = ...
          GP_Classifier_Simulink_Block(r1_raw, r2_raw, r3_raw, is_steady_state)

    % ---- BLOCK 1: Check if window is steady−state ----
    % Layer 1 has already determined if this window is valid
    if is_steady_state == 0
        % Transient window — Layer 1 gate rejected it, do not diagnose
        flag = 0;
        confidence = 0;
        conf_lo = 0;
        conf_hi = 0;
        zone_idx = 0;
        p_nofault = 0.2;
        p_zoneA = 0.2;
        p_zoneB = 0.2;
        p_zoneC = 0.2;
        p_zoneD = 0.2;
        return;
    end

    % ---- BLOCK 2: Call GP classifier ----
    % Query the core prediction function for this residual triplet
    [flag_raw, confidence_raw, confidence_sigma_raw, zone_raw, p_vector_raw] = ...
        predict_leak_zone(r1_raw, r2_raw, r3_raw);

    % ---- BLOCK 3: Temporal smoothing via persistence filter ----
    % Apply hysteresis and persistence threshold
    [final_flag, final_zone, ~] = ...
        persistence_filter(flag_raw, zone_raw, confidence_raw);

    % ---- BLOCK 4: Compute confidence bounds ----
    % Confidence interval: ±2σ
    conf_lo = max(0, confidence_raw - 2 * confidence_sigma_raw);
    conf_hi = min(1, confidence_raw + 2 * confidence_sigma_raw);

    % ---- BLOCK 5: Unpack outputs ----
    flag = final_flag;
    confidence = confidence_raw;
    zone_idx = final_zone;

    % Individual probabilities for live plotting
    p_nofault = p_vector_raw(1);
    p_zoneA = p_vector_raw(2);
    p_zoneB = p_vector_raw(3);
    p_zoneC = p_vector_raw(4);
    p_zoneD = p_vector_raw(5);

end

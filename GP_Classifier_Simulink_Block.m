function [flag, confidence, conf_lo, conf_hi, zone_idx, p_nofault, p_zoneA, p_zoneB, p_zoneC, p_zoneD] = ...
    GP_Classifier_Simulink_Block(r1_raw, r2_raw, r3_raw, is_steady_state)

% ================================================================
% GP_Classifier_Simulink_Block.m
%
% Paste this entire function into a MATLAB Function block in Simulink.
%
% SETUP REQUIRED BEFORE RUNNING IN SIMULINK:
% 1. GP_classifier.mat must be in MATLAB working directory or path
% 2. normalizer_params.mat must be in MATLAB working directory or path
% 3. predict_leak_zone.m must be on the MATLAB path
% 4. persistence_filter.m must be on the MATLAB path
% 5. Call reset_persistence_filter() from command window before
%    each new simulation run to reset state
%
% SIMULINK WIRING:
% - Connect r1, r2, r3 from Residual Generator subsystem outputs
% - Connect is_steady_state from Steady-State Gate output
% - Connect flag, confidence, zone_idx to Display blocks
% - Connect p_nofault through p_zoneD to Mux + Scope
%
% ================================================================

    % Check steady-state gate first
    if is_steady_state == 0
        % Transient window — Layer 1 gate rejected this window
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

    % Call predict_leak_zone (Layer 4)
    [flag_raw, confidence_raw, confidence_sigma, zone_raw, p_vector] = ...
        predict_leak_zone(r1_raw, r2_raw, r3_raw);

    % Call persistence_filter (Layer 5)
    [flag, zone_idx, ~] = persistence_filter(flag_raw, zone_raw, confidence_raw);

    % Confidence interval calculation
    confidence = confidence_raw;
    conf_lo = max(0, confidence - 2 * confidence_sigma);
    conf_hi = min(1, confidence + 2 * confidence_sigma);

    % Unpack probability vector
    p_nofault = p_vector(1);
    p_zoneA = p_vector(2);
    p_zoneB = p_vector(3);
    p_zoneC = p_vector(4);
    p_zoneD = p_vector(5);

end

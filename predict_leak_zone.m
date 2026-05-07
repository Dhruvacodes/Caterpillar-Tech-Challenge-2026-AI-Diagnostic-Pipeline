function [flag, confidence, confidence_sigma, zone_idx, p_vector] = predict_leak_zone(r1_raw, r2_raw, r3_raw)
% ================================================================
% predict_leak_zone.m
%
% CORE PREDICTION FUNCTION — Layer 4 evaluation of GP classifiers
%
% This is the master runtime function called at every time step.
% It loads GP and normalizer models once (persistent) and is safe to 
% call in tight loops.
%
% INPUTS:
%   r1_raw, r2_raw, r3_raw: raw residual scalars from current window
%
% OUTPUTS:
%   flag: integer 0=no leak, 1=leak detected, 2=uncertain
%   confidence: scalar [0,1] probability of dominant class
%   confidence_sigma: scalar [0,1] uncertainty bound (binomial std)
%   zone_idx: integer 0=none, 1=ZoneA, 2=ZoneB, 3=ZoneC, 4=ZoneD
%   p_vector: 1×5 vector [P_nofault, P_ZoneA, P_ZoneB, P_ZoneC, P_ZoneD]
%
% MODELS LOADED (persistent):
%   - GP_classifier.mat (GP_models, class_names, K_CLASSES)
%   - normalizer_params.mat (centroids, sigma_table)
%
% NOTE: Call reset_persistent_models() to clear persistent state
%       between separate simulation runs.
%
% ================================================================

persistent GP_models centroids sigma_table models_loaded

% ---- BLOCK 1: Load models on first call ----
if isempty(models_loaded)
    if ~exist('GP_classifier.mat', 'file')
        error('ERROR: GP_classifier.mat not found. Make sure file is on MATLAB path.');
    end
    if ~exist('normalizer_params.mat', 'file')
        error('ERROR: normalizer_params.mat not found. Make sure file is on MATLAB path.');
    end

    load('GP_classifier.mat', 'GP_models');
    load('normalizer_params.mat', 'centroids', 'sigma_table');

    models_loaded = true;
end

% ---- BLOCK 2: Input validation ----
if ~isfinite(r1_raw) || ~isfinite(r2_raw) || ~isfinite(r3_raw)
    warning('predict_leak_zone: invalid input detected (NaN or Inf), returning uncertain');
    flag = 2;
    confidence = 0;
    confidence_sigma = 0;
    zone_idx = 0;
    p_vector = [0.2, 0.2, 0.2, 0.2, 0.2];
    return;
end

% ---- BLOCK 3: Magnitude gate (hard gate on raw residuals) ----
MAGNITUDE_THRESHOLD = 2.0;  % raw residual units

magnitude = sqrt(r1_raw^2 + r2_raw^2 + r3_raw^2);

if magnitude < MAGNITUDE_THRESHOLD
    % Residual magnitude below noise floor — definite no-fault
    flag = 0;
    confidence = 0.98;
    confidence_sigma = 0.01;
    zone_idx = 0;
    p_vector = [0.98, 0.005, 0.005, 0.005, 0.005];
    return;
end

% ---- BLOCK 4: Regime assignment and normalization ----
% Find nearest cluster centroid
distances = sqrt(sum((repmat([r1_raw, r2_raw, r3_raw], size(centroids,1), 1) - centroids).^2, 2));
[~, k] = min(distances);

% Normalize residuals using this regime's sigma table
r1_norm = r1_raw / sigma_table(k, 1);
r2_norm = r2_raw / sigma_table(k, 2);
r3_norm = r3_raw / sigma_table(k, 3);

x_norm = [r1_norm, r2_norm, r3_norm];

% ---- BLOCK 5: Query all 5 GPs ----
p_raw = zeros(1, 5);

for c = 1:5
    [~, score_c] = predict(GP_models{c}, x_norm);
    % score_c is 1×2: [neg_label, pos_label_score]
    p_raw(c) = score_c(2);
end

% Clamp to prevent numerical issues
p_raw = max(0.001, min(0.999, p_raw));

% ---- BLOCK 6: Normalize probability vector ----
p_sum = sum(p_raw);

if p_sum < 0.01
    % All GPs returned near-zero — GP completely uncertain
    p_vector = [0.2, 0.2, 0.2, 0.2, 0.2];
    flag = 2;
    confidence = 0.2;
    confidence_sigma = 0.2;
    zone_idx = 0;
    return;
end

p_vector = p_raw / p_sum;

% ---- BLOCK 7: Uncertainty estimation ----
% Use binomial standard deviation as approximation
sigma_vector = sqrt(p_vector .* (1 - p_vector));

% ---- BLOCK 8: Alert threshold logic ----
fault_probs = p_vector(2:5);
[max_fault_prob, max_fault_zone_offset] = max(fault_probs);

zone_idx = max_fault_zone_offset;  % 1=A, 2=B, 3=C, 4=D
dominant_sigma = sigma_vector(zone_idx + 1);

% Threshold parameters
P_HIGH = 0.70;  % entry threshold for alert

confidence = max_fault_prob;
confidence_sigma = dominant_sigma;

% Determine flag based on thresholds
if max_fault_prob > P_HIGH && dominant_sigma < 0.15
    flag = 1;  % LEAK DETECTED (high confidence, low uncertainty)
elseif max_fault_prob > 0.50
    flag = 2;  % UNCERTAIN — keep monitoring
else
    flag = 0;  % NO LEAK
    zone_idx = 0;
end

end  % function predict_leak_zone

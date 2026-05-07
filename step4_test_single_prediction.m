% ================================================================
% step4_test_single_prediction.m
%
% PURPOSE: Manual test of the trained GP classifier on 6 known
% test cases before deploying to Simulink.
%
% OUTPUTS: Console summary of test results (no files saved)
%
% DEPENDENCIES: GP_classifier.mat, normalizer_params.mat
%
% ================================================================

clear; clc; close all;

fprintf('\n=================================================\n');
fprintf('STEP 4: SINGLE PREDICTION TESTS\n');
fprintf('=================================================\n\n');

% ---- Load models ----
if ~exist('GP_classifier.mat', 'file')
    error('ERROR: GP_classifier.mat not found. Run step3 first.');
end
if ~exist('normalizer_params.mat', 'file')
    error('ERROR: normalizer_params.mat not found. Run step2 first.');
end

load('GP_classifier.mat', 'GP_models', 'class_names');
load('normalizer_params.mat', 'centroids', 'sigma_table');

fprintf('✓ Models loaded.\n');
fprintf('✓ Normalizer parameters loaded.\n\n');

% ---- Define test cases ----
test_cases = struct();

% Test 1: No fault baseline
test_cases(1).name = 'Test 1: No Fault Baseline';
test_cases(1).r1 = 0.001;
test_cases(1).r2 = 0.002;
test_cases(1).r3 = -0.001;
test_cases(1).expected_zone = 0;

% Test 2: Zone A leak (r1 strongly negative)
test_cases(2).name = 'Test 2: Clear Zone A Leak';
test_cases(2).r1 = -4.5;
test_cases(2).r2 = -0.3;
test_cases(2).r3 = 0.1;
test_cases(2).expected_zone = 1;

% Test 3: Zone B leak (r2 strongly negative)
test_cases(3).name = 'Test 3: Clear Zone B Leak';
test_cases(3).r1 = 0.1;
test_cases(3).r2 = -5.2;
test_cases(3).r3 = 0.05;
test_cases(3).expected_zone = 2;

% Test 4: Zone C leak (r3 strongly positive)
test_cases(4).name = 'Test 4: Clear Zone C Leak';
test_cases(4).r1 = 0.05;
test_cases(4).r2 = 0.1;
test_cases(4).r3 = 4.8;
test_cases(4).expected_zone = 3;

% Test 5: Zone D leak (r3 moderately positive)
test_cases(5).name = 'Test 5: Clear Zone D Leak';
test_cases(5).r1 = 0.05;
test_cases(5).r2 = 0.1;
test_cases(5).r3 = 3.1;
test_cases(5).expected_zone = 4;

% Test 6: Ambiguous (near decision boundary)
test_cases(6).name = 'Test 6: Ambiguous (Near Boundary)';
test_cases(6).r1 = -1.5;
test_cases(6).r2 = -1.4;
test_cases(6).r3 = 0.5;
test_cases(6).expected_zone = -1;  % no specific expectation

% ---- Run tests ----
n_passed = 0;

for test_idx = 1:length(test_cases)
    test = test_cases(test_idx);
    fprintf('%s\n', test.name);
    fprintf('%s\n', repmat('-', 1, 60));

    r1_raw = test.r1;
    r2_raw = test.r2;
    r3_raw = test.r3;

    % Simplification note: use cluster 1 (first regime) as proxy since
    % this is a standalone test without full operating condition info
    k_regime = 1;

    % Normalize using cluster 1 sigma values
    r1_norm = r1_raw / sigma_table(k_regime, 1);
    r2_norm = r2_raw / sigma_table(k_regime, 2);
    r3_norm = r3_raw / sigma_table(k_regime, 3);

    x_norm = [r1_norm, r2_norm, r3_norm];

    fprintf('Input: [r1=%.3f, r2=%.3f, r3=%.3f]\n', r1_raw, r2_raw, r3_raw);
    fprintf('Normalized: [r1=%.3f, r2=%.3f, r3=%.3f]\n\n', r1_norm, r2_norm, r3_norm);

    % Query all 5 GPs
    p_vector = zeros(1, 5);
    for c = 1:5
        [~, score] = predict(GP_models{c}, x_norm);
        p_raw_c = score(2);  % probability of positive class
        p_vector(c) = max(0.001, min(0.999, p_raw_c));
    end

    % Normalize probabilities
    p_sum = sum(p_vector);
    if p_sum < 0.01
        p_vector = [0.2, 0.2, 0.2, 0.2, 0.2];
    else
        p_vector = p_vector / p_sum;
    end

    fprintf('Probabilities: [P0=%.3f, P1=%.3f, P2=%.3f, P3=%.3f, P4=%.3f]\n', ...
        p_vector(1), p_vector(2), p_vector(3), p_vector(4), p_vector(5));

    % Find dominant fault
    fault_probs = p_vector(2:5);
    [max_fault_prob, max_fault_zone_offset] = max(fault_probs);
    zone_idx = max_fault_zone_offset;

    confidence = max_fault_prob;

    % Determine flag
    P_HIGH = 0.70;
    if max_fault_prob > P_HIGH
        flag = 1;
        flag_str = 'LEAK DETECTED';
    elseif max_fault_prob > 0.50
        flag = 2;
        flag_str = 'UNCERTAIN';
    else
        flag = 0;
        flag_str = 'NO LEAK';
        zone_idx = 0;
    end

    if zone_idx == 0
        zone_name = 'No Fault';
    else
        zone_name = class_names{zone_idx + 1};
    end

    fprintf('Predicted class: Zone %d (%s)\n', zone_idx, zone_name);
    fprintf('Confidence: %.1f%%\n', 100*confidence);
    fprintf('Flag: %s\n\n', flag_str);

    % Check PASS/FAIL
    if test.expected_zone == -1
        % No specific expectation for this test
        fprintf('RESULT: INFO (ambiguous case, no definite expected answer)\n');
    elseif zone_idx == test.expected_zone
        fprintf('RESULT: PASS\n');
        n_passed = n_passed + 1;
    else
        fprintf('RESULT: FAIL (expected Zone %d, got Zone %d)\n', ...
            test.expected_zone, zone_idx);
    end

    fprintf('\n');
end

% ---- Summary ----
fprintf('=================================================\n');
fprintf('TEST SUMMARY\n');
fprintf('=================================================\n');
fprintf('Passed: %d / 6\n', n_passed);

if n_passed >= 4
    fprintf('✓ Sufficient tests passed. Ready for full pipeline.\n');
else
    fprintf('⚠ WARNING: Only %d/6 tests passed. Review training data or model parameters.\n', n_passed);
end

fprintf('\nNext: Run step5_run_full_pipeline_test.m\n\n');

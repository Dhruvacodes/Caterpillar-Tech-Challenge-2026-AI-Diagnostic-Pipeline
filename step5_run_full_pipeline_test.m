% ================================================================
% step5_run_full_pipeline_test.m
%
% PURPOSE: End-to-end integration test. Run synthetic residual sequences
% through the complete pipeline and verify all components work together.
%
% INPUTS: None (uses trained models from steps 2–3)
%
% OUTPUTS: Console test results
%
% ================================================================

clear; clc; close all;

fprintf('\n=================================================\n');
fprintf('STEP 5: FULL PIPELINE INTEGRATION TEST\n');
fprintf('=================================================\n\n');

% ---- Check models exist ----
if ~exist('GP_classifier.mat', 'file')
    error('ERROR: GP_classifier.mat not found. Run step3 first.');
end
if ~exist('normalizer_params.mat', 'file')
    error('ERROR: normalizer_params.mat not found. Run step2 first.');
end

fprintf('Loaded trained models. Running 5 synthetic test sequences...\n\n');

% ---- Define 5 test sequences ----
% Each sequence has 10 windows. Each window is [r1, r2, r3]

% Sequence 1: Stable no-fault baseline
seq1 = randn(10, 3) * 0.3;
seq1_name = 'Seq 1: Stable No-Fault Baseline';
seq1_expect = 'All NO LEAK';

% Sequence 2: Zone B leak developing gradually
seq2 = zeros(10, 3);
seq2(1:3, :) = randn(3, 3) * 0.2;  % near-zero
seq2(4:10, 1) = randn(7, 1) * 0.3;  % r1 noisy
seq2(4:10, 2) = -5.0 + randn(7, 1) * 0.3;  % r2 strongly negative
seq2(4:10, 3) = randn(7, 1) * 0.2;  % r3 noisy
seq2_name = 'Seq 2: Zone B Leak Developing';
seq2_expect = 'Zone B alert by window 8–9';

% Sequence 3: Single noise spike then recovery
seq3 = zeros(10, 3);
seq3(1:2, :) = randn(2, 3) * 0.2;  % near-zero
seq3(3, :) = [-4.0, 0.1, 0.1];  % single Zone A spike
seq3(4:10, :) = randn(7, 3) * 0.2;  % recovery
seq3_name = 'Seq 3: Brief Noise Spike (1 window)';
seq3_expect = 'No confirmed alert (below persistence)';

% Sequence 4: Zone C leak
seq4 = zeros(10, 3);
seq4(1:2, :) = randn(2, 3) * 0.2;  % near-zero
seq4(3:10, 1) = randn(8, 1) * 0.2;  % r1 noisy
seq4(3:10, 2) = randn(8, 1) * 0.2;  % r2 noisy
seq4(3:10, 3) = 4.5 + randn(8, 1) * 0.4;  % r3 strongly positive
seq4_name = 'Seq 4: Zone C Leak';
seq4_expect = 'Zone C alert by window 7–8';

% Sequence 5: Zone A then Zone B (zone switch)
seq5 = zeros(10, 3);
seq5(1:5, :) = [-4.5 + randn(5,1)*0.3, -0.2 + randn(5,1)*0.2, randn(5,1)*0.2];
seq5(6:10, :) = [-0.1 + randn(5,1)*0.2, -5.0 + randn(5,1)*0.3, randn(5,1)*0.2];
seq5_name = 'Seq 5: Zone A → Zone B Switch';
seq5_expect = 'Zone A alert first, then Zone B';

sequences = {seq1, seq2, seq3, seq4, seq5};
seq_names = {seq1_name, seq2_name, seq3_name, seq4_name, seq5_name};
seq_expects = {seq1_expect, seq2_expect, seq3_expect, seq4_expect, seq5_expect};

% ---- Run each sequence ----
zone_names = {'None', 'A', 'B', 'C', 'D'};

for seq_idx = 1:5
    fprintf('=== %s ===\n', seq_names{seq_idx});
    fprintf('Expected: %s\n\n', seq_expects{seq_idx});

    % Reset persistence filter before each sequence
    reset_persistence_filter();

    seq_data = sequences{seq_idx};
    n_windows = size(seq_data, 1);

    fprintf('%4s %10s %10s %10s %5s %7s %8s %12s %12s\n', ...
        'Win', 'r1', 'r2', 'r3', 'Flag', 'Zone', 'Confid', 'PersistZn', 'FinalFlag');
    fprintf('%s\n', repmat('-', 1, 95));

    for win = 1:n_windows
        r1 = seq_data(win, 1);
        r2 = seq_data(win, 2);
        r3 = seq_data(win, 3);

        % Run prediction
        [flag_raw, confidence_raw, ~, zone_raw, p_vec] = predict_leak_zone(r1, r2, r3);

        % Run persistence filter
        [final_flag, final_zone, counter_snap] = persistence_filter(flag_raw, zone_raw, confidence_raw);

        % Compute magnitude
        magnitude = sqrt(r1^2 + r2^2 + r3^2);

        % Print window results
        fprintf('%4d %10.3f %10.3f %10.3f ', win, r1, r2, r3);
        fprintf('%5d %7s %8.2f ', flag_raw, zone_names{zone_raw + 1}, confidence_raw);

        if final_flag == 1
            check_str = sprintf('%s(%d/%d)', zone_names{final_zone+1}, ceil(max(counter_snap)), 5);
        else
            check_str = '—';
        end
        fprintf('%12s ', check_str);

        if final_flag == 0
            final_str = 'NO';
        elseif final_flag == 1
            final_str = 'YES';
        else
            final_str = 'UNCERT';
        end
        fprintf('%12s\n', final_str);
    end

    fprintf('\n');
end

fprintf('=================================================\n');
fprintf('STEP 5 COMPLETE\n');
fprintf('=================================================\n');
fprintf('All sequences tested. Review results above.\n');
fprintf('Next: Run step6_validate_performance.m\n\n');

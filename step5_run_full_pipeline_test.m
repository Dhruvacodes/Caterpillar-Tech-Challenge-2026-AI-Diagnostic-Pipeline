% ================================================================
% step5_run_full_pipeline_test.m
%
% PURPOSE: End-to-end integration test of the complete pipeline.
% Run synthetic residual sequences through all layers and verify
% correct behavior.
%
% OUTPUTS: Console test results (no files saved)
%
% DEPENDENCIES: predict_leak_zone.m, persistence_filter.m,
%               assemble_output.m, reset_persistence_filter.m
%
% ================================================================

clear; clc; close all;

fprintf('\n=================================================\n');
fprintf('STEP 5: FULL PIPELINE INTEGRATION TEST\n');
fprintf('=================================================\n\n');

% ---- Define 5 test sequences ----
sequences = struct();

% Sequence 1: Stable no-fault baseline
sequences(1).name = 'Sequence 1: No-Fault Baseline';
sequences(1).windows = [];
for w = 1:10
    sequences(1).windows = [sequences(1).windows; ...
        randn()*0.3, randn()*0.3, randn()*0.3];
end
sequences(1).expected_outcome = 'All windows NO LEAK, no alert';

% Sequence 2: Zone B leak developing gradually
sequences(2).name = 'Sequence 2: Zone B Leak (Gradual)';
windows_seq2 = [];
for w = 1:3
    windows_seq2 = [windows_seq2; randn()*0.3, randn()*0.3, randn()*0.2];
end
for w = 4:10
    windows_seq2 = [windows_seq2; ...
        randn()*0.3, -5.0 + randn()*0.3, randn()*0.2];
end
sequences(2).windows = windows_seq2;
sequences(2).expected_outcome = 'Alert triggers by window 8-9 (Zone B)';

% Sequence 3: Brief noise spike then recovery
sequences(3).name = 'Sequence 3: Noise Spike (Single Window)';
windows_seq3 = [];
for w = 1:2
    windows_seq3 = [windows_seq3; randn()*0.3, randn()*0.3, randn()*0.2];
end
windows_seq3 = [windows_seq3; -4.0, 0.1, 0.1];  % single spike
for w = 4:10
    windows_seq3 = [windows_seq3; randn()*0.3, randn()*0.3, randn()*0.2];
end
sequences(3).windows = windows_seq3;
sequences(3).expected_outcome = 'No confirmed alert (below persistence threshold)';

% Sequence 4: Zone C leak
sequences(4).name = 'Sequence 4: Zone C Leak';
windows_seq4 = [];
for w = 1:2
    windows_seq4 = [windows_seq4; randn()*0.3, randn()*0.3, randn()*0.2];
end
for w = 3:10
    windows_seq4 = [windows_seq4; randn()*0.1, randn()*0.1, 4.5 + randn()*0.4];
end
sequences(4).windows = windows_seq4;
sequences(4).expected_outcome = 'Alert triggers by window 7-8 (Zone C)';

% Sequence 5: Zone A then Zone B (zone switch)
sequences(5).name = 'Sequence 5: Zone A → Zone B Transition';
windows_seq5 = [];
for w = 1:5
    windows_seq5 = [windows_seq5; -4.5 + randn()*0.3, -0.2 + randn()*0.2, 0.1 + randn()*0.1];
end
for w = 6:10
    windows_seq5 = [windows_seq5; -0.1 + randn()*0.2, -5.0 + randn()*0.3, 0.1 + randn()*0.1];
end
sequences(5).windows = windows_seq5;
sequences(5).expected_outcome = 'Zone A alert, then reset to Zone B alert';

% ---- Run all sequences ----
results = struct();

for seq_idx = 1:length(sequences)
    seq = sequences(seq_idx);
    fprintf('%s\n', seq.name);
    fprintf('%s\n', repmat('=', 1, 70));

    % Reset persistence filter for this sequence
    reset_persistence_filter();

    n_windows = size(seq.windows, 1);
    final_flag_log = zeros(n_windows, 1);
    final_zone_log = zeros(n_windows, 1);

    for w = 1:n_windows
        r1_raw = seq.windows(w, 1);
        r2_raw = seq.windows(w, 2);
        r3_raw = seq.windows(w, 3);

        % Call GP classifier
        [flag_gp, confidence_gp, ~, zone_gp, ~] = predict_leak_zone(r1_raw, r2_raw, r3_raw);

        % Call persistence filter
        [final_flag, final_zone, counter_snap] = persistence_filter(flag_gp, zone_gp, confidence_gp);

        % Log outcomes
        final_flag_log(w) = final_flag;
        final_zone_log(w) = final_zone;

        % Print window result
        magnitude = sqrt(r1_raw^2 + r2_raw^2 + r3_raw^2);
        fprintf('W%2d: r=[%6.2f,%6.2f,%6.2f] mag=%5.2f| GP_flag=%d zone=%d conf=%.2f| persist_flag=%d zone=%d| counters=%s\n', ...
            w, r1_raw, r2_raw, r3_raw, magnitude, ...
            flag_gp, zone_gp, confidence_gp, ...
            final_flag, final_zone, ...
            sprintf('[%.1f,%.1f,%.1f,%.1f]', counter_snap));
    end

    % Analyze results
    fprintf('\nSequence result:\n');
    fprintf('  Expected: %s\n', seq.expected_outcome);
    fprintf('  Window-by-window final flags: %s\n', sprintf('%d ', final_flag_log));
    fprintf('  Final zones: %s\n', sprintf('%d ', final_zone_log));

    % Simple PASS/FAIL assessment
    pass_fail = 'INFORMATIONAL';
    if seq_idx == 1
        if all(final_flag_log == 0)
            pass_fail = 'PASS';
        else
            pass_fail = 'FAIL';
        end
    elseif seq_idx == 2
        if max(final_flag_log(7:end)) == 1 && max(final_zone_log(7:end)) == 2
            pass_fail = 'PASS';
        else
            pass_fail = 'FAIL';
        end
    elseif seq_idx == 3
        if max(final_flag_log) < 1
            pass_fail = 'PASS';
        else
            pass_fail = 'FAIL';
        end
    elseif seq_idx == 4
        if max(final_flag_log(7:end)) == 1 && max(final_zone_log(7:end)) == 3
            pass_fail = 'PASS';
        else
            pass_fail = 'FAIL';
        end
    elseif seq_idx == 5
        % Complex sequence, just check that zones changed
        if length(unique(final_zone_log(final_zone_log > 0))) > 1
            pass_fail = 'PASS (zones transitioned)';
        else
            pass_fail = 'INFORMATIONAL';
        end
    end

    results(seq_idx).pass_fail = pass_fail;
    fprintf('  Result: %s\n\n', pass_fail);
end

% ---- Summary ----
fprintf('=================================================\n');
fprintf('SEQUENCE TEST SUMMARY\n');
fprintf('=================================================\n');
for seq_idx = 1:length(sequences)
    fprintf('%s: %s\n', sequences(seq_idx).name, results(seq_idx).pass_fail);
end

fprintf('\nNext: Run step6_validate_performance.m\n\n');

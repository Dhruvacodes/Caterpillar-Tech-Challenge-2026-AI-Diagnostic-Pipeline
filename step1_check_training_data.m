% ================================================================
% step1_check_training_data.m
%
% PURPOSE: Load and inspect training_data_raw.mat to verify dataset
% integrity before training any models.
%
% OUTPUTS: Console diagnostics only (no .mat files saved)
%
% REQUIRED INPUT: training_data_raw.mat containing a matrix
% called 'training_data' with columns [r1, r2, r3, zone_label]
%
% ================================================================

clear; clc; close all;

fprintf('\n=================================================\n');
fprintf('STEP 1: TRAINING DATA INTEGRITY CHECK\n');
fprintf('=================================================\n\n');

% ---- BLOCK 1: Check file existence ----
if ~exist('training_data_raw.mat', 'file')
    error(['ERROR: training_data_raw.mat not found.\n' ...
           'Run the Simulink data generation script first.\n']);
end

fprintf('✓ training_data_raw.mat found. Loading...\n\n');

% ---- BLOCK 2: Load and validate structure ----
load('training_data_raw.mat', 'training_data');

assert(ismatrix(training_data), 'training_data must be a 2D matrix');
assert(size(training_data, 2) == 4, ...
    sprintf('Expected 4 columns [r1, r2, r3, zone_label], got %d', size(training_data, 2)));

n_total = size(training_data, 1);
fprintf('Dataset loaded: %d simulation rows × 4 columns\n', n_total);
fprintf('Columns: [r1, r2, r3, zone_label]\n\n');

% ---- BLOCK 3: Extract columns ----
r1_all = training_data(:, 1);
r2_all = training_data(:, 2);
r3_all = training_data(:, 3);
labels = training_data(:, 4);

% ---- BLOCK 4: Check for NaN and Inf ----
fprintf('--- NaN and Inf Check ---\n');
nan_count_r1 = sum(isnan(r1_all));
nan_count_r2 = sum(isnan(r2_all));
nan_count_r3 = sum(isnan(r3_all));
nan_count_labels = sum(isnan(labels));

inf_count_r1 = sum(isinf(r1_all));
inf_count_r2 = sum(isinf(r2_all));
inf_count_r3 = sum(isinf(r3_all));
inf_count_labels = sum(isinf(labels));

total_issues = nan_count_r1 + nan_count_r2 + nan_count_r3 + nan_count_labels + ...
               inf_count_r1 + inf_count_r2 + inf_count_r3 + inf_count_labels;

if total_issues == 0
    fprintf('✓ No NaN or Inf values detected.\n\n');
else
    fprintf('⚠ WARNING: Found %d NaN/Inf values:\n', total_issues);
    fprintf('  NaN: r1=%d, r2=%d, r3=%d, labels=%d\n', ...
        nan_count_r1, nan_count_r2, nan_count_r3, nan_count_labels);
    fprintf('  Inf: r1=%d, r2=%d, r3=%d, labels=%d\n', ...
        inf_count_r1, inf_count_r2, inf_count_r3, inf_count_labels);
    fprintf('  These rows will be excluded from statistics.\n\n');
end

% ---- BLOCK 5: Class distribution ----
fprintf('--- Class Distribution ---\n');
zone_names = {'Zone 0 (No Fault)', 'Zone 1 (A)', 'Zone 2 (B)', 'Zone 3 (C)', 'Zone 4 (D)'};
class_counts = zeros(5, 1);

for k = 0:4
    count = sum(labels == k);
    class_counts(k+1) = count;
    fprintf('%s: %4d rows (%5.1f%%)\n', zone_names{k+1}, count, 100*count/n_total);
end

% Check for classes with < 10 examples
fprintf('\n');
for k = 0:4
    if class_counts(k+1) < 10
        fprintf('⚠ WARNING: %s has only %d examples (minimum recommended: 10)\n', ...
            zone_names{k+1}, class_counts(k+1));
    end
end

if all(class_counts > 0)
    fprintf('✓ All 5 classes present in dataset.\n\n');
else
    missing = find(class_counts == 0) - 1;
    fprintf('⚠ WARNING: Missing classes: %s\n\n', sprintf('Zone %d ', missing));
end

% ---- BLOCK 6: Per-class statistics table ----
fprintf('--- Residual Statistics by Zone ---\n');
fprintf('%-20s %8s %12s %12s %12s\n', 'Zone', 'Count', 'Mean r1', 'Mean r2', 'Mean r3');
fprintf('%s\n', repmat('-', 1, 64));

for k = 0:4
    mask = (labels == k);
    cnt = sum(mask);

    if cnt > 0
        mean_r1 = mean(r1_all(mask));
        mean_r2 = mean(r2_all(mask));
        mean_r3 = mean(r3_all(mask));
        fprintf('%-20s %8d %12.4f %12.4f %12.4f\n', ...
            zone_names{k+1}, cnt, mean_r1, mean_r2, mean_r3);
    end
end

fprintf('\n');

% ---- BLOCK 7: Min/Max per class ----
fprintf('--- Min/Max Range by Zone ---\n');
fprintf('%-20s %8s %12s %12s\n', 'Zone', 'Residual', 'Min', 'Max');
fprintf('%s\n', repmat('-', 1, 50));

for k = 0:4
    mask = (labels == k);
    if sum(mask) > 0
        fprintf('%s:\n', zone_names{k+1});
        fprintf('%20s %8s %12.4f %12.4f\n', '', 'r1', min(r1_all(mask)), max(r1_all(mask)));
        fprintf('%20s %8s %12.4f %12.4f\n', '', 'r2', min(r2_all(mask)), max(r2_all(mask)));
        fprintf('%20s %8s %12.4f %12.4f\n', '', 'r3', min(r3_all(mask)), max(r3_all(mask)));
    end
end

fprintf('\n');

% ---- BLOCK 8: Verify fault signature patterns ----
fprintf('--- Fault Signature Pattern Verification ---\n');
fprintf('Expected patterns:\n');
fprintf('  Zone 1 (A): r1 most negative\n');
fprintf('  Zone 2 (B): r2 most negative\n');
fprintf('  Zone 3 (C): r3 most positive\n');
fprintf('  Zone 4 (D): r3 moderately positive\n\n');

pattern_verified = true;

% Zone 1: Check if mean r1 is most negative
mean_r1_by_zone = zeros(5, 1);
mean_r2_by_zone = zeros(5, 1);
mean_r3_by_zone = zeros(5, 1);

for k = 0:4
    mask = (labels == k);
    if sum(mask) > 0
        mean_r1_by_zone(k+1) = mean(r1_all(mask));
        mean_r2_by_zone(k+1) = mean(r2_all(mask));
        mean_r3_by_zone(k+1) = mean(r3_all(mask));
    end
end

% Zone 1 should have most negative r1 (excluding Zone 0)
if class_counts(2) > 0
    [min_r1, min_r1_zone] = min(mean_r1_by_zone(2:5));
    if min_r1_zone == 1  % Zone 1 corresponds to index 2
        fprintf('✓ Zone 1: Mean r1 = %.4f (most negative among fault zones)\n', min_r1);
    else
        fprintf('⚠ Zone 1: Mean r1 = %.4f (NOT most negative; Zone %d is more negative)\n', ...
            mean_r1_by_zone(2), min_r1_zone);
        pattern_verified = false;
    end
end

% Zone 2 should have most negative r2
if class_counts(3) > 0
    [min_r2, min_r2_zone] = min(mean_r2_by_zone(2:5));
    if min_r2_zone == 2  % Zone 2 corresponds to index 3
        fprintf('✓ Zone 2: Mean r2 = %.4f (most negative among fault zones)\n', min_r2);
    else
        fprintf('⚠ Zone 2: Mean r2 = %.4f (NOT most negative; Zone %d is more negative)\n', ...
            mean_r2_by_zone(3), min_r2_zone);
        pattern_verified = false;
    end
end

% Zones 3 & 4 should have most positive r3
if class_counts(4) > 0 || class_counts(5) > 0
    [max_r3, max_r3_zone] = max(mean_r3_by_zone(2:5));
    max_r3_zone_actual = max_r3_zone;  % 1=Zone1, 2=Zone2, 3=Zone3, 4=Zone4
    if max_r3_zone_actual >= 3  % Zone 3 or 4
        fprintf('✓ Zone 3/4: Mean r3 = %.4f (most positive among fault zones)\n', max_r3);
    else
        fprintf('⚠ Zone 3/4: r3 signature weak. Most positive in Zone %d\n', max_r3_zone_actual);
        pattern_verified = false;
    end
end

fprintf('\n');

% ---- BLOCK 9: Final verdict ----
if pattern_verified
    fprintf('✓✓✓ PATTERN VERIFIED ✓✓✓\n');
    fprintf('Fault signatures match expected physics patterns.\n');
else
    fprintf('⚠⚠⚠ WARNING: UNEXPECTED PATTERN ⚠⚠⚠\n');
    fprintf('Fault signatures deviate from expected physics patterns.\n');
    fprintf('Possible causes:\n');
    fprintf('  - Simulink engine model needs tuning parameters adjusted\n');
    fprintf('  - Residual generator algorithm has an error\n');
    fprintf('  - Training data was corrupted or mislabeled\n');
    fprintf('Continue with caution. Review Simulink model before proceeding to training.\n');
end

fprintf('\n=================================================\n');
fprintf('STEP 1 COMPLETE\n');
fprintf('=================================================\n');
fprintf('Next: Run step2_train_normalizer.m\n\n');

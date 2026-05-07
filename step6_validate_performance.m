% ================================================================
% step6_validate_performance.m
%
% PURPOSE: Quantify system performance using cross-validation and
% compute minimum detectable leak (MDL) thresholds.
%
% INPUTS: training_normalized.mat, training_data_raw.mat
%
% OUTPUTS:
%   - performance_results.mat (cross-validation metrics, MDL values)
%   - MDL_curve.png (detection rate vs severity plot)
%
% ================================================================

clear; clc; close all;

fprintf('\n=================================================\n');
fprintf('STEP 6: VALIDATE PERFORMANCE & COMPUTE MDL\n');
fprintf('=================================================\n\n');

% ---- Load data ----
if ~exist('training_normalized.mat', 'file')
    error('ERROR: training_normalized.mat not found. Run step2 first.');
end
if ~exist('training_data_raw.mat', 'file')
    error('ERROR: training_data_raw.mat not found.');
end

load('training_normalized.mat', 'training_normalized');
load('training_data_raw.mat', 'training_data');

X_norm = training_normalized(:, 1:3);
y = training_normalized(:, 4);
X_raw = training_data(:, 1:3);

n_samples = size(X_norm, 1);
n_classes = 5;

fprintf('Loaded training data: %d samples\n\n', n_samples);

% ---- SECTION 1: 5-Fold Cross-Validation ----
fprintf('=== SECTION 1: CROSS-VALIDATION (5-FOLD) ===\n\n');

n_folds = 5;
fold_size = floor(n_samples / n_folds);

% Create fold indices
fold_indices = randperm(n_samples);

confusion_matrix = zeros(n_classes, n_classes);
class_precision = zeros(n_classes, 1);
class_recall = zeros(n_classes, 1);
class_f1 = zeros(n_classes, 1);

for fold = 1:n_folds
    fprintf('Fold %d/%d: ', fold, n_folds);

    % Define test set for this fold
    test_start = (fold - 1) * fold_size + 1;
    test_end = min(test_start + fold_size - 1, n_samples);
    test_idx = fold_indices(test_start:test_end);

    % Get train indices (all others)
    train_idx = setdiff(1:n_samples, test_idx);

    X_train = X_norm(train_idx, :);
    y_train = y(train_idx);
    X_test = X_norm(test_idx, :);
    y_test = y(test_idx);

    % Train 5 GPs (simple serial training for cross-val)
    gp_fold_models = cell(n_classes, 1);

    for c = 0:4
        y_binary_train = logical(y_train == c);
        gp_fold_models{c+1} = fitcgp(X_train, y_binary_train, ...
            'KernelFunction', 'squaredexponential', ...
            'OptimizeHyperparameters', 'auto', ...
            'HyperparameterOptimizationOptions', struct( ...
                'ShowPlots', false, 'Verbose', 0, 'MaxObjectiveEvaluations', 20));
    end

    % Predict on test set
    n_test = length(test_idx);
    p_test = zeros(n_test, n_classes);

    for i = 1:n_test
        for c = 0:4
            [~, score_c] = predict(gp_fold_models{c+1}, X_test(i, :));
            p_test(i, c+1) = score_c(2);
        end
    end

    % Normalize probabilities
    p_sum = sum(p_test, 2);
    p_test(p_sum > 0.01, :) = p_test(p_sum > 0.01, :) ./ p_sum(p_sum > 0.01);
    p_test(p_sum <= 0.01, :) = 1/n_classes;

    % Get predictions
    [~, y_pred_fold] = max(p_test, [], 2);
    y_pred_fold = y_pred_fold - 1;  % Convert to 0-based

    % Update confusion matrix
    for i = 1:n_test
        true_class = y_test(i) + 1;
        pred_class = y_pred_fold(i) + 1;
        confusion_matrix(true_class, pred_class) = confusion_matrix(true_class, pred_class) + 1;
    end

    fprintf('Done\n');
end

fprintf('\n--- Confusion Matrix ---\n');
fprintf('        Pred:  0       1       2       3       4\n');
for c = 0:4
    fprintf('True %d:     ', c);
    for p = 0:4
        fprintf('%6d ', confusion_matrix(c+1, p+1));
    end
    fprintf('\n');
end
fprintf('\n');

% Compute per-class metrics
for c = 0:4
    % Precision = TP / (TP + FP)
    tp = confusion_matrix(c+1, c+1);
    fp = sum(confusion_matrix(:, c+1)) - tp;
    class_precision(c+1) = tp / (tp + fp + eps);

    % Recall = TP / (TP + FN)
    fn = sum(confusion_matrix(c+1, :)) - tp;
    class_recall(c+1) = tp / (tp + fn + eps);

    % F1
    class_f1(c+1) = 2 * class_precision(c+1) * class_recall(c+1) / (class_precision(c+1) + class_recall(c+1) + eps);
end

overall_accuracy = 100 * trace(confusion_matrix) / sum(confusion_matrix(:));

fprintf('--- Per-Class Metrics ---\n');
fprintf('Class  Precision  Recall   F1-Score\n');
fprintf('%s\n', repmat('-', 1, 36));
for c = 0:4
    class_name = ['Zone ' char(abs(c) + 48)];
    fprintf('%s      %.3f      %.3f     %.3f\n', class_name, class_precision(c+1), class_recall(c+1), class_f1(c+1));
end
fprintf('\n');
fprintf('Overall Accuracy: %.1f%%\n\n', overall_accuracy);

% ---- SECTION 2: Detection rate vs severity (simplified) ----
fprintf('=== SECTION 2: MINIMUM DETECTABLE LEAK (MDL) ANALYSIS ===\n\n');

% For each zone, group by severity (approximated by dominant residual magnitude)
% and compute detection rate
n_severity_bins = 10;
severity_bins = linspace(0, 0.30, n_severity_bins);

detection_by_zone = cell(4, 1);  % zones A-D
mdl_values = zeros(4, 1);

for zone = 1:4  % zones 1-4 (A-D)
    zone_mask = (y == zone);
    zone_indices = find(zone_mask);

    if sum(zone_mask) < 5
        fprintf('Zone %s: Insufficient examples (%d)\n', char(zone + 64), sum(zone_mask));
        detection_by_zone{zone} = [];
        mdl_values(zone) = inf;
        continue;
    end

    X_zone_raw = X_raw(zone_indices, :);
    y_zone = y(zone_indices);

    % Compute dominant residual magnitude for each zone example
    switch zone
        case 1  % Zone A: r1 is dominant
            severity = abs(X_zone_raw(:, 1));
        case 2  % Zone B: r2 is dominant
            severity = abs(X_zone_raw(:, 2));
        case 3  % Zone C: r3 is dominant
            severity = X_zone_raw(:, 3);
        case 4  % Zone D: r3 is dominant
            severity = X_zone_raw(:, 3);
    end

    % Load pre-trained models for detection rate calculation
    load('GP_classifier.mat', 'GP_models');
    load('normalizer_params.mat', 'centroids', 'sigma_table');

    detections_by_severity = [];

    for i = 1:length(zone_indices)
        idx = zone_indices(i);
        r1 = X_raw(idx, 1);
        r2 = X_raw(idx, 2);
        r3 = X_raw(idx, 3);
        sev = severity(i);

        % Query classifier
        [flag, ~, ~, pred_zone, ~] = predict_leak_zone(r1, r2, r3);

        is_detected = (flag == 1 && pred_zone == zone);

        detections_by_severity = [detections_by_severity; [sev, is_detected]];
    end

    % Compute detection rate per severity bin
    bin_detection_rates = [];
    bin_severities = [];

    for b = 1:length(severity_bins)-1
        bin_mask = (detections_by_severity(:, 1) >= severity_bins(b)) & ...
                  (detections_by_severity(:, 1) < severity_bins(b+1));
        if sum(bin_mask) > 0
            rate = mean(detections_by_severity(bin_mask, 2));
            bin_severities = [bin_severities; mean(detections_by_severity(bin_mask, 1))];
            bin_detection_rates = [bin_detection_rates; rate];
        end
    end

    detection_by_zone{zone} = [bin_severities, bin_detection_rates];

    % Find MDL (severity at which detection rate crosses 0.95)
    if ~isempty(bin_detection_rates)
        [~, idx_95] = min(abs(bin_detection_rates - 0.95));
        mdl_values(zone) = bin_severities(idx_95);
        fprintf('Zone %s: MDL = %.2f flow loss at %.1f%% detection\n', ...
            char(zone + 64), mdl_values(zone), bin_detection_rates(idx_95)*100);
    end
end

fprintf('\n');

% ---- SECTION 3: Plot MDL curves ----
fprintf('=== Creating MDL Detection Rate vs Severity Plot ===\n\n');

figure('Position', [100, 100, 1000, 700]);
hold on;
grid on;
colors = {'b', 'r', [1 0.5 0], 'g'};
zone_labels = {'Zone A', 'Zone B', 'Zone C', 'Zone D'};

for zone = 1:4
    if ~isempty(detection_by_zone{zone})
        sev = detection_by_zone{zone}(:, 1);
        det = detection_by_zone{zone}(:, 2);
        plot(sev, det, 'o-', 'Color', colors{zone}, 'LineWidth', 2, 'MarkerSize', 6, 'DisplayName', zone_labels{zone});
    end
end

% Add horizontal MDL line at 95%
yline(0.95, 'r--', 'LineWidth', 1.5, 'DisplayName', '95% MDL Threshold');

xlabel('Leak Severity (flow loss)', 'FontSize', 12);
ylabel('Detection Probability', 'FontSize', 12);
title('Minimum Detectable Leak (MDL) — Caterpillar PS3 AI Pipeline', 'FontSize', 14, 'FontWeight', 'bold');
legend('Location', 'best', 'FontSize', 10);
xlim([0, 0.30]);
ylim([0, 1.05]);
set(gca, 'FontSize', 11);

saveas(gcf, 'MDL_curve.png');
fprintf('✓ Saved: MDL_curve.png\n\n');

% ---- SECTION 4: False positive rate ----
fprintf('=== SECTION 4: FALSE POSITIVE RATE ===\n\n');

nofault_mask = (y == 0);
nofault_indices = find(nofault_mask);

false_positives = 0;
for idx = nofault_indices'
    r1 = X_raw(idx, 1);
    r2 = X_raw(idx, 2);
    r3 = X_raw(idx, 3);

    [flag, ~, ~, zone, ~] = predict_leak_zone(r1, r2, r3);

    if flag == 1 && zone > 0
        false_positives = false_positives + 1;
    end
end

fpr = 100 * false_positives / length(nofault_indices);
fprintf('No-fault examples tested: %d\n', length(nofault_indices));
fprintf('False positives: %d\n', false_positives);
fprintf('False positive rate: %.2f%%\n\n', fpr);

if fpr > 5.0
    fprintf('⚠ WARNING: FPR > 5%%, consider lowering alert threshold\n\n');
end

% ---- SECTION 5: Correct isolation rate ----
fprintf('=== SECTION 5: ZONE ISOLATION ACCURACY ===\n\n');

fault_mask = (y > 0);
fault_indices = find(fault_mask);

correct_zone = 0;
correct_detection = 0;

for idx = fault_indices'
    r1 = X_raw(idx, 1);
    r2 = X_raw(idx, 2);
    r3 = X_raw(idx, 3);

    true_zone = y(idx);
    [flag, ~, ~, pred_zone, ~] = predict_leak_zone(r1, r2, r3);

    if flag == 1
        correct_detection = correct_detection + 1;
        if pred_zone == true_zone
            correct_zone = correct_zone + 1;
        end
    end
end

detection_rate = 100 * correct_detection / length(fault_indices);
isolation_rate = 100 * correct_zone / max(1, correct_detection);

fprintf('Total fault examples: %d\n', length(fault_indices));
fprintf('Correctly detected: %d (%.1f%%)\n', correct_detection, detection_rate);
fprintf('Correctly isolated: %d (%.1f%% of detected)\n\n', correct_zone, isolation_rate);

% ---- Final summary ----
fprintf('=================================================\n');
fprintf('PERFORMANCE SUMMARY\n');
fprintf('=================================================\n\n');

fprintf('=== MINIMUM DETECTABLE LEAK (MDL) RESULTS ===\n');
fprintf('Zone A: MDL = %.2f%% flow loss (at 95%% confidence)\n', mdl_values(1)*100);
fprintf('Zone B: MDL = %.2f%% flow loss\n', mdl_values(2)*100);
fprintf('Zone C: MDL = %.2f%% flow loss\n', mdl_values(3)*100);
fprintf('Zone D: MDL = %.2f%% flow loss\n', mdl_values(4)*100);
fprintf('==============================================\n');
fprintf('Cross-validation accuracy: %.1f%%\n', overall_accuracy);
fprintf('Overall detection rate: %.1f%%\n', detection_rate);
fprintf('False positive rate: %.2f%%\n', fpr);
fprintf('Correct zone isolation rate: %.1f%%\n', isolation_rate);
fprintf('==============================================\n\n');

% ---- Save results ----
save('performance_results.mat', 'confusion_matrix', 'class_precision', 'class_recall', 'class_f1', ...
     'overall_accuracy', 'mdl_values', 'detection_rate', 'fpr', 'isolation_rate');

fprintf('✓ Saved: performance_results.mat\n\n');

fprintf('=================================================\n');
fprintf('STEP 6 COMPLETE\n');
fprintf('=================================================\n');
fprintf('Next: Run plot_residual_space.m\n\n');

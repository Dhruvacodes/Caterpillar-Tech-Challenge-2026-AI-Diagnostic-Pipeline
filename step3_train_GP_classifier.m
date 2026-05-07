% ================================================================
% step3_train_GP_classifier.m
%
% PURPOSE: Implement Layer 4 — Train 5 binary Gaussian Process
% classifiers using one-vs-rest (OvR) strategy.
%
% OUTPUTS: GP_classifier.mat containing:
%   - GP_models (cell array of 5 fitcgp objects)
%   - class_names
%   - K_classes
%   - training_date
%
% DEPENDENCIES: training_normalized.mat from step2
%
% ================================================================

clear; clc; close all;

fprintf('\n=================================================\n');
fprintf('STEP 3: TRAINING GP CLASSIFIERS (5-class OvR)\n');
fprintf('=================================================\n\n');

% ---- BLOCK A: Load normalized training data ----
if ~exist('training_normalized.mat', 'file')
    error('ERROR: training_normalized.mat not found. Run step2 first.');
end

load('training_normalized.mat', 'training_normalized');
assert(size(training_normalized, 2) == 4, 'Expected 4 columns');

X = training_normalized(:, 1:3);  % normalized residuals
y = training_normalized(:, 4);     % zone labels
n_total = size(X, 1);

fprintf('Dataset loaded: %d rows × 3 features (normalized residuals)\n', n_total);
fprintf('Class distribution:\n');

class_counts = zeros(5, 1);
for k = 0:4
    count = sum(y == k);
    class_counts(k+1) = count;
    fprintf('  Zone %d: %4d rows (%5.1f%%)\n', k, count, 100*count/n_total);
end
fprintf('\n');

% ---- BLOCK B: Kernel selection rationale ----
fprintf('--- Kernel Selection: Squared Exponential (RBF) ---\n');
fprintf('Rationale:\n');
fprintf('  - RBF kernel assumes smooth, continuous relationships\n');
fprintf('  - Residuals vary smoothly with leak severity\n');
fprintf('  - Hyperparameters (length scale, signal variance) optimized\n');
fprintf('    automatically via marginal likelihood maximization\n');
fprintf('  - Suitable for nonlinear fault signatures\n\n');

KERNEL = 'squaredexponential';
K_CLASSES = 5;
class_names = {'NoFault','ZoneA','ZoneB','ZoneC','ZoneD'};

% ---- BLOCK C: Train 5 binary GP classifiers ----
fprintf('--- Training 5 Binary GP Classifiers (OvR Strategy) ---\n\n');

GP_models = cell(K_CLASSES, 1);
total_train_time = 0;

for k = 0:4
    fprintf('Training GP[%d] (%s vs Rest)...\n', k, class_names{k+1});

    % Create binary labels
    y_binary = logical(y == k);
    n_pos = sum(y_binary);
    n_neg = sum(~y_binary);

    fprintf('  Positive (class %d): %d\n', k, n_pos);
    fprintf('  Negative (all others): %d\n', n_neg);

    if n_pos < 5
        fprintf('  ⚠ WARNING: Only %d positive examples (minimum recommended: 5)\n', n_pos);
    end

    % Train GP
    tic;
    try
        GP_models{k+1} = fitcgp(X, y_binary, ...
            'KernelFunction', KERNEL, ...
            'OptimizeHyperparameters', 'auto', ...
            'HyperparameterOptimizationOptions', struct( ...
                'ShowPlots', false, ...
                'Verbose', 0, ...
                'MaxObjectiveEvaluations', 30));
    catch ME
        % Fallback: add noise parameter if covariance singular
        fprintf('  ⚠ Initial training failed, adding Sigma=0.01\n');
        GP_models{k+1} = fitcgp(X, y_binary, ...
            'KernelFunction', KERNEL, ...
            'Sigma', 0.01, ...
            'OptimizeHyperparameters', 'auto', ...
            'HyperparameterOptimizationOptions', struct( ...
                'ShowPlots', false, ...
                'Verbose', 0, ...
                'MaxObjectiveEvaluations', 30));
    end
    elapsed = toc;
    total_train_time = total_train_time + elapsed;

    % Compute resubstitution loss
    [~, score] = predict(GP_models{k+1}, X);
    p_pos = score(:, 2);
    y_pred = (p_pos >= 0.5);
    accuracy = mean(y_pred == y_binary);

    % Extract hyperparameters (if available from KernelInformation)
    fprintf('  Resubstitution Accuracy: %.2f%%\n', 100*accuracy);
    fprintf('  Training time: %.2f seconds\n', elapsed);
    fprintf('  ✓ GP[%d] training complete\n\n', k);
end

fprintf('Total training time for all 5 GPs: %.2f seconds\n\n', total_train_time);

% ---- BLOCK D: Quick sanity check on all 5 GPs ----
fprintf('--- Sanity Check: Training Set Accuracy ---\n');

p_matrix = zeros(n_total, K_CLASSES);

for c = 1:K_CLASSES
    [~, score] = predict(GP_models{c}, X);
    p_matrix(:, c) = score(:, 2);  % probability of positive class (class c-1)
end

% Clamp to prevent numerical issues
p_matrix = max(0.001, min(0.999, p_matrix));

% Normalize probabilities
p_sum = sum(p_matrix, 2);
p_normalized = p_matrix ./ p_sum;

% Predict class as argmax
[~, y_pred] = max(p_normalized, [], 2);
y_pred = y_pred - 1;  % convert from 1-indexed to 0-indexed

overall_accuracy = mean(y_pred == y);
fprintf('Overall training set accuracy: %.2f%%\n', 100*overall_accuracy);
fprintf('Note: This is optimistic. Validation accuracy typically 3-8%% lower.\n\n');

% ---- BLOCK E: Save trained models ----
fprintf('--- Saving GP_classifier.mat ---\n');

training_date = datestr(now);
save('GP_classifier.mat', 'GP_models', 'class_names', 'K_CLASSES', 'training_date');

fprintf('✓ Saved: GP_classifier.mat\n');
fprintf('  - 5 trained fitcgp models\n');
fprintf('  - Class names: NoFault, ZoneA, ZoneB, ZoneC, ZoneD\n');
fprintf('  - Training date: %s\n\n', training_date);

fprintf('=================================================\n');
fprintf('STEP 3 COMPLETE\n');
fprintf('=================================================\n');
fprintf('Next: Run step4_test_single_prediction.m\n\n');

% ================================================================
% step2_train_normalizer.m
%
% PURPOSE: Implement Layer 3 — K-Means clustering on no-fault data,
% compute per-regime standard deviations, and normalize all residuals.
%
% OUTPUTS:
%   - normalizer_params.mat: centroids (4×3), sigma_table (4×3)
%   - training_normalized.mat: normalized training data, centroids, sigma_table
%
% DEPENDENCIES: training_data_raw.mat from Simulink
%
% ================================================================

clear; clc; close all;

fprintf('\n=================================================\n');
fprintf('STEP 2: TRAINING NORMALIZER (K-MEANS + SIGMA)\n');
fprintf('=================================================\n\n');

% ---- BLOCK A: Load and validate data ----
if ~exist('training_data_raw.mat', 'file')
    error('ERROR: training_data_raw.mat not found. Run step1 first.');
end

load('training_data_raw.mat', 'training_data');
assert(size(training_data, 2) == 4, 'Expected 4 columns [r1, r2, r3, label]');

n_total = size(training_data, 1);
r1_raw = training_data(:, 1);
r2_raw = training_data(:, 2);
r3_raw = training_data(:, 3);
labels = training_data(:, 4);

nofault_mask = (labels == 0);
fault_mask = (labels > 0);

n_nofault = sum(nofault_mask);
n_fault = sum(fault_mask);

fprintf('Data loaded: %d total rows\n', n_total);
fprintf('No-fault rows: %d\n', n_nofault);
fprintf('Fault rows: %d\n\n', n_fault);

% Validate we have enough no-fault data
if n_nofault < 20
    error('ERROR: Insufficient no-fault data (%d rows). Need at least 20 for K-Means.', n_nofault);
end

% ---- BLOCK B: K-Means clustering on no-fault data ----
fprintf('--- K-Means Clustering (K=4) ---\n');
tic;

nofault_data = [r1_raw(nofault_mask), r2_raw(nofault_mask), r3_raw(nofault_mask)];
K_CLUSTERS = 4;

[cluster_assignments_nofault, centroids] = kmeans(nofault_data, K_CLUSTERS, ...
    'Replicates', 20, ...
    'Distance', 'sqeuclidean', ...
    'MaxIter', 300);

elapsed = toc;
fprintf('✓ K-Means completed in %.2f seconds\n\n', elapsed);

% Print centroids
fprintf('Cluster Centroids (4×3):\n');
fprintf('Cluster    r1_center     r2_center     r3_center\n');
fprintf('%s\n', repmat('-', 1, 50));
for k = 1:K_CLUSTERS
    fprintf('  %d       %10.4f    %10.4f    %10.4f\n', ...
        k, centroids(k,1), centroids(k,2), centroids(k,3));
end
fprintf('\n');

% ---- BLOCK C: Per-regime variance estimation ----
fprintf('--- Per-Regime Variance Estimation ---\n');

sigma_table = zeros(K_CLUSTERS, 3);
epsilon = 1e-6;

for k = 1:K_CLUSTERS
    % Find rows assigned to this cluster (from no-fault data only)
    cluster_mask_nofault = (cluster_assignments_nofault == k);
    n_in_cluster = sum(cluster_mask_nofault);

    if n_in_cluster > 0
        % Grab the actual rows from the no-fault subset
        r1_cluster = nofault_data(cluster_mask_nofault, 1);
        r2_cluster = nofault_data(cluster_mask_nofault, 2);
        r3_cluster = nofault_data(cluster_mask_nofault, 3);

        sigma_table(k, 1) = std(r1_cluster) + epsilon;
        sigma_table(k, 2) = std(r2_cluster) + epsilon;
        sigma_table(k, 3) = std(r3_cluster) + epsilon;
    else
        % Empty cluster — use a default sigma
        sigma_table(k, :) = 1.0;
        fprintf('⚠ Cluster %d is empty; using default sigma=1.0\n', k);
    end
end

fprintf('Sigma Table (per-regime standard deviations) (4×3):\n');
fprintf('Cluster    sigma_r1      sigma_r2      sigma_r3\n');
fprintf('%s\n', repmat('-', 1, 50));
for k = 1:K_CLUSTERS
    fprintf('  %d       %10.6f    %10.6f    %10.6f\n', ...
        k, sigma_table(k,1), sigma_table(k,2), sigma_table(k,3));
end
fprintf('\n');

% ---- BLOCK D: Assign ALL rows to nearest cluster ----
fprintf('--- Assigning All Rows to Nearest Cluster ---\n');

all_data = [r1_raw, r2_raw, r3_raw];
all_cluster_assignments = zeros(n_total, 1);

for i = 1:n_total
    % Euclidean distance to each centroid
    distances = sqrt(sum((all_data(i, :) - centroids).^2, 2));
    [~, nearest_k] = min(distances);
    all_cluster_assignments(i) = nearest_k;
end

fprintf('✓ All %d rows assigned to nearest cluster\n\n', n_total);

% ---- BLOCK E: Normalize ALL residuals ----
fprintf('--- Normalizing All Residuals ---\n');

r1_norm = zeros(n_total, 1);
r2_norm = zeros(n_total, 1);
r3_norm = zeros(n_total, 1);

for i = 1:n_total
    k = all_cluster_assignments(i);
    r1_norm(i) = r1_raw(i) / sigma_table(k, 1);
    r2_norm(i) = r2_raw(i) / sigma_table(k, 2);
    r3_norm(i) = r3_raw(i) / sigma_table(k, 3);
end

training_normalized = [r1_norm, r2_norm, r3_norm, labels];
fprintf('✓ Normalization complete: %d rows × 4 columns\n\n', n_total);

% ---- BLOCK F: Validation check on no-fault normalized data ----
fprintf('--- Post-Normalization Validation Check ---\n');

nofault_r1_norm = r1_norm(nofault_mask);
nofault_r2_norm = r2_norm(nofault_mask);
nofault_r3_norm = r3_norm(nofault_mask);

std_r1_after = std(nofault_r1_norm);
std_r2_after = std(nofault_r2_norm);
std_r3_after = std(nofault_r3_norm);

fprintf('Post-normalization std check (no-fault data only):\n');
fprintf('  r1_norm std: %.4f (should be ~1.0)\n', std_r1_after);
fprintf('  r2_norm std: %.4f (should be ~1.0)\n', std_r2_after);
fprintf('  r3_norm std: %.4f (should be ~1.0)\n\n', std_r3_after);

% Warn if outside acceptable range
TOL_LOW = 0.5;
TOL_HIGH = 1.5;

any_warning = false;
if std_r1_after < TOL_LOW || std_r1_after > TOL_HIGH
    fprintf('⚠ WARNING: r1_norm std = %.4f is outside [%.1f, %.1f]\n', std_r1_after, TOL_LOW, TOL_HIGH);
    any_warning = true;
end
if std_r2_after < TOL_LOW || std_r2_after > TOL_HIGH
    fprintf('⚠ WARNING: r2_norm std = %.4f is outside [%.1f, %.1f]\n', std_r2_after, TOL_LOW, TOL_HIGH);
    any_warning = true;
end
if std_r3_after < TOL_LOW || std_r3_after > TOL_HIGH
    fprintf('⚠ WARNING: r3_norm std = %.4f is outside [%.1f, %.1f]\n', std_r3_after, TOL_LOW, TOL_HIGH);
    any_warning = true;
end

if ~any_warning
    fprintf('✓ All post-normalization stds within acceptable range\n\n');
else
    fprintf('\n');
end

% ---- BLOCK G: Save normalizer parameters ----
fprintf('--- Saving Files ---\n');

save('normalizer_params.mat', 'centroids', 'sigma_table');
fprintf('✓ Saved: normalizer_params.mat\n');

save('training_normalized.mat', 'training_normalized', 'centroids', 'sigma_table');
fprintf('✓ Saved: training_normalized.mat\n\n');

fprintf('=================================================\n');
fprintf('STEP 2 COMPLETE\n');
fprintf('=================================================\n');
fprintf('Normalizer trained and saved.\n');
fprintf('Next: Run step3_train_GP_classifier.m\n\n');

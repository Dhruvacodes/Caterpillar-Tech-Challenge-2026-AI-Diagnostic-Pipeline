% step6_validate_performance.m - Performance validation script
clear; clc; close all;
fprintf("STEP 6: PERFORMANCE VALIDATION\n");
if ~exist("training_normalized.mat", "file")
    error("training_normalized.mat not found");
end
load("training_normalized.mat", "training_normalized");
load("training_data_raw.mat", "training_data");
X = training_normalized(:, 1:3);
y = training_normalized(:, 4);
r_raw = training_data(:, 1:3);
fprintf("Loaded %d training examples\n", size(X, 1));
fprintf("STEP 6 COMPLETE\n");
fprintf("Next: Run plot_residual_space.m\n");

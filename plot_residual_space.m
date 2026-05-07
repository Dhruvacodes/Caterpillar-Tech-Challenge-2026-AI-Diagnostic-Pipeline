% ================================================================
% plot_residual_space.m
%
% PURPOSE: Generate 3D scatter plot of training data in normalized
% residual space. For presentation: shows fault zones are separable.
%
% OUTPUTS: residual_space_3D.png
%
% DEPENDENCIES: training_normalized.mat
%
% ================================================================

clear; clc; close all;

fprintf('\n=================================================\n');
fprintf('STEP 10: RESIDUAL SPACE VISUALIZATION\n');
fprintf('=================================================\n\n');

if ~exist('training_normalized.mat', 'file')
    error('ERROR: training_normalized.mat not found.');
end

load('training_normalized.mat', 'training_normalized');

r1_norm = training_normalized(:, 1);
r2_norm = training_normalized(:, 2);
r3_norm = training_normalized(:, 3);
labels = training_normalized(:, 4);

fprintf('✓ Data loaded. Creating 3D scatter plot...\n\n');

% ---- Create figure ----
figure('Name', 'Residual Space - Interactive', 'Position', [100, 100, 1000, 800]);
hold on;

% ---- Color scheme ----
colors = [
    0.5, 0.5, 0.5;  % Zone 0 (no fault) = gray
    0, 0.447, 0.741;  % Zone 1 (A) = blue
    0.850, 0.325, 0.098;  % Zone 2 (B) = red
    0.929, 0.694, 0.125;  % Zone 3 (C) = orange
    0.466, 0.674, 0.188   % Zone 4 (D) = green
];

zone_names = {'No Fault', 'Zone A (MAF-Comp)', 'Zone B (Charge Air)', ...
    'Zone C (Pre-Turbine)', 'Zone D (Post-Turbine)'};

% ---- Plot each zone with different color ----
for z = 0:4
    mask = (labels == z);
    scatter3(r1_norm(mask), r2_norm(mask), r3_norm(mask), ...
        60, 'MarkerFaceColor', colors(z+1, :), ...
        'MarkerEdgeColor', 'black', ...
        'MarkerFaceAlpha', 0.6, ...
        'MarkerEdgeAlpha', 0.8, ...
        'DisplayName', zone_names{z+1});
end

% ---- Add magnitude gate sphere (2.0 normalized units) ----
[x_sphere, y_sphere, z_sphere] = sphere(20);
x_sphere = 2.0 * x_sphere;
y_sphere = 2.0 * y_sphere;
z_sphere = 2.0 * z_sphere;

surf(x_sphere, y_sphere, z_sphere, ...
    'FaceColor', [0.9, 0.9, 0.9], ...
    'FaceAlpha', 0.1, ...
    'EdgeColor', 'none', ...
    'DisplayName', 'Magnitude Gate (r=2.0)');

% ---- Labels and formatting ----
xlabel('r̂_1 (normalized mass balance)', 'FontSize', 12, 'FontWeight', 'bold');
ylabel('r̂_2 (normalized pressure ratio)', 'FontSize', 12, 'FontWeight', 'bold');
zlabel('r̂_3 (normalized exhaust energy)', 'FontSize', 12, 'FontWeight', 'bold');

title('Fault Zone Separation in Normalized Residual Space', ...
    'FontSize', 14, 'FontWeight', 'bold');

legend('Location', 'northeast', 'FontSize', 10);
grid on;
set(gca, 'FontSize', 11);
view(45, 30);

% ---- Save figure ----
saveas(gcf, 'residual_space_3D.png');
fprintf('✓ Saved: residual_space_3D.png (150 dpi)\n\n');

fprintf('=================================================\n');
fprintf('STEP 10 COMPLETE\n');
fprintf('=================================================\n');
fprintf('Next: Run GP_Classifier_Simulink_Block.m integration\n\n');

% ================================================================
% plot_residual_space.m
%
% PURPOSE: Generate 3D scatter plot of training data in normalized
% residual space. Shows judges that fault zones are separable.
%
% INPUTS: training_normalized.mat
%
% OUTPUTS: residual_space_3D.png (publication-quality 3D visualization)
%
% ================================================================

clear; clc; close all;

fprintf('\n=================================================\n');
fprintf('STEP 10: 3D RESIDUAL SPACE VISUALIZATION\n');
fprintf('=================================================\n\n');

% ---- Load normalized training data ----
if ~exist('training_normalized.mat', 'file')
    error('ERROR: training_normalized.mat not found. Run step2 first.');
end

load('training_normalized.mat', 'training_normalized', 'centroids');

r1_norm = training_normalized(:, 1);
r2_norm = training_normalized(:, 2);
r3_norm = training_normalized(:, 3);
zone_labels = training_normalized(:, 4);

fprintf('Loaded normalized training data: %d samples\n\n', size(training_normalized, 1));

% ---- Create 3D scatter plot ----
figure('Position', [150, 150, 1200, 900], 'Name', 'Residual Space — Interactive 3D View');
hold on;
grid on;

% Color scheme and zone labels
colors = [0.5, 0.5, 0.5;      % Zone 0: Gray
          0, 0, 1;             % Zone 1: Blue (A)
          1, 0, 0;             % Zone 2: Red (B)
          1, 0.65, 0;          % Zone 3: Orange (C)
          0, 0.7, 0];          % Zone 4: Green (D)

zone_names = {'No Fault', 'Zone A (MAF−Comp)', 'Zone B (Charge−Air)', ...
              'Zone C (Pre−Turbine)', 'Zone D (Post−Turbine)'};

% Plot each zone's points
for zone = 0:4
    mask = (zone_labels == zone);
    if sum(mask) > 0
        scatter3(r1_norm(mask), r2_norm(mask), r3_norm(mask), ...
                 60, 'MarkerFaceColor', colors(zone+1, :), ...
                 'MarkerEdgeColor', 'k', 'MarkerFaceAlpha', 0.6, ...
                 'MarkerEdgeAlpha', 0.7, 'DisplayName', zone_names{zone+1});
    end
end

% ---- Add magnitude gate boundary (sphere radius = 2.0) ----
% Note: Uses normalized residuals, not raw
[x_sphere, y_sphere, z_sphere] = sphere(30);
x_sphere = x_sphere * 2.0;
y_sphere = y_sphere * 2.0;
z_sphere = z_sphere * 2.0;

surfl(x_sphere, y_sphere, z_sphere, 'FaceAlpha', 0.05, 'EdgeColor', 'r', 'EdgeAlpha', 0.3);
colormap(gca, parula);

% ---- Labels and formatting ----
xlabel('r̂₁ — Mass Balance (normalized)', 'FontSize', 13, 'FontWeight', 'bold');
ylabel('r̂₂ — Pressure Ratio (normalized)', 'FontSize', 13, 'FontWeight', 'bold');
zlabel('r̂₃ — Exhaust Energy (normalized)', 'FontSize', 13, 'FontWeight', 'bold');

title('Fault Zone Separation in Normalized Residual Space', ...
      'FontSize', 15, 'FontWeight', 'bold');

% ---- Legend ----
legend_handle = legend('Location', 'northeast', 'FontSize', 11, 'Interpreter', 'tex');
set(legend_handle, 'Box', 'on', 'BackgroundAlpha', 0.85);

% ---- Viewing angle ----
view(45, 30);
axis equal;
grid on;
set(gca, 'FontSize', 11, 'LineWidth', 1.2);

% ---- Annotations ----
text_str = sprintf('Training set: %d samples', size(training_normalized, 1));
text(0.02, 0.98, text_str, 'Units', 'normalized', 'FontSize', 10, ...
    'VerticalAlignment', 'top', 'BackgroundColor', 'w', 'EdgeColor', 'k');

fprintf('✓ 3D scatter plot created\n');
fprintf('  - Zones color-coded\n');
fprintf('  - Magnitude gate sphere visualized (r̂ = 2.0 radius)\n');
fprintf('  - View angle: (45, 30) for clear separation\n\n');

% ---- Save figure ----
fprintf('Saving figure...\n');
print(gcf, 'residual_space_3D.png', '-dpng', '-r150');
fprintf('✓ Saved: residual_space_3D.png (150 dpi)\n\n');

% ---- Rotation instructions ----
fprintf('Figure saved. In MATLAB, the figure window allows interactive rotation:\n');
fprintf('  - Use left-click drag to rotate\n');
fprintf('  - Use right-click drag to zoom\n');
fprintf('  - Use scroll wheel to pan\n\n');

fprintf('=================================================\n');
fprintf('STEP 10 COMPLETE\n');
fprintf('=================================================\n');
fprintf('Next: Run plot_residual_space.m\n');
fprintf('Final: GP_Classifier_Simulink_Block.m (copy into Simulink)\n\n');

%% MINIMAL CODE - EXACT LAYOUT MATCH
clear all; close all; clc;

%% Run models
specs = {'dsge_gali', 'dsge_swiss_base', 'dsge_full_rega', 'dsge_full_regb', 'dsge_unstable'};
for i = 1:5
    evalc(['dynare ' specs{i} ' noclearall nolog']);
    R.(specs{i}) = oo_.irfs;
end

%% Figure 1: Stability (1x4 layout)
figure('Position', [100,100,1200,350], 'Color', 'w');
vars = {'pi', 'er'};
titles = {'\pi (Stable)', 'e (Stable)', '\pi (Unstable)', 'e (Unstable)'};

for v = 1:2
    % Stable (blue solid)
    subplot(1,4,v); hold on; box on; grid on;
    plot(0:14, R.dsge_swiss_base.([vars{v} '_eps_nu'])*100, '-', ...
         'Color', [0 0.447 0.741], 'LineWidth', 2.5);
    yline(0,'k-',  'LineWidth', 0.5);
    title(titles{v}, 'FontSize', 11);
    xlabel('Quarters'); ylabel('Basis points');
    xlim([0 14]);
    
    % Unstable (orange dashed)
    subplot(1,4,v+2); hold on; box on; grid on;
    plot(0:14, R.dsge_unstable.([vars{v} '_eps_nu'])*100, '--', ...
         'Color', [0.85 0.325 0.098], 'LineWidth', 2.5);
    yline(0,'k-', 'LineWidth', 0.5);
    title(titles{v+2}, 'FontSize', 11);
    xlabel('Quarters'); ylabel('Basis points');
    xlim([0 14]);
end
print('Fig_Stability_Clean', '-dpng', '-r300');
close;

%% Figure 2: 4-Panel (2x2 layout)
figure('Position', [100,100,900,600], 'Color', 'w');
vars = {'pi_h', 'pi', 'er', 'i'};
titles = {'\pi_H', '\pi', 'e', 'i'};
ylabs = {'Basis points', 'Basis points', 'Percentage points', 'Basis points'};
names = {'Galí', 'Swiss Base', 'Full (Reg A)', 'Full (Reg B)'};
colors = {[0 0 0], [0 0.447 0.741], [0.85 0.325 0.098], [0.466 0.674 0.188]};
styles = {'-', '--', '-.', ':'};
widths = [1.2, 1.8, 2.0, 2.0];

for v = 1:4
    subplot(2,2,v); hold on; box on; grid on;
    for s = 1:4
        irf = R.(specs{s}).([vars{v} '_eps_nu']);
        if v~=3, irf = irf*100; end  % bp except ER (percentage points)
        plot(0:14, irf, styles{s}, 'Color', colors{s}, 'LineWidth', widths(s));
    end
    yline(0,'k-', 'LineWidth', 0.5);
    title(titles{v}, 'FontSize', 12);
    xlabel('Quarters', 'FontSize', 10);
    ylabel(ylabs{v}, 'FontSize', 10);
    xlim([0 14]);
    if v==1
        legend(names, 'Location', 'best', 'FontSize', 8);
    end
end
print('Fig_4Panel_Clean', '-dpng', '-r300');
close;

%% Figure 3: Regime (2x4 layout)
figure('Position', [100,100,1200,500], 'Color', 'w');
vars = {'pi_h', 'pi', 'er', 'i'};
titles = {'\pi_H', '\pi', 'e', 'i'};

for v = 1:4
    % Top row: IRF comparison
    subplot(2,4,v); hold on; box on; grid on;
    irf_a = R.dsge_full_rega.([vars{v} '_eps_nu']);
    irf_b = R.dsge_full_regb.([vars{v} '_eps_nu']);
    if v~=3, irf_a = irf_a*100; irf_b = irf_b*100; end
    
    plot(0:14, irf_a, '-', 'Color', [0 0.447 0.741], 'LineWidth', 2);
    plot(0:14, irf_b, '--', 'Color', [0.85 0.325 0.098], 'LineWidth', 2);
    yline(0,'k-', 'LineWidth', 0.5);
    title(titles{v}, 'FontSize', 11);
    xlabel('Quarters', 'FontSize', 9);
    xlim([0 14]);
    if v==1
        legend('Regime A', 'Regime B', 'Location', 'best', 'FontSize', 8);
    end
    
    % Bottom row: Difference bars
    subplot(2,4,v+4); hold on; box on; grid on;
    bar(0:14, irf_a-irf_b, 'FaceColor', [0.5 0.5 0.5], 'EdgeColor', 'none');
    yline(0,'k-', 'LineWidth', 0.5);
    xlabel('Quarters', 'FontSize', 9);
    ylabel('A - B', 'FontSize', 9);
    xlim([-0.5 14.5]);
end
print('Fig_Regime_Clean', '-dpng', '-r300');
close;

disp('✓ Fig_Stability_Clean.png');
disp('✓ Fig_4Panel_Clean.png');
disp('✓ Fig_Regime_Clean.png');
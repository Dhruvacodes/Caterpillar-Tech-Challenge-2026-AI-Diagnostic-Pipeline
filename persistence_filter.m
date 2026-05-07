function [final_flag, final_zone, counter_snapshot] = persistence_filter(flag_in, zone_in, confidence_in)
% ================================================================
% persistence_filter.m
%
% Layer 5 — Temporal smoothing and hysteresis. Require fault to
% persist across N consecutive windows before confirming alert.
%
% INPUTS:
%   flag_in: integer 0/1/2 from predict_leak_zone
%   zone_in: integer 0–4 from predict_leak_zone
%   confidence_in: scalar [0,1] confidence from predict_leak_zone
%
% OUTPUTS:
%   final_flag: integer 0/1/2 (confirmed output after persistence)
%   final_zone: integer 0–4 (confirmed zone)
%   counter_snapshot: 1×4 vector (alert counter values for zones 1–4)
%
% STATE: Maintained via persistent variables across calls
%
% NOTE: Call reset_persistence_filter() to reset state between
%       simulation runs or when restarting monitoring.
%
% ================================================================

persistent alert_counters in_alert_state confirmed_zone no_fault_streak last_zone

% ---- Initialize on first call ----
if isempty(alert_counters)
    alert_counters = zeros(1, 4);     % one counter per zone (A, B, C, D)
    in_alert_state = false;
    confirmed_zone = 0;
    no_fault_streak = 0;
    last_zone = 0;
end

% ---- Parameters ----
N_PERSIST = 5;      % windows required before confirming alert
P_EXIT = 0.40;      % confidence below this clears alert (no-fault streak)
DECAY_RATE = 0.5;   % counter decay per window when zone not active
CLEAR_STREAK = 3;   % consecutive no-fault windows to clear alert

counter_snapshot = alert_counters;

% ---- Logic flow ----

if flag_in == 1 && zone_in > 0
    % ---- CASE 1: Incoming flag is 1 (fault) ----

    % Increment counter for this zone
    alert_counters(zone_in) = alert_counters(zone_in) + 1;

    % Decay other zone counters
    for z = 1:4
        if z ~= zone_in
            alert_counters(z) = max(0, alert_counters(z) * DECAY_RATE);
        end
    end

    % Check if already in alert state for same zone
    if in_alert_state && confirmed_zone == zone_in
        % Maintain existing alert
        final_flag = 1;
        final_zone = confirmed_zone;
    elseif alert_counters(zone_in) >= N_PERSIST
        % Confirmation threshold reached
        in_alert_state = true;
        confirmed_zone = zone_in;
        no_fault_streak = 0;
        final_flag = 1;
        final_zone = zone_in;
    else
        % Still counting toward confirmation
        final_flag = 2;
        final_zone = zone_in;
    end

    last_zone = zone_in;

elseif flag_in == 0
    % ---- CASE 2: Incoming flag is 0 (no fault) ----

    % Decay ALL counters
    alert_counters = max(0, alert_counters * DECAY_RATE);
    no_fault_streak = no_fault_streak + 1;

    if in_alert_state
        % Still in alert state but receiving no-fault signal
        if no_fault_streak >= CLEAR_STREAK
            % Hysteresis: clear alert after N consecutive no-fault windows
            in_alert_state = false;
            confirmed_zone = 0;
            final_flag = 0;
            final_zone = 0;
        else
            % First few no-fault windows: stay in alert (hysteresis)
            final_flag = 1;
            final_zone = confirmed_zone;
        end
    else
        % Not in alert, no problem
        final_flag = 0;
        final_zone = 0;
    end

else
    % ---- CASE 3: Incoming flag is 2 (uncertain) ----

    % Do not change counters
    % Maintain current state

    no_fault_streak = 0;

    if in_alert_state
        final_flag = 1;
        final_zone = confirmed_zone;
    else
        final_flag = 2;
        final_zone = zone_in;
    end

end

% Update snapshot
counter_snapshot = alert_counters;

end  % function persistence_filter

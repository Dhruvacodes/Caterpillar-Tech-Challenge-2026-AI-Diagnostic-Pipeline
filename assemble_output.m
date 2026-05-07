function [flag_str, confidence_str, location_str, action_str] = assemble_output(final_flag, confidence, confidence_sigma, final_zone)
% ================================================================
% assemble_output.m
%
% Layer 6 — Assemble numeric outputs into four human-readable strings:
%   1. FLAG — leak status
%   2. CONFIDENCE — calibrated posterior probability with bounds
%   3. LOCATION — which zone (or none)
%   4. ACTION — specific physical inspection recommendation
%
% INPUTS:
%   final_flag: integer 0/1/2
%   confidence: scalar [0,1]
%   confidence_sigma: scalar [0,1]
%   final_zone: integer 0–4
%
% OUTPUTS:
%   flag_str: string — "NO LEAK" / "⚠ LEAK DETECTED" / "◉ UNCERTAIN..."
%   confidence_str: string — percentage with bounds or "N/A"
%   location_str: string — zone description or "None"
%   action_str: string — inspection instructions
%
% ================================================================

% ---- Zone display names ----
zone_display_names = {
    'No fault — all zones nominal', ...
    'Zone A: Intake duct between MAF sensor and turbocharger compressor inlet', ...
    'Zone B: Charge-air system — compressor outlet through intercooler to intake manifold', ...
    'Zone C: Exhaust pre-turbine — exhaust manifold to turbocharger turbine inlet', ...
    'Zone D: Exhaust post-turbine — turbine outlet through aftertreatment to tailpipe'
};

% ---- Action lookup table (one per zone 0–4) ----
actions = {
    'Continue testing. All physics residuals within baseline bounds. No anomaly detected.', ...
    sprintf(['INSPECT: Intake ducting between MAF sensor and turbocharger compressor inlet. ' ...
        'Check all hose clamps, rubber couplings, and flange connections. Look for oil streaks ' ...
        'or residue on duct surfaces (indicates air movement). IMPORTANT: Verify MAF sensor ' ...
        'calibration first — a drifting MAF sensor produces an r1 signature identical to ' ...
        'a Zone A leak. Confirm sensor reading with a secondary flow check if available ' ...
        'before physical disassembly.']), ...
    sprintf(['INSPECT: Pressure-test the entire charge-air circuit from compressor outlet ' ...
        'to intake manifold ports. Focus on intercooler (CAC) inlet/outlet hose couplings, ' ...
        'all charge-air pipe clamps, and boost pipe sections. Check clamps for correct ' ...
        'tightening torque. Definitive field confirmation: MAP drops while compressor ' ...
        'outlet pressure remains normal. Use a hand pump pressure tester at 1.5× boost ' ...
        'pressure to locate the leak.']), ...
    sprintf(['INSPECT: Exhaust manifold gaskets at each cylinder head interface. ' ...
        'Turbocharger turbine inlet connection and all exhaust manifold-to-head bolts ' ...
        '(check torque). Inspect manifold casting for thermal fatigue cracks — common at ' ...
        'sharp bends and flange interfaces. Definitive field confirmation: EGT drops ' ...
        'simultaneously with boost loss. Do not run engine at high load until inspection ' ...
        'is complete — exhaust gases near personnel are a safety hazard.']), ...
    sprintf(['INSPECT: All connections from turbine outlet to tailpipe. Priority order: ' ...
        '(1) DPF inlet V-band clamp, (2) SCR inlet and outlet pipe flanges, (3) test cell ' ...
        'exhaust duct connection. Definitive field confirmation: exhaust backpressure ' ...
        'drops while turbine outlet temperature and boost remain normal. Check for soot ' ...
        'deposits at suspected leak points.'])
};

% ---- Flag string logic ----
switch final_flag
    case 0
        flag_str = 'NO LEAK';
    case 1
        flag_str = '⚠ LEAK DETECTED';
    case 2
        flag_str = '◉ UNCERTAIN — MONITORING';
    otherwise
        flag_str = 'UNKNOWN';
end

% ---- Confidence string logic ----
if final_flag == 0
    confidence_str = 'N/A';
elseif final_flag == 1
    % ±2σ expressed as percentage (multiply sigma by 200 to get ±2σ%)
    confidence_str = sprintf('%.0f%% ± %.0f%%', confidence*100, confidence_sigma*200);
elseif final_flag == 2
    confidence_str = sprintf('%.0f%% (insufficient for alert)', confidence*100);
else
    confidence_str = 'N/A';
end

% ---- Location string logic ----
if final_flag == 0 || final_zone == 0
    location_str = 'None — no fault detected';
else
    location_str = zone_display_names{final_zone + 1};
end

% ---- Action string ----
action_str = actions{final_zone + 1};

% Append pending confirmation message if uncertain
if final_flag == 2
    action_str = sprintf(['%s | PENDING CONFIRMATION: Fault suspected in this zone but ' ...
        'persistence threshold not yet reached. Continue monitoring. If alert persists, ' ...
        'perform inspection.'], action_str);
end

end  % function assemble_output

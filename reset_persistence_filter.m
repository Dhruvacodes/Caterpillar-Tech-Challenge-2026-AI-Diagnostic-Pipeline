function reset_persistence_filter()
% ================================================================
% reset_persistence_filter.m
%
% Clears persistent state in persistence_filter.m
%
% Call this between simulation runs or when restarting monitoring.
%
% ================================================================

clear persistence_filter

fprintf('✓ Persistence filter state reset.\n');

end

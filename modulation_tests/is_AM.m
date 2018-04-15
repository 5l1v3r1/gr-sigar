%% Determines if a signal is AM (Returns 'true if it is)
function [AM_modulated, certainty] = is_AM(freqMax, freqVariance, IF)
% still needs work as it might not account for files with a single peak
% with noise around it
    
    %global freqMax
    chunkSize = fix(length(freqMax)/10);
    forLoopEnd=10;
    
    %if chunks are too small, just use the normal length of freqMax instead
    if chunkSize ==1
        chunkSize=length(freqMax);
        forLoopEnd=1;
    end
    
    isAM=0;
    for c=1:forLoopEnd 
        %valueVariance(index) = freqVariance 
        if var(freqMax(chunkSize*(c-1)+1:chunkSize*c)) < 10	%if the peak frequency doesn't change (much)
            if std(freqVariance(chunkSize*(c-1)+1:chunkSize*c))> 10 && std(freqVariance(chunkSize*(c-1)+1:chunkSize*c))< 200e3	%if around the peak, the variance of the signal changes, the signal is likely to be AM
                isAM=isAM+1;
            end
        end
    end
    certainty=isAM*10;
    if isAM>5           %<1 for testing det_modtype
        fprintf('Signal at %0.4f MHz is amplitude modulated with %0.2f %% certainty \n\n', IF/1e6, certainty)
        AM_modulated=true;
    else
        fprintf('Signal at %0.4f MHz is not amplitude modulated\n\n', IF/1e6)
        AM_modulated=false;
    end
end
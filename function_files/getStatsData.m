%% Measures basic statistical values for data contained in vector freqInfo
% and returns the frequency where the max value was found, the mean, the
% mode and the variance
% xAxis represents the frequency values
function [maximum, meanValue, modeValue, variance]=getStatsData(freqInfo, xAxis)
    maximum = xAxis(freqInfo == max(freqInfo(:))); %stores frequency where the max value was found
    if length(maximum)~=1
        %if maximum cannot be determined, the first xAxis value is chosen. This
        %is usually inconsequential and probably only happens at the end of a file.
        maximum=xAxis(1);
    end
    meanValue = mean(freqInfo); %this value is not being use as of right now
    modeValue = mode(freqInfo);
    variance =var(freqInfo);    %this value is not being use as of right now
end

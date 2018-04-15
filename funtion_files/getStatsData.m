%% Measures basic statistical values for data contained in vector freqInfo
% and returns the frequency where the max value was found, the mean, the
% mode and the variance
% xAxis represents the frequency values
function [maximum, meanValue, modeValue, variance]=getStatsData(freqInfo, xAxis)
    %maxIndex = find(freqInfo == max(freqInfo(:)));
    %maximum = xAxis(maxIndex);  %stores frequency where the max value was found

    %The below removes the warning about indexed variabels and is a little
    %faster. However; it may impact detection.
    maximum = xAxis(freqInfo == max(freqInfo(:)));
    meanValue = mean(freqInfo); %this value is not being use as of right now
    
    %****************************requires work*****************************
    modeValue = mode(freqInfo);
    variance =var(freqInfo);    %this value is not being use as of right now
end

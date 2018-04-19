%% frequency analysis***
function [freqMax, freqMean, freqMode, freqVariance, freqData] = freqAnalysis(data, Fs, IF)
    L=length(data);             %total number of samples recorded.
    %Is this needed?
    duration=L/Fs;              %determines the total duration of the signal in seconds
    w = 1000;                     %using an arbitrary window size for now. Line below will be used.
    %w=Fs/100;                   %window size for FFT equivalent to 1/100 second worth of samples
    x_Hz = (0:w-1)*(Fs/w)+IF;     %will need adjustment since the IF will be frequency that the local oscillator is set to, not the frequency detected
    k = fix(L/w);                %number of fft's that can be performed. This will be used for the 'for' loop
    %k =150;                    % setting the value to 150 temporarily...might cause errors
    %freqData=fft(data,w);       %stores frequency info for the values in the first window
    % calculates threshold
    % freqData= fft(data(Fs*25:end),w);
    % threshold = 1.5 * mean(abs(freqData));  %sets the threshold to 1.5 times the value of the overall mean
    % clear freqData'
    threshold = 0.6;  % the lines above have an error for the threshold. Not being used yet. will be used for signal detection
    
    % these vectors will store the statisical values of the FFT's for signal
    % evaluation
    freqMax=zeros(k,1);
    freqMean=zeros(k,1);
    freqMode=zeros(k,1);
    freqVariance=zeros(k,1);
    for c=1:k % Runs the FFT analysys and stores stats values in the vectors defined above
        %freqData= fft(data((c*w):end),w);
        freqData= fftshift(fft(data((c*w):end),w));
        
        % ****uncomment from here when plots are needed****************
        diagnostic_plots(data, freqData, c, k, w, x_Hz, Fs)
        % ****uncomment until here when plots are not needed****************

        %plot(x_Hz2,abs(freqData2))
        [freqMax(c), freqMean(c), freqMode(c), freqVariance(c)]=getStatsData(freqData, x_Hz);
    end
end
%% This algorithm will evaluate the modulation type of a signal captures
% Assumptions: the data obtained contains only one usable signal. No signal
% discrimination has been implemented yet.

%% Obtains data from file
% gets data from the binary file created by gr-scan
% ****add algorithm that looks thtough a folder and pulls data one file at
% time. This will eventually call the function that will do the frequency
% analysis, and write the type of modulation to the .csv file that was
% created when gr-scan was used.

% ***Basic structure of future loop
% for x many files in the folder
%     get I/Q data (see get data area below)
%     calls the frequency analysis function(it will return modulation type)
%     stores data in the .csv file next to its corresponding entry
% end

% gets I/Q data
[FileName,PathName,FilterIndex] = uigetfile('.bin');
%FileName = 'Random_music.bin';
%PathName = 'C:\Users\Guillo\OneDrive\Documents\School Stuff\Spring-18 Classes\EEE489-Senior Year Project\Files\Test Signals\';

[data, Fs, IF]=GetBinData(PathName, FileName);%gets I/Q data,sample frequency, and IF

%[data, Fs, IF]=GetBinData('C:\Users\Guillo\OneDrive\Documents\School Stuff\Spring-18 Classes\EEE489-Senior Year Project\Files\Test Signals\Random_music.bin');%gets I/Q data,sample frequency, and IF
L=length(data);             %total number of samples recorded.
duration=L/Fs;              %determines the total duration of the signal in seconds

%% frequency analysis*** 
% this area will be a function that will return modulation type

w = 1000;                     %using an arbitrary window size for now. Line below will be used.                    
%w=Fs/100;                   %window size for FFT equivalent to 1/100 second worth of samples
x_Hz = (0:w-1)*(Fs/w)+IF;     %will need adjustment since the IF will be frequency that the local oscillator is set to, not the frequency detected
k = fix(L/w);                %number of fft's that can be performed. This will be used for the 'for' loop
%k = 150;                    % setting the value to 150 temporarily...might cause errors
%freqData=fft(data,w);       %stores frequency info for the values in the first window

% calculates threshold
% freqData= fft(data(Fs*25:end),w);
% threshold = 1.5 * mean(abs(freqData));  %sets the threshold to 1.5 times the value of the overall mean
% clear freqData'
threshold = 0.6;  % the lines above have an error for the threshold. Not being used yet. will be used for signal detection

set(gca,'YScale','log')

% these vectors will store the statisical values of the FFT's for signal
% evaluation
freqMax=zeros(k,1);       
freqMean=zeros(k,1);
freqMode=zeros(k,1);
freqVariance=zeros(k,1);

for c=1:k % Runs the FFT analysys and stores stats values in the vectors defined above
  
   freqData= fft(data((c*w):end),w);
   
   % ****uncomment from here when plots are needed****************
    subplot(3,1,1)
   plot(x_Hz,abs(freqData))
   title("Signal's FFT")
   %data for time domain plot
   subplot(3,1,2)
   timedata = (data(w*(c-1)+1:w*c));
   x = (1:1:w)*(c/Fs);
   plot(x,abs(timedata), x, imag(timedata), x, real(timedata))
   title("Signal in time domain")
   
   subplot(3,1,3)
   if c>15
       hold on
   else
       hold off
   end
   plot(timedata)
   title("Signal I/Q components")
   pause
   % ****uncomment until here when plots are not needed****************
   
   indices=find(abs(freqData)>threshold);
   freqData2=freqData(indices);
   x_Hz2=x_Hz(indices);
   %plot(x_Hz2,abs(freqData2))
   
   [freqMax(c), freqMean(c), freqMode(c), freqVariance(c)]=getStatsData(freqData, x_Hz);
   %these 3 lines below allow us to use the data without the lower values
   %if isempty(freqData2)==0
   %     [freqMax(c), freqMean(c), freqMode(c), freqVariance(c)]=getStatsData(freqData2, x_Hz2);
   %end
   %plot(x_Hz(1:300),abs(freqData(1:300)),'b')
end

%% Evaluates Frequency modulation results 
% it measures the standard deviation of the max values obtain above. 
% if the standard deviation is greated than 20kHz (set arbitrarily due to
% the audio frequency limt), then the algorithm estimates that the signal 
% is FM. **Needs to use other parameters to confirm (Mean, Mode, etc)**
% This is a temporary solution and the real modulation detection will use
% the ratio (R) of the variance of the envelope ot the square of the mean
% of the envelope. See Identification of the Modulation Type of a Signal by
% Y. T. Chann
if std(freqMax)>200 * std(freqMax)<200
    %msgbox('Signal is frequency modulated')
    disp('Signal is frequency modulated')
else
    disp('Signal is not frequency modulated')
end

%% Measures basic statistical values for data contained in vector freqInfo 
% and returns the frequency where the max value was found, the mean, the 
% mode and the variance
% xAxis represents the frequency values
function [maximum, meanValue, modeValue, variance]=getStatsData(freqInfo, xAxis)
    maxIndex = find(freqInfo == max(freqInfo(:)));
    maximum = xAxis(maxIndex);  %stores frequency where the max value was found
    meanValue = mean(freqInfo); %this value is not being use as of right now
    modeValue = 0;              %requires work
    variance =var(freqInfo);    %this value is not being use as of right now
end 

%% Will be used for signal detection (backup to gr-scan)
% AvgfreqData=freqData;
% for counter=2:k %Averages 30 FFT(w) samples
%     AvgfreqData= AvgfreqData + fft(data((1:w+1)+(w*counter)),w);
%     TempFreqData=AvgfreqData/counter;
%     plot(x_Hz(2:end),abs(TempFreqData(2:end)))
%     pause
% end    

%% This function takes as an input a binary file that contains I/Q data and 
% returns the data in complex form. It also returns sample rate (Fs) and
% Intermediate frequency IF (frequency that LO was set when data was
% captured) *****It still requires the changes that Hunter made to extract
% the LO freq, the sampling rate (Fs) from the file name
function [data, Fs, IF]=GetBinData(filePath, fileName)
    fileID=fopen([filePath, fileName], 'r');
    data = fread(fileID,'float32');
    data = data(1:2:end) +1i*data(2:2:end); %represents data as f=I+jQ 
    fclose(fileID);
    
    % Extracts data from file name
    try
        info=strsplit(fileName, {'-', '_'});
        Fs=2*str2double(info{2})*1e3; %Hz
        IF=str2double(info{1})*1e6; %add code to obtain IF that receiver is tuned to
    catch
        Fs = 820e3; %Hz. For testing purposes with the music.bin file
    	IF = 76.5e6; % For testing purposes with the music.bin file
    end
    if isnan(Fs)
        Fs = 820e3; %Hz. For testing purposes with the music.bin file
        IF = 76.5e6; % For testing purposes with the music.bin file
    end
    %Eliminates the DC component using the mean value
    data = data-mean(data);
    
end


% gets data from the binary file created by GNU radio design
%****add algorithm that looks thtough a folder and pulls data one file at a
%time
[file_name, path_name, filter_index] =uigetfile('./bin_files/*.bin', 'Select I/Q binary file');
[data,Fs,IF]=GetBinData(path_name, file_name); %gets I/Q data,sample frequency, and IF
n=length(data); %total number of samples recorded
w=1024;         %window size for FFT and frequency determination
%***frequency analysis***

%Determines indices for x axis in frequency (creates a vector same lenght
%as the FFT window and centers it around the IF, then normalizes it to
%match the bandwidth
x_Hz=(0:w-1)*(Fs/w)+IF;  
%x_Hz=((0:1/w:1-(1/w))*Fs).';  
k=fix(n/w); %number of fft's that can be performed

freqData=fft(data,w);
AvgfreqData=freqData;
for counter=2:30 %Averages 30 FFT(w) samples
    AvgfreqData= AvgfreqData + fft(data((1:w+1)+(w*counter)),w);
    TempFreqData=AvgfreqData/counter;
    plot(x_Hz,abs(TempFreqData))
    grid on
    %pause
end    

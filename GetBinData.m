function [f, Fs, IF]=GetBinData(filePath, fileName)
info=strsplit(fileName, {'-', '_'});
fileID=fopen([filePath, fileName], 'r');
f=fread(fileID,'float32');
%f=f-127.5; %to get from the unsigned (0 to 255) range we need to subtract 127.5 from each I and Q value, which results in a new range from -127.5 to +127.5
f=f(1:2:end) +1i*f(2:2:end); %represents data as f=I+jQ 
fclose(fileID);
Fs=2*str2double(info{2})*1e3; %Hz
N=length(f);
IF=str2double(info{1})*1e6; %add code to obtain IF that receiver is tuned to
x_Hz=[0:N-1]*Fs/N; %Returns the indices for the frequency x axis
end
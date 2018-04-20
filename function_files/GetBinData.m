%% This function takes as an input a binary file that contains I/Q data and
% returns the data in complex form. It also returns sample rate (Fs) and
% Intermediate frequency IF (frequency that LO was set when data was
% captured) *****It still requires the changes that Hunter made to extract
% the LO freq, the sampling rate (Fs) from the file name
function [data, Fs, IF, soi_data, csv_file]=GetBinData(filePath, fileName, soi_data, csv_file)
    fileID=fopen([filePath, fileName], 'r');
    data = fread(fileID,'float32');
    data = data(1:2:end) +1i*data(2:2:end); %represents data as f=I+jQ
    fclose(fileID);

    % Extracts data from file name
    
    %*********************Normalize Fs and IF Values***********************
    try
        info=strsplit(fileName, {'-', '_'});
        Fs=2*str2double(info{2})*1e3; %Hz
        IF=str2double(info{1})*1e6;   %Hz
    catch
        %Get user input for frequency and sampling rate if it cannot be
        %determined.
        recording_info=inputdlg({'Please specify an intermediate frequency (MHz)';'Please specify the sampling rate (kHz)'}, 'Signal recording info');
        IF=str2double(recording_info{1})*1e6;   %Hz
        Fs=str2double(recording_info{2})*1e6;   %Hz
    end
    if isnan(Fs)
        %Get user input for frequency and sampling rate if it cannot be
        %determined.
        recording_info=inputdlg({'Please specify an intermediate frequency MHz)';'Please specify the sampling rate (kHz)'}, 'Signal recording info');
        IF=str2double(recording_info{1})*1e6;   %Hz
        Fs=str2double(recording_info{2})*1e6;   %Hz
    end
    %Eliminates the DC component using the mean value
    data = data-mean(data);

    %If the csv_file was the alternate file, append signal info to soi_data
    if strcmp(csv_file, 'csv_files/orphan_files.csv')
        if strcmp(soi_data{height(soi_data),1},'')
            use_row=1;
        else
            use_row=height(soi_data)+1;
        end
        soi_data(use_row,:)={datestr(now, 'yyyyMMdd_HHmmss') IF/1e6 Fs/1e3 0 0 [filePath,fileName] 'unk' 0};
    end
end
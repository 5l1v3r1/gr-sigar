%% This algorithm will evaluate the modulation type of a signal captures
% Assumptions: the data obtained contains only one usable signal. No signal
% discrimination has been implemented yet.
clear

%% Initial user input
init_prompt = ['What do you want to do?\n\n'...
        'gr-scan:       Run gr-scan\n'...
        'analysis:      Search for bin/dat file(s) to analyze\n'...
        'exit\n> '];
 
 global soi_data;
 global csv_file;
 global freqData;
 global freqMax;    %added in order to evaluate data after frequency analysis is completed
 
 mod_type={};
 freqData=[];
 freqMax=[];
 %gr-scan variable options
 %'CSV output file name; no extension (required)'
 gr_prompt = {'FFT samples to average (default: 1000)'
 'Course bandwidth in kHz (default: fine bandwidth * 8)'
        'Fine bandwidth in kHz (default: 25)'
        'Time to scan each freq in seconds (default: 1)'
        'Sample rate in MSamples/s (default: 2)'
        'Minimum spacing between signals in kHz (default: 50'
        'Threshold in dB (default: 3)'
        'FFT width (default: 1000)'
        'Start frequency in MHz (default: 87)'
        'End frequency in MHz (default: 108)'
        'Frequency step in MHz (default: sample rate / 4)'};
 gr_flags = {' -a ', ' -c ', ' -f ', ' -p ', ' -r ', ' -s ', ' -t ', ' -w ', ' -x ', ' -y ', ' -z '};
 out_filename=[];
 title = 'gr-scan options (leave blank for defaults)';
 %Dimension for text boxes
 dims = [1 65];
 
while true
    %Get user input for what to do
    usr_in=input(init_prompt, 's');
    switch usr_in
        case 'gr-scan'
            gr_vars=inputdlg(gr_prompt, title, dims);
            
            %Cancel button clicked: skip to next loop iteration
            if isempty(gr_vars)
                continue
            end
            
            %Use loop to check value validity and build commad options
            i = 1;
            %A while loop was selected so that the loop could be reset and 
            %the dialog could be recalled with the current user values.
            while i < length(gr_flags)+1
                %If the user hits cancel after an error, gr_vars will be
                %0x0 and breaks everything, so we break this loop
                if isempty(gr_vars)
                    break
                end
                %str2double doesn't return a status code
                [num, stat] = str2num(gr_vars{i}); %#ok<ST2NM>
                
                %If number conversion fails, we aren't checking the
                %filename, and the field isn't blank
                if (stat == 0) && (gr_vars{i} ~= "")
                    waitfor(msgbox('All values except the filename must be valid numbers', 'Invalid values', 'error', 'modal'));
                    %Restart loop for checking values
                    i = 1;
                    %calls a new input dialog, passing the current user
                    %defined values as the default values
                    gr_vars=inputdlg(gr_prompt, 'gr-scan options', dims, gr_vars);
                else
                    %Value is ok enough
                    i = i+1;
                end
            end
            %This must be checked again because only the while loop was
            %broken if this condition was previously met and we need to exit
            %the switch too
            if isempty(gr_vars)
                continue
            end
            
            options=[];
            %Create options string for calling gr-scan with specified
            %parameters
            for i=1:length(gr_flags)
                switch gr_vars{i}
                    case ""             %Ignore if field was left blank
                        continue
                    otherwise           %Add flag and value to options string
                        out_filename = [out_filename, strtrim(gr_flags{i}), gr_vars{i}]; %#ok<AGROW>
                        options = [options, gr_flags{i}, gr_vars{i}]; %#ok<AGROW>
                end 
            end
            
            %create final command
            if isempty(out_filename)
                out_filename = '.csv';
            end
            %Add file checking
            command=['./gr-scan ', options, ' -o ', out_filename(2:end), '.csv'];
            
            %status could be used to tell if gr-scan breaks or not, but
            %gr-scan cannot be closed cleanly. 
            [status, cmdout] = unix(command, '-echo');
            %[status, cmdout] = system(['echo ',command], '-echo');  %Demo for windows
 
        case 'analysis'
            %specify file(s) to analyze
            %*******************************Add error handling in case this fails*******************************
            [modType, int_freq] = analyzeFile;

         
        case 'exit'
            %exit is the only command that actually brreaks the input loop
            break
            
        otherwise
            %Handling for unkown options
            fprintf('\nCommand not recognized!\n\n')
    end
    
    %Write to file one time
    rec_mod_type(det_modtype(modType), int_freq);
    writetable(soi_data, csv_file,'QuoteStrings',true);
end

%% Determine mod type (protoytype)
function [mt]=det_modtype(mod_FM)
    
    if mod_FM==true
        mt={'FM'};
    else
        mt={'Not FM'};
    end
end

%% Let user pick files (a funtion called get_file should not return a modulation type)
function [mod_FM, IF] = analyzeFile %Changed name to match its function//GS
    % Obtains data from file
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
    
    global soi_data;
    global csv_file;

    [FileName,PathName] = uigetfile('*.bin; *.dat', 'Select one or more files', 'MultiSelect', 'on');
    
    if iscellstr(FileName) || ischar(FileName)
        wrk_dir=strsplit(PathName, filesep);                                            %Split the directory for the selected file(s)
        run_info = {wrk_dir(length(wrk_dir)-2), wrk_dir(length(wrk_dir)-1)};            %Pull run date and time (unique to each run)
        wrk_dir(length(wrk_dir)-3:length(wrk_dir))=[];                                  %Clear the path name back to gr-scan directory
        csv_path = sprintf('%s%scsv_files%s%s-%s*.csv', strjoin(wrk_dir, filesep) ...
            , filesep, filesep, char(run_info{1}), ...
            char(run_info{2}));                                                         %Create a search path with a wildcard
        csv = dir(csv_path);                                                            %Get CSV that corresponds to the bin file's run
        csv_file=strjoin({csv.folder, csv.name}, filesep);
        soi_data=readtable(csv_file);         %Create a table with csv file info
    else
        return
    end
    
    %FileName = 0 if user hits cancel
    %Easier to determine type in two different cases as opposed to forcing
    %FileName to be a cell
    if iscellstr(FileName)
        %If FileName is a cell string, iterate through indexes for analysis
        for i=1:numel(FileName)
            [data, Fs, IF]=GetBinData(PathName, FileName{i}); %gets I/Q data,sample frequency, and IF
            mod_FM = is_FM(data, Fs, IF);
            %Create a new figure for next interation
            if i~= numel(FileName)
                figure
            end
        end
    elseif ischar(FileName)
        %Only one file was chosen, no loop required
        [data, Fs, IF]=GetBinData(PathName, FileName);
        mod_FM = is_FM(data, Fs, IF, FileName);
    end
    
    % Add opening CSV; file will need to be imported. CSV
    % file saving should include directory info so that choosing a random
    % bin file will import the appropriate CSV file for saving.
    
    %[data, Fs, IF]=GetBinData('C:\Users\Guillo\OneDrive\Documents\School Stuff\Spring-18 Classes\EEE489-Senior Year Project\Files\Test Signals\Random_music.bin');%gets I/Q data,sample frequency, and IF

end

%% frequency analysis***
function [mod_type] = freqAnalysis(data, Fs, IF, FileName) 
    % this area will be a function that will return modulation type
   
    global freqData;
    global freqMax; 
    
    L=length(data);             %total number of samples recorded.
    
    %Is this needed?
    duration=L/Fs;              %determines the total duration of the signal in seconds

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
%         subplot(3,1,1)
%         plot(x_Hz,abs(freqData))
%         title("Signal's FFT. " + c + " out of " + k)
%         %data for time domain plot
%         subplot(3,1,2)
%         timedata = (data(w*(c-1)+1:w*c));
%         x = (1:1:w)*(c/Fs);
%         plot(x,abs(timedata), x, imag(timedata), x, real(timedata))
%         title("Signal in time domain")
%    
%         subplot(3,1,3)
%         plot(timedata)
%         title("Signal I/Q components")
%         pause
        % ****uncomment until here when plots are not needed****************
   
        indices=find(abs(freqData)>threshold);
        
        %Are these required?
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

    % Evaluates Frequency modulation results 
    % it measures the standard deviation of the max values obtain above. 
    % if the standard deviation is greated than 20kHz (set arbitrarily due to
    % the audio frequency limt), then the algorithm estimates that the signal 
    % is FM. **Needs to use other parameters to confirm (Mean, Mode, etc)**
    % This is a temporary solution and the real modulation detection will use
    % the ratio (R) of the variance of the envelope ot the square of the mean
    % of the envelope. See Identification of the Modulation Type of a Signal by
    % Y. T. Chann
    
    % the following for loop evaluates the standard deviation of the
    % frequency where the max value over 10 different sections of the
    % signal. If the majority of the results concur (5 or more), then, the
    % script will return a positive for Freq modulation
    chunkSize = fix(length(freqMax)/10);
    isFM=0;
    for c= 1:10
        stdValue = std(freqMax(chunkSize*(c-1)+1:chunkSize*c)); 
        if (stdValue>20 && stdValue<20e3)	%Common audio frequencies vary between 20Hz to 20kHz
            isFM=isFM+1;
        end 
    end
    if isFM>5           % if > 5 out of 10 freqMax sections meet the variation rqmnt, signal is FM 
        fprintf('Signal at %0.4f MHz is frequency modulated with %0.2f %% certainty \n\n', IF/1e6, isFM*10)
        mod_type=true;
    else
        fprintf('Signal at %0.4f MHz is not frequency modulated\n\n', IF/1e6)
        mod_type=false;
    end
    
%     if std(freqMax)>20 * std(freqMax)<20e3      %Common audio frequencies vary between 20Hz to 20kHz
%         %msgbox('Signal is frequency modulated')
%         
%         %make sure the units work.
%         fprintf('Signal at %0.4f MHz is frequency modulated\n\n', IF/1e6)
%         mod_type=true;
%     else
%         fprintf('Signal at %0.4f MHz is not frequency modulated\n\n', IF/1e6)
%         mod_type=false;
%     end
end


%% frequency analysis***
function [mod_type] = is_FM(data, Fs, IF, FileName) 
    % this area will be a function that will return modulation type
   
    global freqData;
    global freqMax; 
    
    L=length(data);             %total number of samples recorded.
    
    %Is this needed?
    duration=L/Fs;              %determines the total duration of the signal in seconds

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
%         subplot(3,1,1)
%         plot(x_Hz,abs(freqData))
%         title("Signal's FFT. " + c + " out of " + k)
%         %data for time domain plot
%         subplot(3,1,2)
%         timedata = (data(w*(c-1)+1:w*c));
%         x = (1:1:w)*(c/Fs);
%         plot(x,abs(timedata), x, imag(timedata), x, real(timedata))
%         title("Signal in time domain")
%    
%         subplot(3,1,3)
%         plot(timedata)
%         title("Signal I/Q components")
%         pause
        % ****uncomment until here when plots are not needed****************
   
        indices=find(abs(freqData)>threshold);
        
        %Are these required?
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

    % Evaluates Frequency modulation results 
    % it measures the standard deviation of the max values obtain above. 
    % if the standard deviation is greated than 20kHz (set arbitrarily due to
    % the audio frequency limt), then the algorithm estimates that the signal 
    % is FM. **Needs to use other parameters to confirm (Mean, Mode, etc)**
    % This is a temporary solution and the real modulation detection will use
    % the ratio (R) of the variance of the envelope ot the square of the mean
    % of the envelope. See Identification of the Modulation Type of a Signal by
    % Y. T. Chann
    
    % the following for loop evaluates the standard deviation of the
    % frequency where the max value over 10 different sections of the
    % signal. If the majority of the results concur (5 or more), then, the
    % script will return a positive for Freq modulation
    chunkSize = fix(length(freqMax)/10);
    isFM=0;
    for c= 1:10
        stdValue = std(freqMax(chunkSize*(c-1)+1:chunkSize*c)); 
        if (stdValue>20 && stdValue<20e3)	%Common audio frequencies vary between 20Hz to 20kHz
            isFM=isFM+1;
        end 
    end
    if isFM>5           % if > 5 out of 10 freqMax sections meet the variation rqmnt, signal is FM 
        fprintf('Signal at %0.4f MHz is frequency modulated with %0.2f %% certainty \n\n', IF/1e6, isFM*10)
        mod_type=true;
    else
        fprintf('Signal at %0.4f MHz is not frequency modulated\n\n', IF/1e6)
        mod_type=false;
    end
    
%     if std(freqMax)>20 * std(freqMax)<20e3      %Common audio frequencies vary between 20Hz to 20kHz
%         %msgbox('Signal is frequency modulated')
%         
%         %make sure the units work.
%         fprintf('Signal at %0.4f MHz is frequency modulated\n\n', IF/1e6)
%         mod_type=true;
%     else
%         fprintf('Signal at %0.4f MHz is not frequency modulated\n\n', IF/1e6)
%         mod_type=false;
%     end
end


function rec_mod_type(mod_type, IF)
    global soi_data
    
     % Find index of current freq
    soi_index=(soi_data.frequency_mhz==IF/1e6);

    % Add entry for determined mod type
    soi_data.mod_type{soi_index} = mod_type;
end

%% Determines whether a signal is AM
 % needs to run after is_FM because it uses vector freqMax 
function [mod_type] = is_AM(data, Fs, IF, FileName) 
    for c= 1:10
        stdValue = std(freqMax(chunkSize*(c-1)+1:chunkSize*c)); 
        if (stdValue>20 && stdValue<20e3)	%Common audio frequencies vary between 20Hz to 20kHz
            isFM=isFM+1;
        end 
    end
    if isFM>5           % if > 5 out of 10 freqMax sections meet the variation rqmnt, signal is FM 
        fprintf('Signal at %0.4f MHz is frequency modulated with %0.2f %% certainty \n\n', IF/1e6, isFM*10)
        mod_type=true;
    else
        fprintf('Signal at %0.4f MHz is not frequency modulated\n\n', IF/1e6)
        mod_type=false;
    end

end

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
    modeValue = 0;              %requires work
    variance =var(freqInfo);    %this value is not being use as of right now
end 

%% Will be used for signal detection (backup to gr-scan)
% Use this average to determine how many signals are present in the bin
% data and separate them correspondingly (use windows to blank out the rest
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

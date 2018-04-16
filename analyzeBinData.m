%% This algorithm will evaluate the modulation type of a signal captures
% Assumptions: the data obtained contains only one usable signal. No signal
% discrimination has been implemented yet.
clear

%% Initial user input
init_prompt = ['What do you want to do?\n\n'...
        '0:    Run gr-scan\n'...
        '1:    Search for bin/dat file(s) to analyze\n'...
        '2:    Exit\n> '];

 global soi_data csv_file freqData
 mod_indication={};
 freqData=[];
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
    %Get user input for what to do next
    usr_in=input(init_prompt, 's');
    switch usr_in
        case '0'
            if filesep~='/'
                fprintf('\ngr-scan cannot be run on windows.\n\n')
                continue
            end
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
        case '1'
            %specify file(s) to analyze
            %*******************************Add error handling in case this fails*******************************
            [mod_indication, int_freq] = evaluateSignal;
        case '2'
            %exit is the only command that actually brreaks the input loop
            break

        otherwise
            %Handling for unkown options
            fprintf('\nCommand not recognized!\n\n')
    end

    %Write to file, unless no file was selected
    if ~isempty(mod_indication) && ~isempty(int_freq)
        writetable(soi_data, csv_file,'QuoteStrings',true);
    end
end

%% Let user pick files, calls frequency analysis function (which determines mod type)
function [mod_info, IF] = evaluateSignal
    % Obtains data from file
    % gets data from the binary file(s) created by gr-scan and determines
    % modulation type

    global soi_data  csv_file

    [FileName,PathName] = uigetfile('*.bin; *.dat', 'Select one or more files', 'MultiSelect', 'on');

    if iscell(FileName) || ischar(FileName)
        wrk_dir=strsplit(PathName, filesep);                                            %Split the directory for the selected file(s)
        run_info = {wrk_dir(length(wrk_dir)-2), wrk_dir(length(wrk_dir)-1)};            %Pull run date and time (unique to each run)
        wrk_dir(length(wrk_dir)-3:length(wrk_dir))=[];                                  %Clear the path name back to gr-scan directory
        csv_path = sprintf('%s%scsv_files%s%s-%s*.csv', strjoin(wrk_dir, filesep) ...
            , filesep, filesep, char(run_info{1}), ...
            char(run_info{2}));                                                         %Create a search path with a wildcard
        csv = dir(csv_path);                                                            %Get CSV that corresponds to the bin file's run
        csv_file=strjoin({csv.folder, csv.name}, filesep);
        alt_csv=sprintf('csv_files/orphan_files.csv');                                  %CSV file for orphan signal files
        if ~exist('csv_files', 'dir')                                                   %Create csv_files directory if necessary
            mkdir csv_files;
        end
        %Check existance of corresponding CSV file
        if exist(csv_file, 'file') == 2
            %Create a table with csv file info
            soi_data=readtable(csv_file);
        %If no CSV file was found, check for alt_csv
        elseif exist(alt_csv, 'file') == 2
            %Define csv_file as alt_csv
            csv_file=alt_csv;
            %Read from alt_csv
            soi_data=readtable(csv_file);
        %If no csv file is found, make an empty soi_data to write to
        %alt_csv later
        else                                               
            csv_file=alt_csv;
            %variable names
            headers = {'time' 'frequency_mhz' 'width_khz' 'peak' 'dif' 'filename' 'mod_type' 'certainty'};
            %a cell array with numbertts to force matlab to allow numeric
            %values in appropriate columns
            data={'' 0 0 0 0 '' '' 0};
            %Create table and assign column headers
            soi_data=cell2table(data);
            soi_data.Properties.VariableNames = headers;
        end
        
    else
        %Handle if user hit cancel
        mod_info = [];
        IF = [];
        return
    end

    %Force FileName to be a cellstring because uigetfile will return a
    %char string for one file and a cell string for multiple files. Forcing
    %it to alwayus be a cell string makes logic easier to manage.
    FileName=cellstr(FileName);
    for i=1:numel(FileName) 
        [data, Fs, IF]=GetBinData(PathName, FileName{i}); %gets I/Q data,sample frequency, and IF

        [freqMax, freqMean, freqMode, freqVariance]=freqAnalysis(data, Fs, IF); %#ok<ASGLU> performs FFT analysis and returns vectors with statistical values

        [mod_FM, cert_FM] = is_FM(freqMax, IF); % returns True if signal is FM and within a percentage range of certainty
        [mod_AM, cert_AM] = is_AM(freqMax, freqVariance, IF);

        analysis_results = {'FM' mod_FM cert_FM;...
                            'AM' mod_AM cert_AM};

        %Determine modulation type
        mod_info=det_modtype(analysis_results);
        %Record modulation type into soi_data table
        rec_mod_type(mod_info, IF);

        % ** if mod_FM == false then
        % **    mod_AM = is_AM(freqMax, freqMaxValue)
    end
end

%% Determine mod type (protoytype)
function [mt]=det_modtype(analysis_results)
    
    %Find maximum percentage of certainty 
    [highest_certainty, row] = max([analysis_results{:,3}]);
    %Create an empty array to hold certainty percentages for comparison
    hit=[];

    %The below loop checks for any hits that match the highest hit value
    %above. If there is more than one hit for the highest certainty, or no
    %hits above 50, then the signal is ambiguous.
    
    %If the highest certanty is greater than 50%
    if highest_certainty > 50
        %for every row in mod_ind
        for i=1:size(analysis_results,1)
            %if that determination was equal to the highest certainty
            if analysis_results{i,3} == highest_certainty
                %record the hit
                hit=[hit analysis_results{i,3}]; %#ok<AGROW>
            end
        end

        %If there was only one hit
        if length(hit)==1
            %Use corresponding determination {Modulation type, certainty precentage}
            mt={analysis_results{row,1}, analysis_results{row, 3}};
        else
            %Otherwise, signal is ambiguous
            mt={'Unk', 0};
        end
    else
        %Otherwise, signal is ambiguous
        mt={'Unk',0};
    end
    
%     if mod_FM==true
%         mt={'FM'};
%     else
%         mt={'Not FM'};
%     end
end

%% frequency analysis***
function [freqMax, freqMean, freqMode, freqVariance] = freqAnalysis(data, Fs, IF)

    global freqData
    L=length(data);             %total number of samples recorded.
    %Is this needed?
    duration=L/Fs;              %determines the total duration of the signal in seconds
    w = 1000;                     %using an arbitrary window size for now. Line below will be used.
    %w=Fs/100;                   %window size for FFT equivalent to 1/100 second worth of samples
    x_Hz = (0:w-1)*(Fs/w)+IF;     %will need adjustment since the IF will be frequency that the local oscillator is set to, not the frequency detected
    %k = fix(L/w);                %number of fft's that can be performed. This will be used for the 'for' loop
    k =150;                    % setting the value to 150 temporarily...might cause errors
    %freqData=fft(data,w);       %stores frequency info for the values in the first window
    % calculates threshold
    % freqData= fft(data(Fs*25:end),w);
    % threshold = 1.5 * mean(abs(freqData));  %sets the threshold to 1.5 times the value of the overall mean
    % clear freqData'
    threshold = 0.6;  % the lines above have an error for the threshold. Not being used yet. will be used for signal detection
    
    %figure
    %set(gca,'YScale','log')
    
    % these vectors will store the statisical values of the FFT's for signal
    % evaluation
    freqMax=zeros(k,1);
    freqMean=zeros(k,1);
    freqMode=zeros(k,1);
    freqVariance=zeros(k,1);
    tic
    for c=1:k % Runs the FFT analysys and stores stats values in the vectors defined above
        %freqData= fft(data((c*w):end),w);
        freqData= fftshift(fft(data((c*w):end),w));
        
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
        plot(timedata, '*')
        title("Signal I/Q components")
        %pause
        % ****uncomment until here when plots are not needed****************

        %plot(x_Hz2,abs(freqData2))
        [freqMax(c), freqMean(c), freqMode(c), freqVariance(c)]=getStatsData(freqData, x_Hz);
    end
toc
end
%% Determines if a sighnal is frequency modulated***
function [FM_modulated, certainty] = is_FM(vector_maxFreq, IF)
    %global freqMax   
    chunkSize = fix(length(vector_maxFreq)/10);
    forLoopEnd=10;
    
    %if chunks are too small, just use the normal length of freqMax instead
    if chunkSize ==1
        chunkSize=length(vector_maxFreq);%freqMax);
        forLoopEnd=1;
    end
    isFM=0;
    for c= 1:forLoopEnd
        stdValue = std(vector_maxFreq(chunkSize*(c-1)+1:chunkSize*c)); 
        if (stdValue>20 && stdValue<20e3)	%Common audio frequencies vary between 20Hz to 20kHz
            isFM=isFM+1;
        end 
    end
    
    certainty=isFM*10;
    
    if isFM>5           % if > 5 out of 10 freqMax sections meet the variation rqmnt, signal is FM 
        fprintf('Signal at %0.4f MHz is frequency modulated with %0.2f %% certainty \n\n', IF/1e6, certainty)
        FM_modulated=true;
    else
        fprintf('Signal at %0.4f MHz is not frequency modulated\n\n', IF/1e6)
        FM_modulated=false;
    end
end

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

%% I'm not sure what this is for
%It's a seperate function for entering the mod type into the data table.
function rec_mod_type(mod_type, IF)
    global soi_data csv_file

    % Find index of current freq
    if strcmp(csv_file, 'csv_files/orphan_files.csv')
        soi_index=height(soi_data);
    else  
        soi_index=(soi_data.frequency_mhz==IF/1e6);
    end

    %Separated for clarity
    % Add entry for determined mod type
    soi_data.mod_type{soi_index} = mod_type{1};
    %Add entry for certainty; values of type double must be referenced by position
    soi_data{soi_index, 8} = mod_type{2};
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
    modeValue = mode(freqInfo);              %requires work
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
    global soi_data csv_file
    %global csv_file
    fileID=fopen([filePath, fileName], 'r');
    data = fread(fileID,'float32');
    data = data(1:2:end) +1i*data(2:2:end); %represents data as f=I+jQ
    fclose(fileID);

    % Extracts data from file name
    
    %*********************Normalize Fs and IF Values***********************
    
    try
        info=strsplit(fileName, {'-', '_'});
        Fs=2*str2double(info{2})*1e3; %Hz
        IF=str2double(info{1})*1e6; %add code to obtain IF that receiver is tuned to
    catch
        Fs = 820e3; %Hz. For testing purposes with the music.bin file
    	IF = 0; % For testing purposes with the music.bin file
    end
    if isnan(Fs)
        Fs = 820e3; %Hz. For testing purposes with the music.bin file
        IF = 0; % For testing purposes with the music.bin file
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
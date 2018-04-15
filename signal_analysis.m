%% This algorithm will evaluate the modulation type of a signal captures
% Assumptions: the data obtained contains only one usable signal. No signal
% discrimination has been implemented yet.
clear
addpath(genpath('.'))
%% Initial user input
init_prompt = ['What do you want to do?\n\n'...
        '0:    Run gr-scan\n'...
        '1:    Search for bin/dat file(s) to analyze\n'...
        '2:    Exit\n> '];
    
 mod_indication={};
 
 %gr-scan variable options
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
            [mod_indication, int_freq, soi_data, csv_file, freqData] = evaluateSignal;
        case '2'
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
function [mod_info, IF, soi_data, csv_file, freqData] = evaluateSignal
    % Obtains data from file
    % gets data from the binary file(s) created by gr-scan and determines
    % modulation type

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
            %data is a cell array with numbers to force matlab to allow numeric
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
    %it to always be a cell string makes logic easier to manage.
    FileName=cellstr(FileName);
    for i=1:numel(FileName)
        [data, Fs, IF, soi_data, csv_file]=GetBinData(PathName, FileName{i}, soi_data, csv_file); %gets I/Q data,sample frequency, and IF
        
        tic
        [freqMax, freqMean, freqMode, freqVariance, freqData]=freqAnalysis(data, Fs, IF); %#ok<ASGLU> performs FFT analysis and returns vectors with statistical values
        
        %**************needs work*****************
        %**  [freqMax,freqMean, freqMode,freqVariance]=freqAnalysis(data, Fs, IF)
        %**  mod_FM = is_FM(freqMax, IF); Change line below to this
        %**  [freqMax,freqMean, freqMode,freqVariance]=freqAnalysis(data, Fs, IF)

        [mod_FM, cert_FM] = is_FM(freqMax, IF); % returns True if signal is FM and within a percentage range of certainty
        [mod_AM, cert_AM] = is_AM(freqMax, freqVariance, IF);
        toc
        
        analysis_results = {'FM' mod_FM cert_FM;...
                            'AM' mod_AM cert_AM};

        %Determine modulation type
        mod_info=det_modtype(analysis_results);
        %Record modulation type into soi_data table
        [soi_data, csv_file]=rec_mod_type(mod_info, IF, soi_data, csv_file);
    end
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
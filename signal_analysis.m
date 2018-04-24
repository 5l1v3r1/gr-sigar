%% This algorithm will evaluate the modulation type of captured signals
% Assumptions: the data obtained contains only one usable signal. No signal
% discrimination has been implemented yet.
clear
addpath(genpath('.')) %Add the subdirectories in the home directory so files can be called from other directories
%% Initial user input
init_prompt = ['What do you want to do?\n\n'...
        '0:    Run gr-scan\n'...
        '1:    Search for bin/dat file(s) to analyze\n'...
        '2:    Exit\n> '];
    
 mod_indication={};
 int_freq={};
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
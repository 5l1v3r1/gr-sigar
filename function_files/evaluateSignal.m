%% Let user pick files, calls frequency analysis function (which determines mod type)
function [mod_info, IF, soi_data, csv_file, freqData] = evaluateSignal
    % Gets data from the binary file(s) created by gr-scan and determines
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
            headers = {'time' 'frequency_mhz' 'width_khz' 'peak_db' 'dif_db' 'filename' 'mod_type' 'certainty'};
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
        soi_data=[];
        csv_file=[];
        freqData=[];
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

%% Record modulation type and certainty into soi_data table
function [soi_data, csv_file]=rec_mod_type(mod_type, IF, soi_data, csv_file)
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
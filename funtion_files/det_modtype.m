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
end
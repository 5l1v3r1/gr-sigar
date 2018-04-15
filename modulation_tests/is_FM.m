%% Determines if a sighnal is frequency modulated***
function [FM_modulated, certainty] = is_FM(freqMax, IF)
    %global freqMax   
    chunkSize = fix(length(freqMax)/10);
    forLoopEnd=10;
    
    %if chunks are too small, just use the normal length of freqMax instead
    if chunkSize ==1
        chunkSize=length(freqMax);%freqMax);
        forLoopEnd=1;
    end
    isFM=0;
    for c= 1:forLoopEnd
        stdValue = std(freqMax(chunkSize*(c-1)+1:chunkSize*c)); 
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

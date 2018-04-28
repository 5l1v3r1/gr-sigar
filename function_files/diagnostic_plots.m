function diagnostic_plots(data, freqData, c, k, w, x_Hz, Fs)
        hold
        %Data fro FFT Plot
        subplot(3,1,1)
        plot(x_Hz,abs(freqData))
        title("Signal's FFT")
        
        %data for time domain plot
        subplot(3,1,2)
        timedata = (data(w*(c-1)+1:w*c));
        x = (1:1:w)*(c/Fs);
        plot(x,abs(timedata), x, imag(timedata), x, real(timedata))
        title("Signal in time domain")

        %IQ Constellation
        subplot(3,1,3)
        plot(timedata, '*')
        title("Signal I/Q components")
        
        if c==k
            %Create a new figure at the end of the loop for the next signal
            figure
        elseif c==1
            %Set the Yscal to logarithmic for the first iteration of the
            %loop.
            set(gca,'YScale','log')
        end
        %pause
end
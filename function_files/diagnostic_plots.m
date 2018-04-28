function diagnostic_plots(data, freqData, c, k, w, x_Hz, Fs)
        hold
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
        
        if c==k
            figure
        elseif c==1
            set(gca,'YScale','log')
        end
        %pause
end
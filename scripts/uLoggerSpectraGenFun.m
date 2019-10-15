function [spectra,timeStamp] = uLoggerSpectraGenFun(Y,timeStamp,fileId,preprocFeatOptions)
% Last Modified 03/11/2017 AM
% This function is called by the uLoggerSpectraGen.m script
% Performs fixed length FFT with overlapping window (STFT)

NFFT = preprocFeatOptions.NFFT;
% windowSize = preprocFeatOptions.windowSize;
overlapFrac = preprocFeatOptions.overlapFrac; % .5*preprocFeatOptions.NFFT
plotOption = preprocFeatOptions.plotOption;

fprintf('\t\tGenerating spectra...\n');

% AM Modified 25 Oct 2016: Simulate input/output of MPLAB C-code FFT
% implementation, i.e. 
% Input to FFT = round(scaled by 1000)?
% Output of FFT = round(mag(fft))

if size(Y,1)<NFFT
    printf('NSignal<NFFT - Skipping this recording\n');
    spectra = [];    
    timeStamp = [];
else
    if preprocFeatOptions.normalizeBeforeSpectra
        Y = zscore(Y);
    end
    % FFT of accelerometry data overlapping windows
    Nwindows = length((1:1-overlapFrac:floor(size(Y,1)/NFFT))');
    % Find approximate corresponding time stamps    
    timeStamp = linspace(timeStamp(NFFT/2),timeStamp(end-NFFT/2),Nwindows)';        
    spectra = nan(NFFT/2,Nwindows);

    if preprocFeatOptions.windowBeforeSpectra
        win = hann(NFFT,'periodic');
    end
        
    idx = 1;
    for nWin=1:Nwindows
        idxStart = (idx-1)*overlapFrac*NFFT+1;
        idxEnd = idxStart+NFFT-1;
%         fprintf('%d %d %d\n',idx,idxStart,idxEnd);           

        Ywin = Y(idxStart:idxEnd);

        if preprocFeatOptions.windowBeforeSpectra
            Ywin = win.*Ywin;
        end
        
        % Apply FFT per window to the highpassed Y signal         
        Yfhat = fft(Ywin, NFFT);

        % save this up to the nyquist limit. 
        spectra(:,nWin) = abs(Yfhat(1:NFFT/2));       
    
        if plotOption            
            figure(100);
            subplot(4,1,1);plot(Y(idxStart:idxEnd));grid on;grid minor;
            ylabel('Y');
            subplot(4,1,2);plot(Ywin);grid on;grid minor;
            ylabel('Y highpassed');
            xlabel('Freq (Hz)');
            subplot(4,1,3);plot(spectra(:,nWin));grid on;grid minor;
            ylabel('|Y_fft|');            
            subplot(4,1,4);plot(10*log10(spectra(:,nWin)));grid on;grid minor;
            ylabel('|Y_fft| (dB)');
            figure(100);
            pause(.1);         
        end     
        idx = idx+1;
    end

%     figure(101);
%     xMax = timeStamp(end)+5;
%     yMin = min(Y);
%     yMax = max(Y);
%     subplot(3,1,1);plot(timeStamp,Y);grid on;grid minor;
%     axis([0 xMax yMin yMax]);
%     ylabel('Y');
%     subplot(3,1,2);plot(timeStamp,Y_hp);grid on;grid minor;
%     axis([0 xMax yMin yMax]);
%     ylabel('Y highpassed');
%     xlabel('Freq (Hz)');         
%     subplot(3,1,3);plot(timeStamp,spd/preprocFeatOptions.Fs);grid on;grid minor;
%     axis([0 xMax 0 max(spd/preprocFeatOptions.Fs)]);
%     ylabel('Speed (rate of chance of angle) (deg/s)');
%     keyboard;
end

fprintf('\t\tSpectra generation complete\n');

% figure(101);
% subplot(2,1,1);
% imagesc(spectra);
% caxis([prctile(spectra(:),2.5),prctile(spectra(:),97.5)]);
% set(gca,'YDir','normal');
% subplot(2,1,2);
% imagesc(10*log10(spectra));
% caxis([prctile(10*log10(spectra(:)),2.5),prctile(10*log10(spectra(:)),97.5)]);
% set(gca,'YDir','normal');
% keyboard;
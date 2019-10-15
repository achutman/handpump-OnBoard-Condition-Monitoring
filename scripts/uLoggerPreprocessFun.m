function [dataPreproc,timeStamp] = uLoggerPreprocessFun(data,timeStamp,fileId,preprocFeatOptions)
% Last Modified 03/11/2017 AM
% This function is called by the uLoggerSpectraGen.m script
% Does all the preprocessing
% LPF >> Find peaks >> Remove the ends of the original signal >> HPF
% Caution - Involves various adhoc numbers/parameters!

windowSize = preprocFeatOptions.windowSize;
thresholdToFindPeaks = preprocFeatOptions.thresholdToFindPeaks; % threshold used when calling findpeaks.m
distBetnTroughsThres = preprocFeatOptions.distBetnTroughsThres; % median +/- 0.5*median
minNumOfTroughsInRecording = preprocFeatOptions.minNumOfTroughsInRecording; % In order to consider this recording
downsampleFactor = preprocFeatOptions.downsampleFactor;
Fs = preprocFeatOptions.Fs; % sampling frequency will change depending on downsample factor
plotOption = preprocFeatOptions.plotOption;

fprintf('\t\tPreprocessing...\n');

%General gist: 
%Design of low-pass/high-pass filters:Done fairly arbitrarily, based on what looks OK

% Note - For PIC-implementation, use moving average to approximate filters

% Zero-phase filtering
% http://uk.mathworks.com/help/signal/ref/filtfilt.html
Fpass = 2/downsampleFactor;% 2*Fpass(Hz)/sampling f(Hz) in normalized freq
Fstop = 4/downsampleFactor;% 2*Fstop(Hz)/sampling f(Hz) in normalized freq
Lowpass = designfilt('lowpassfir', ...
    'PassbandFrequency',2*Fpass/Fs,'StopbandFrequency',2*Fstop/Fs, ...
    'PassbandRipple',1,'StopbandAttenuation',60, ...
    'DesignMethod','equiripple');

% Using Signal-MovingAverage(Phase-shift corrected) instead
Fpass = 4/downsampleFactor; % 2*Fpass(Hz)/sampling f(Hz) in normalized freq
Fstop = 2/downsampleFactor; % 2*Fstop(Hz)/sampling f(Hz) in normalized freq
Highpass = designfilt('highpassfir', ...
    'PassbandFrequency',2*Fpass/Fs,'StopbandFrequency',2*Fstop/Fs, ...
    'PassbandRipple',1,'StopbandAttenuation',60, ...
    'DesignMethod','equiripple');

% Visualize the filter
% fvtool(Lowpass);

Y = data(:,1);

% AM Modified 06 Feb 2017
% There has to be enough samples!
if length(Y)<=windowSize
    printf('NSignal<windowSize - Skipping this recording\n');
    dataPreproc = [];
    timeStamp = [];
else
    % lowpass filter and arc calculation for gross movement
    Y_lp = filtfilt(Lowpass,Y);

    if (plotOption)
        xMax = timeStamp(end)+5;
        yMin = min(Y);
        yMax = max(Y);
    end
    if (plotOption)
        figure(1);clf;
        subplot(5,1,1);plot(timeStamp,Y);ylabel('Y');grid on;
%         axis([0 xMax yMin yMax]);
        title('Preprocessing');
        figure(1);subplot(5,1,2);plot(timeStamp,Y_lp);ylabel('Y Low-passed');grid on;
%         axis([0 xMax yMin yMax]);
    end

    % Find troughs to find periods
    % Clip ends, i.e. remove signal before/after first/last trough
    x = (1:length(Y_lp))';
    % Find the troughs
    [~,locsTroughs] = findpeaks(-Y_lp,x,'MinPeakProminence',thresholdToFindPeaks);
    if (plotOption)  
        figure(1);subplot(5,1,3);
        plot(timeStamp,Y_lp);hold on;
        plot(timeStamp(locsTroughs),Y_lp(locsTroughs),'or'); 
        hold off;grid on;
%         axis([0 xMax yMin yMax]);
    end

    % There has to be at least 10 troughs!
    if length(locsTroughs)<=minNumOfTroughsInRecording
        fprintf('NPeriods<minNPeriods - Skipping this recording\n');
        dataPreproc = [];
        timeStamp = [];
    else
        % Remove the first and last trough
        locsTroughs = locsTroughs(2:end-1);
        intervalWo1andNTrough = (locsTroughs(1):locsTroughs(end))';

        % Check if the length of time-series >= NFFT
        if length(intervalWo1andNTrough)<windowSize
            printf('NPeriods<minNPeriods - Skipping this recording\n');
            dataPreproc = [];
            timeStamp = [];
        else    
            % Ends removed
            Y_lp = Y_lp(intervalWo1andNTrough);
            data = data(intervalWo1andNTrough,:);
            %     arc = arc(intervalWo1andNTrough); % Adjust arc
            timeStamp = timeStamp(intervalWo1andNTrough); % Adjust timeStamp        
            locsTroughs = bsxfun(@minus,locsTroughs,locsTroughs(1)-1); % Adjust locs of troughs 
            
            if (plotOption)                
                figure(1);subplot(5,1,4);
                plot(timeStamp,Y_lp);hold on;
                plot(timeStamp(locsTroughs),Y_lp(locsTroughs),'or'); 
                hold off;grid on;                
            end
            
           if preprocFeatOptions.findTypicalObs
                % Only consider window with "typical" observations
                % "typical" = minDist < distBetnTroughs < maxDist
                indicesToRemove = [];
                distBetnTroughs = locsTroughs(2:end)-locsTroughs(1:end-1);

                fprintf('FileId %d Pump stroke period (secs): Avg %.1f, 1SD %.1f, Med %.1f\n',...
                    fileId,mean(distBetnTroughs/Fs),std(distBetnTroughs/Fs),median(distBetnTroughs/Fs));

                medDistBetnTroughs = median(distBetnTroughs);
                atypicalLocsTroughs = find(distBetnTroughs>(1+distBetnTroughsThres)*medDistBetnTroughs);
                for idx=1:size(atypicalLocsTroughs,1)
                    indicesToRemove = cat(1,indicesToRemove,(locsTroughs(atypicalLocsTroughs(idx)):locsTroughs(atypicalLocsTroughs(idx)+1))');
                end
                data(indicesToRemove,:) = [];
                Y = data(:,1);
                timeStamp(indicesToRemove) = [];
           end
            
            % Apply highpass filter to whole recording
            % Note: Use a simpler approximate fileter to implement on PIC 
            % MATLAB's FIR followed by filtfilt (takes care of phase shift)
            Y_hp = filtfilt(Highpass, data(:,1));         
            X_hp = filtfilt(Highpass, data(:,2)); 
            Z_hp = filtfilt(Highpass, data(:,3));
            dataPreproc = cat(2,Y_hp,X_hp,Z_hp);

        end
    end
end

fprintf('\t\tPreprocessing complete\n');
% keyboard;
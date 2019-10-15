clear
close all

% Last Modified 03/11/2017 AM

% Filters designed using MATLAB's designfilt function
% loggerPreprocess***.m function does all the preprocessing
% loggerStft***.m function does STFT per window

% Choose which accelerometer signal to use (1, 2, or 3)

% Feature generation (adhoc): 
% (I) Uniformly samples across freq range
% (II) Handpicked looking at spectra plot

% Please save the dataset that will be used by uLoggerRecordingsClassifyScript.m to
% perform classification

% Pump condition: 0=abnormal, 1=normal
conditionFieldNotes = [0     1     1     0     1     1   1];

% Path to data
dataPath = '\...UNICEFsmartHandpumpConditionMonitoring\dataPlots\dataAccelerometerLoc1';

% Choose which accelerometer signal to use 
% preprocFeatOptions.accelerometerSignal = '1';

% Choose downsample factor
preprocFeatOptions.downsampleFactor = 1;
% If the signal is downsampled, Fs will change
% Wiimote
% preprocFeatOptions.Fs = 96/preprocFeatOptions.downsampleFactor;  % Sampling Frequency
% Logger
preprocFeatOptions.Fs = 95/preprocFeatOptions.downsampleFactor;  % Sampling Frequency

% Scaling factor to scale up and round accelerometer signals to make
% portable in PIC18 MPLAB implementation
preprocFeatOptions.scaleFactorIntContraint = 1;

% Preprocessing options
preprocFeatOptions.findTypicalObs = true;
% Preproc ad-hoc options to discard useless signals
preprocFeatOptions.thresholdToFindPeaks = .2*10000;%preprocFeatOptions.scaleFactorIntContraint; % threshold used when calling findpeaks.m
preprocFeatOptions.distBetnTroughsThres = 0.5; % median +/- 0.5*median
preprocFeatOptions.minNumOfTroughsInRecording = 10; % In order to consider this recording

% Feature (spectra) generation options
preprocFeatOptions.normalizeBeforeSpectra = false;
preprocFeatOptions.windowBeforeSpectra = false;
% For each window in the clip, size of windows and their overlap = 
% Trade off between frequency/time resolution and smoothness
preprocFeatOptions.windowSize = 128;
preprocFeatOptions.NFFT = preprocFeatOptions.windowSize; % At Fs = 96 Hz and Median pump stroke period = 1.2s, 512 samples = 4.5 pump strokes. If downsampled by 2, 256 samples = 4.5 strokes.
preprocFeatOptions.overlapFrac = .5; % .5*preprocFeatOptions.NFFT, When spectra generated using wiimoteRecordingsFftFixedLen.m

% Feature generation
preprocFeatOptions.featureSelection = (6:3:60);

fileIdVec = [];
conditionVec = [];
spectra = [];

% Begin code
for fileId=(1:7)
    fprintf('Analyzing data from file %s \n',fileId);
    fileName = sprintf('%d',fileId);
    load(fullfile(dataPath,fileName));   
    
    % For speed
    conditionThisFile = conditionFieldNotes(fileId);  

    timeStamp = cumsum(dataMat(:,4))/4000000;                            

    % Preprocess:
    % LPF >> Find peaks >> Remove the ends of the original signal >> HPF
    preprocFeatOptions.plotOption = false;            
    [dataPreproc,timeStampThisRec] = uLoggerPreprocessFun(dataMat(:,1:3),timeStamp,fileId,preprocFeatOptions);   

    % Generate Spectra:
    % "timeStampWindow" = time stamp may not correspond to true time stamp due to preprocessing (Need to verify)
    preprocFeatOptions.plotOption = false;
    [spectraThisFile,timeStampThisRec] = uLoggerSpectraGenFun(dataPreproc(:,3),timeStampThisRec,fileId,preprocFeatOptions); 
    
    lenThisFile = size(spectraThisFile,2);
    fileIdVec = cat(1,fileIdVec,fileId*ones(lenThisFile,1));    
    conditionVec = cat(1,conditionVec,conditionThisFile*ones(lenThisFile,1));
    
    spectra = cat(2,spectra,spectraThisFile);     
    
    close all;

end
keyboard;


%%  Once the spectra is generated above, plot the spectra, etc.
% Labels
isnor = conditionVec;

xAxis = 1:size(spectra,2);
yAxis = linspace(1,preprocFeatOptions.Fs/(2*preprocFeatOptions.downsampleFactor),size(spectra,1));       

% Sort based on labels
[~,sortIndices] = sort(conditionVec);

figure(10);
subplot(6,1,1:2);imagesc(xAxis,yAxis,spectra(:,sortIndices)); 
caxis(prctile(spectra(:),[2.5,99.5]));
set(gca,'YDir','normal'); ylabel('Frequency'); 
title(sprintf('|FFT|'));      

% Plot spectra (dB), fileId indices, and labels
spectraDB = 10*log10(spectra);
subplot(6,1,3:4);imagesc(xAxis,yAxis,spectraDB(:,sortIndices)); 
caxis(prctile(spectraDB(:),[2.5,99.5]));
set(gca,'YDir','normal'); ylabel('Frequency'); 
title(sprintf('|FFT| dB'));

subplot(6,1,5);plot(conditionVec(sortIndices),'LineWidth',1.5);grid on;axis([0 size(spectra,2) -0.1 1.1]); 
ylabel('Prefix/postfix label');
xlabel('Window count across all recordings');     

subplot(6,1,6);
plot(fileIdVec(sortIndices),'LineWidth',1.5);grid on;grid minor;
axis([0 size(spectra,2) 0 8]); 
ylabel('Recording Id');
    
%% 
% Once the spectra is generated above, choose freq components as features
% Adhoc: 
%     (1) Uniformly samples across freq range
%     (2) Handpicked looking at spectra plot
%% Feature Selection
% dataset.data = features; 
dataset.data = spectraDB(preprocFeatOptions.featureSelection,:)'; 
dataset.labels = conditionVec;
dataset.groupLabels = fileIdVec;
dataset.preprocFeatOptions = preprocFeatOptions;
if preprocFeatOptions.saveData
    saveDataPath = '\...UNICEFsmartHandpumpConditionMonitoring\data';
    save(fullfile(saveDataPath,'spectraLoc1Acc3FftN128Freq3_3_60dB'),'dataset');
end
function outputsTrain = uLoggerRecordingsClassifyLrTrain(Xtrain,myOptions)
% Last Modified 03/11/2017 AM
% Called by uLoggerRecordingsClassifyScript.m

% % Train linear regression classifier 
% fitglm
mdl = fitglm(Xtrain.data,Xtrain.labels,'Distribution','binomial','Link','logit');
outputsTrain.mdl = mdl;

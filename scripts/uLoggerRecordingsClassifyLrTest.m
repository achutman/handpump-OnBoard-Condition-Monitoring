function yOut = uLoggerRecordingsClassifyLrTest(Xtest,outputsTrain,myOptions)
% Last Modified 03/11/2017 AM
% Called by uLoggerRecordingsClassifyScript.m

mdl = outputsTrain.mdl;
yOut = mdl.predict(Xtest.data);

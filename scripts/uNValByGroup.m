function [yOut, xValTrainedClassifier, crossValKeysByGroup] = uNValByGroup(dataset,numOfFolds,myTrainFun,myTestFun,myOptions)
% yOut = uNValByGroup(dataset,numOfFolds,myTrainFun,myTestFun,myOptions)
% dataset has fields 'data' and 'labels'
% Last Modified 03/11/2017 AM

dataset.groupLabels = grp2idx(dataset.groupLabels);
NGroups = length(unique(dataset.groupLabels));
NSamples = length(dataset.labels);
yOut = zeros(NSamples,1);

% AM Modified 31 Mar 2017
if (isfield(myOptions,'crossValKeys'))
    crossValKeysByGroup = myOptions.crossValKeys;
else    
    foldNums = 1:numOfFolds;
    quotient = ceil(NGroups/numOfFolds);
    foldLabels = repmat(foldNums',quotient,1);
    foldLabels = foldLabels(1:NGroups);
    crossValKeysByGroup = foldLabels(randperm(NGroups));
end
crossValKeysBySample = crossValKeysByGroup(dataset.groupLabels);

namesOfFields = fieldnames(dataset);
for nFold=1:numOfFolds
    for nField=1:length(namesOfFields)
        fieldname = char(namesOfFields(nField));   
        % If the size of this field corresponds to the total samples
        if size(dataset.(fieldname),1)==NSamples
            Xtrain.(fieldname)  = dataset.(fieldname)(crossValKeysBySample~=nFold,:);
            Xtest.(fieldname)   = dataset.(fieldname)(crossValKeysBySample==nFold,:);         
        end
    end   
    
    if myOptions.balanceData
        Xtrain = balanceDataFun(Xtrain);
%         Xtest = balanceDataFun(Xtest);
    end
     
    myOptions.nFold = nFold;
    outputsTrain = myTrainFun(Xtrain,myOptions); % how to make this general??!!!    
    
    % what if dataset are downsampled and groupLabels are random??? or
    % non-sequentially increasing?? 
    yOut(crossValKeysBySample==nFold) = myTestFun(Xtest,outputsTrain,myOptions);        
    xValTrainedClassifier(nFold).outputsTrain = outputsTrain;
    
end

end

function Xtrain = balanceDataFun(Xtrain)
%     keyboard;
    totalByClass = accumarray(grp2idx(Xtrain.labels),ones(size(Xtrain.labels)));
    if length(totalByClass)>2
        error('Balance fun only works for binary classification data!');
    end
    totalSamplesToKeep = min(totalByClass);
    proportion = totalByClass./sum(totalByClass);
    if proportion(1)<.4
        % Label 0 < Label 1, i.e. randomly select subset from Label 1's
        datatemp = Xtrain.data(Xtrain.labels==1,:);
        labelstemp = Xtrain.labels(Xtrain.labels==1,:);
        groupLabelstemp = Xtrain.groupLabels(Xtrain.labels==1,:);
        indices = randperm(totalByClass(2))';
        indices(totalSamplesToKeep+1:end) = [];
        Xtrain.data = cat(1,Xtrain.data(Xtrain.labels==0,:),datatemp(indices,:));
        Xtrain.labels = cat(1,Xtrain.labels(Xtrain.labels==0,:),labelstemp(indices,:));
        Xtrain.groupLabels = cat(1,Xtrain.groupLabels(Xtrain.labels==0,:),groupLabelstemp(indices,:));
    elseif proportion(1)>.6
        % Label 0 > Label 1, i.e. remove from Label 0's
        datatemp = Xtrain.data(Xtrain.labels==0,:);
        labelstemp = Xtrain.labels(Xtrain.labels==0,:);
        groupLabelstemp = Xtrain.groupLabels(Xtrain.labels==0,:);
        indices = randperm(totalByClass(1))';
        indices(totalSamplesToKeep+1:end) = [];
        Xtrain.data = cat(1,Xtrain.data(Xtrain.labels==1,:),datatemp(indices,:));
        Xtrain.labels = cat(1,Xtrain.labels(Xtrain.labels==1,:),labelstemp(indices,:));
        Xtrain.groupLabels = cat(1,Xtrain.groupLabels(Xtrain.labels==1,:),groupLabelstemp(indices,:));
    end    
end
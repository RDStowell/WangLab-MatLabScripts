% script to read in olympus files and calculate std
% K.H.Wang 05102021

%% specify the folder containing image data files for one brain
clearvars; 
close all;

inputFolder = uigetdir;
%inputFolder = '/Users/kwang56/Documents/MATLAB/Scripts/Rianne Stowell/calcium imaging/Revision Calcium Final';

%% Get inputFolder contents
% subfolder organized by animal and condition
subFolder = dir(fullfile(inputFolder));
subFolder(startsWith({subFolder.name},'.')) = [];
nFolder = length(subFolder);

% get animal names and conditions
treatmentAnimal = cell(nFolder,1);
for i = 1:nFolder
    newStr = split(subFolder(i).name,{' ','+'});
    emptyIdx = cellfun(@isempty,newStr);
    newStr(emptyIdx) = [];
    treatmentAnimal{i} = [newStr{end-1},'-',newStr{end},'-',newStr{1}(1)];
end
[treatmentAnimal, sId] = sort(upper(treatmentAnimal)); % sort by condition
subFolder = subFolder(sId);

% images organized by session per day
dirC = cell(nFolder,1); 
for i = 1:nFolder
    % get oib file names in subfolders
    listing = dir(fullfile(subFolder(i).folder,subFolder(i).name,'*.oib'));  
    
    % sort files by naming convention: baseline,1 condition, 2 conditions
    % connected with "+"
    fileNames = {listing.name};   
    sortIdx = zeros(3,1);
    sortIdx(1) = find(contains(fileNames,'base','IgnoreCase',true));
    sortIdx(3) = find(contains(fileNames,'+','IgnoreCase',true));
    sortIdx(2) = setdiff(1:3,sortIdx([1 3]));
    listing = listing(sortIdx);
    
    % store file paths
    dirC{i} = listing;
end

% concatenate dirC
dirC = cat(1,dirC{:});
nFile = length(dirC);

%% Run a loop to visually inspect each image stack

hF = figure;

for i = 1:nFile
    %% generate full file name
    filename = fullfile(dirC(i).folder,dirC(i).name); 
%     [fi,pa] = uigetfile('*.oib');
%     filename = fullfile(pa,fi);
    
    % read image file
    [keyValue,metaData,I] = openFV1000(filename);
    I = squeeze(I); % from xyzct to xyt
    fps = 1./keyValue.tInterval*1000; % frames per second
    
    %  image file name
    imgName = split(dirC(i).name,'.'); % split file name and extension
    
    % command line and figure name display
    currentImg = ['i = ', num2str(i),', ', imgName{1}];
    disp(currentImg);
    set(gcf,'name',currentImg);
     
    % visual inspect image stability
    calciumVideoStabilityInspect(I,fps)
            
    %% closing figure window breaks the loop
    if ~ishandle(hF)
        break
    end
    
end
close(gcf)

%% Run a loop to analyze each file
caSigA = cell(nFile,1);
imgCond = cell(nFile,1);

tic;
for i = 1:nFile
    %% generate full file name
    filename = fullfile(dirC(i).folder,dirC(i).name); 
    
    % read image file
    [keyValue,metaData,I] = openFV1000(filename);
    I = squeeze(I); % from xyzct to xyt
    fps = 1./keyValue.tInterval*1000; % frames per second
    
    % calculate whole field dFoF signal
    caSig = wholeFieldCa(I,fps);

    % store results
    caSigA{i} = caSig;
    
    % store image file name
    imgName = split(dirC(i).name,'.'); % split file name and extension
    imgCond{i} = imgName{1};
    
    disp(i);
    disp(imgCond{i});

end
toc;

frameRate = keyValue.tInterval; % ms

%% group analysis
% get dFoF std
caStd = cellfun(@(x) x.dFoFStd, caSigA);

% reshape caStd, imaging session x animalTreatment
nGroup = nFile/3;
caStd = reshape(caStd,[3,nGroup]);

% normalize by baseline
caStd = (caStd-caStd(1,:))./caStd(1,:);

% plot caStd results
figure;
nCond = 3;
nSub = nGroup/nCond;

tiledlayout(1,nCond);
axA = cell(nCond,1);
ylimA = zeros(nCond,2);
for i = 1:nCond
    axA{i} = nexttile;
    hold on;
    for j = 1:nSub
        k = (i-1) * nSub + j;
        plot(caStd(:,k),'o-','linewidth',1); axis tight;
    end
    title(treatmentAnimal{k}(1:7));
    ylabel('Ca activity (dF/F)');
    xlabel('session');
    legend(cellfun(@(x) {x(end)},treatmentAnimal(1:nSub)));

    % store y-axis lim
    yL = get(gca,'YLim');
    ylimA(i,:) = yL;    
end

% set common ylim
minY = min(ylimA(:,1));
maxY = max(ylimA(:,2));
for i = 1:nCond
    set(axA{i}, 'YLim',[minY,maxY]);
end

% group stats
hA = cell(nCond,1);
yL = zeros(nCond,2);
figure;
tiledlayout(1,nCond);
for i = 1:nCond
    subR = (i-1)*nSub+1 : i*nSub;
    tmp = caStd(:,subR);
    tmpM = mean(tmp,2);
    tmpS = std(tmp,[],2)./sqrt(nSub);
    [h,p] = ttest(tmp(2,:),tmp(3,:));
    hA{i} = nexttile;
    bar(tmpM,'FaceColor','w'); hold on;
    errorbar(tmpM,tmpS,'x');
    for j = 1:3
        plot(j,tmp(j,:),'ko');
    end
    xticklabels({'baseline',treatmentAnimal{i*nSub}(1:3),treatmentAnimal{i*nSub}(5:7)});
    title(['p = ',num2str(p,2)]);
    ylabel('Changes in Ca Activity')
    yL(i,:) = get(gca,'YLim');
end
for i = 1:nCond
    hA{i}.YLim = [min(yL(:,1)), max(yL(:,2))];
end
    
%% plot individual dFoF results
figure;
% tiledlayout(nFile,1);
ylimA = zeros(nFile,2);
axA = cell(nFile,1);
for i = 1:nFile
    axA{i} = nexttile;
    timeVect = (1:length(caSigA{i}.dFoF)).*frameRate/1000; % sec
    imgGrp = [treatmentAnimal{ceil(i/3)},num2str(mod(i-1,3))];
    plot(timeVect, caSigA{i}.dFoF,'linewidth',1); axis tight;
    title(['std = ',num2str(caSigA{i}.dFoFStd,2),' ',imgGrp]);
    ylabel('Ca activity (dF/F)');
    xlabel('frame');
    
    % store y-axis lim
    yL = get(gca,'YLim');
    ylimA(i,:) = yL;    
%     waitforbuttonpress
end

% set common ylim
minY = min(ylimA(:,1));
maxY = max(ylimA(:,2));
for i = 1:nFile
    set(axA{i}, 'YLim',[minY,maxY]);
end

figure;
% tiledlayout(nFile,1);
ylimA = zeros(nFile,2);
axA = cell(nFile,1);
for i = 1:nFile
    axA{i} = nexttile;
    timeVect = (1:length(caSigA{i}.Z)).*frameRate/1000; % sec
    imgGrp = [treatmentAnimal{ceil(i/3)},num2str(mod(i-1,3))];
    plot(timeVect, caSigA{i}.Z,'linewidth',1); axis tight;
    title(imgGrp);
    ylabel('img stability Z');
    xlabel('frame');
    
    % store y-axis lim
    yL = get(gca,'YLim');
    ylimA(i,:) = yL;    
%     waitforbuttonpress
end

% set common ylim
minY = min(ylimA(:,1));
maxY = max(ylimA(:,2));
for i = 1:nFile
    set(axA{i}, 'YLim',[minY,maxY]);
end
    
%% check every image file
dirC = dir(fullfile(inputFolder,'**/*.oib'));
[~,sIdx] = sort(upper({dirC.name}));
dirC = dirC(sIdx);
nFile = length(dirC);

%%
data = struct;
for i = 1:nFile
    data(i).name = dirC(i).name;
    data(i).Ze = caSigA{i}.Ze;
    data(i).dFoFStd = caSigA{i}.dFoFStd;
end

%  save tmp051421

function calciumVideoStabilityInspect(I,fps)
% This function accepts a xyt calcium image stack (I) and enables visual
% inspection of its stability
% check frame by frame correlation with mean projection image
% check whole field calcium signal frame by frame
% K.H.Wang 03012021

%% get wholeFieldCa output
output = wholeFieldCa(I,fps);
Z = output.Z;
Ze = output.Ze;
thr = output.thr;
dFoF = output.dFoF;
dFoFStd = output.dFoFStd;

%% visually inspect
hF = figure(gcf);
clf(hF);

% set up sliceviewer
hP = uipanel(hF, 'Position',[0.05,0.2,0.4,0.7],'title','Ca image movie');
dispR = prctile(I(:),[2 99.9]);
hI = sliceViewer(I,'parent',hP,'sliceNumber',1,'DisplayRange',dispR);

% set up z-stability plot
hA1 = axes('Position',[0.5 0.55 0.45 0.35]);
plot(Z,'b');hold on;axis tight;
plot(get(gca,'xlim'),thr*ones(2,1),'r-');
title(['z-stability ', num2str(Ze)])
ylabel('Z score')

% set up whole field dFoF plot
hA2 = axes('Position',[0.5 0.1 0.45 0.35]);
plot(dFoF,'r');hold on;axis tight;
title(['whole field signal ',num2str(dFoFStd,2)])
ylabel('dFoF');
xlabel('Frame')

% add listener and interaction
hL1 = plot(hA1,[1 1],hA1.YLim,'g-','linewidth',2);
hL2 = plot(hA2,[1 1],hA2.YLim,'g-','linewidth',2);
hWin = round(fps*60); % 60 sec sliding half window
nFrame = size(I,3);
addlistener(hI,'SliderValueChanging',...
    @(src,evt) moveLine(src,evt,hL1,hL2,hA1,hA2,hWin,nFrame));

% set up continue button
uicontrol('Style','pushbutton','String','Continue','Units','normalized',...
    'Position',[0.2,0.05,0.2,0.1],'Callback','uiresume' );

% wait until click close button
uiwait

end

% callback function
function moveLine(~,evt,hL1,hL2,hA1,hA2,hWin,nFrame) 
    
    curFrame = evt.CurrentValue;
    xMin = max(0,curFrame - hWin);
    xMax = min(nFrame,curFrame + hWin);
    hL1.XData = curFrame * ones(1,2);
    hL2.XData = curFrame * ones(1,2);
    hA1.XLim = [xMin xMax];
    hA2.XLim = [xMin xMax];

end
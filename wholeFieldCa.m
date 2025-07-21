% This function calculates the standard deviation of whole field average 
% calcium activity
% I should be in x,y,t format
% fps frame per second
% K.H.Wang 05102021

function output = wholeFieldCa(I,fps)

%% image dimension
[nrow,ncolumn,nframe] = size(I);

%% check image quality for movement artifact
Is = imgaussfilt(double(I),2); % denoise I in 2D
Iv = reshape(Is,nrow*ncolumn,nframe); % vectorize images

%% detect single frame jumps
Ib1 = smoothdata(Iv,2,'movmedian',3); % 
Id1 = Iv - Ib1;
Z = sum(Id1.*(Id1<0),1); % large negative changes caused by Z-jumps

%% set excluded frames
Z = (Z - median(Z))./mad(Z,1)/1.4826; %  standardize
thr = -3;
exId = Z < thr;
Ze = nnz(exId)./nframe;

%% calculate whole field dFoF std
% remove slow drifting baseline (bleaching) in xx sec windows
baseWinT = 30;      % sec baseline window
baseWinF = round(baseWinT*fps/2)*2+1;

% subtract baseline
Ie = Iv;
Ie(:,exId) = NaN;
if nframe > baseWinF
    Ib = smoothdata(Ie,2,'movmean',baseWinF);
else
    Ib = nanmean(Ie,2);
end
Id = Ie - Ib;

% whole field average
Ida = mean(Id,1); % dF
Iba = mean(Ib,1); % baseline

% dFoF calculation
% minI = double(min(I(:)));
% dFoF = Ida./(Iba-minI);
dFoF = Ida./Iba;
% dFoF = Ida./mean(Iba);

% exclude jumped frames and calculate std
dFoFStd = std(dFoF(~exId));

% store output
output.dFoF = dFoF;
output.dFoFStd = dFoFStd;
output.Z = Z;
output.exId = exId;
output.thr = thr;
output.Ze = Ze;


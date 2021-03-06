function [N,cloud] = Abs_Analysis_DualFit(varargin)

atomType = 'Rb87';
% tof = varargin{2};
tof = 216.35e-3;%camera two

col1 = 'b.-';
col2 = 'r--';
dispOD = [0,.5];
plotOpt = 0;
plotROI = 0;
useFilt = 1;
filtWidth = 25e-6;
%% Imaging ROI first spot
% fitdata = AtomCloudFit('roiRow',[500,720],...
%                        'roiCol',[0,250],...
%                        'roiStep',2,...
%                        'fittype','tf2d');    %Options: none, gauss1d, twocomp1d, bec1d, gauss2d, twocomp2d, bec2d

%% Imaging Second spot
fitdata = AtomCloudFit('roiRow',[160,800],...
                       'roiCol',[550,850],...
                       'roiStep',2,...
                       'fittype','none'); 

%% Imaging parameters
imgconsts = AtomImageConstants(atomType,'tof',tof,'detuning',0,...
            'pixelsize',6.45e-6,'magnification',0.99,...
            'freqs',2*pi*[53,53,25],'exposureTime',14e-6,...
            'polarizationcorrection',1.5,'satOD',5);

directory = 'E:\RawImages\2021';

%% Load raw data
if nargin == 0 || (nargin == 1 && strcmpi(varargin{1},'last')) || (nargin == 2 && strcmpi(varargin{1},'last') && isnumeric(varargin{2}))
    %
    % If no input arguments are given, or the only argument is 'last', or
    % if the arguments are 'last' and a numeric array, then load the last
    % image(s).  In the case of 2 arguments, the second argument specifies
    % the counting backwards from the last image
    %
    if nargin < 2
        idx = 1;
    else
        idx = varargin{2};
    end
    args = {'files','last','index',idx};
else
    %
    % Otherwise, parse arguments as name/value pairs for input into
    % RawImageData
    %
    if mod(nargin,2) ~= 0
        error('Arguments must occur as name/value pairs!');
    end
    args = varargin; 
end
%
% This loads the raw image sets
%
raw = RawImageData.loadImageSets('directory',directory,args{:});

numImages = numel(raw);
plotOpt = plotOpt || numImages == 1;    %This always enables plotting if only one image is analyzed

cloud = AbsorptionImage.empty;
for nn = 1:numImages
    cloud(nn,1) = AbsorptionImage;
end

N = zeros(numImages,2);

for jj = 1:numImages
    %
    % Copy immutable properties
    %
    cloud(jj).constants.copy(imgconsts);
    cloud(jj).fitdata.copy(fitdata);
    cloud(jj).raw.copy(raw(jj));
    %
    % Create image and fit
    %
    if size(cloud(jj).raw.images,3) == 2
        cloud(jj).makeImage;
    elseif size(cloud(jj).raw.images,3) == 3
        cloud(jj).makeImage([1,2,3]);
    else
        error('Not sure what to do here');
    end
    if useFilt
        cloud(jj).butterworth2D(filtWidth);
    end
%     cloud(jj).fitdata.makeFitObjects(cloud(jj).x,cloud(jj).y,cloud(jj).imageCorr);
    cloud(jj).fit('fittype','none');
    [p,f,~] = dualCloudAnalysis(cloud(jj).fitdata);
    N(jj,1) = 2*pi/5*p(1).becAmp*prod(p(1).becWidth);
    N(jj,2) = 2*pi/5*p(2).becAmp*prod(p(2).becWidth);
    N(jj,:) = N(jj,:)./cloud(jj).constants.absorptionCrossSection.*(1+4*(cloud(jj).constants.detuning/cloud(jj).constants.gamma).^2);
    cloud(jj).fitdata.residuals = cloud(jj).fitdata.image - f;
    cloud(jj).fitdata.xfit = sum(f,1);
    cloud(jj).fitdata.yfit = sum(f,2);
    
        
    %% Plotting
    if plotOpt
        if numImages == 1
            %
            % Plot absorption data and marginal distributions when there is only 1 image
            %
            figure(3);clf;
            cloud(jj).plotAllData(dispOD,col1,col2,plotROI);
        else
            %
            % Plot only the absorption data in a grid when there is more than one image
            %
            if jj == 1
                figure(3);clf;
                dimSubPlot=ceil(sqrt(numImages));
            end
            
            figure(3);
            subplot(dimSubPlot,dimSubPlot,jj);
            cloud(jj).plotAbsData(dispOD,plotROI);
        end
    end
    
    %% Print summaries
    imgNum = cloud(jj).raw.getImageNumbers;
    fprintf(1,'Image: %05d, N1 = %.3g, N2 = %.3g, Ratio = %.3f\n',imgNum(1),N(jj,1),N(jj,2),N(jj,2)./sum(N(jj,:)));
    
end

end



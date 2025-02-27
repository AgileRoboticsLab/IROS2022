% offlinetracker v1.0
% 
% This function inputs a video file of a soft robot with markers to
% outputs the tracked robot pose and the tracked video file
% 
% tracking_data = offlinetracker(inputfilename, outputfilename, options)
% 
% Inputs:
% 1. inputfilename: The name the input video file. The video lighting
% ensures that the robot and the markers are clearly visible [Format: mp4]
% 2. outputfilename: The name of the output video file with the over-laid
% markers and the frame number [Format: mp4]
% 3. options:
%   a. startframe - the frame number from which the tracking starts [1x1]
%   b. number_of_markers - the number of markers on the robot [1x1]
%   c. ifplot - flag for visualizing while data is being processed (debug
%   mode) [0 or 1]
% 
% Output:
% 1. tracking_data: tracked data matrix of dimension 
%    [3x(number_of_markers) + 
%     Intermediate frame {Rotation matrix (9) + displacement (3)}
%     Global frame {Rotation matrix (9) + displacement (3)} + time]
%  2. Tracked video file with overlaid tracked markers of name
%  outputfilename
% 
% Example:
% options.startframe =1;
% options.number_of_markers = 4;
% options.ifplot = false;
% tracking_data = offlinetracker('Gait_B_120', 'Gait_B_120_tracked', options)
% tracking_data will be of dimension Nx(3*4 + 2*(9 + 3) + 1)=Nx37 where N is
% the number of frames
% 
% % =====
% TODO: 
% 1. Convert this to a class with functions processFile(), plotData(),
% 2. Tracking data is in SE(2), hence, everything is much simpler - 2x1 for
% marker positions, 1x1 theta for rotation, 2x1 for displacements. SO2 and
% SE3 maps can map them to rotation and translation matrix. Even pose can
% be constructed out of this.
% 3. Add endframe in options if it is not desired to track the whole video.
% Default should be end of the video.
% % =====
% 
% Author: Arun Niddish Mahendran (anmahendran@crimson.ua.edu)
function tracking_data = offlinetracker(inputfilename, outputfilename, options)
if nargin>2
    startframe = options.startframe;
    number_of_markers = options.numberofmarkers;
    ifplot = options.outputvideo;
else
%   default values
    startframe = 1;
    number_of_markers = 8;
    ifplot = 1;
end

fullFileName = file_name(inputfilename); % To get the directory to video

[videoObject,vwrite] = video_params(fullFileName,outputfilename); % Creating objects for the video

tracking_data = videotracker(videoObject,vwrite,startframe,number_of_markers,ifplot); % Marker data

end

function fullFileName = file_name(baseFileName)

    folder = pwd; % Current folder path
    fullFileName = fullfile(folder, baseFileName);

% Check if the video file actually exists in the current folder or on the search path.
    if ~exist(fullFileName, 'file')
    % File doesn't exist -- didn't find it there.  Check the search path for it.
    fullFileNameOnSearchPath = baseFileName; % No path this time.
        if ~exist(fullFileNameOnSearchPath, 'file')
        % Still didn't find it.  Alert user.
        errorMessage = sprintf('Error: %s does not exist in the search path folders.', fullFileName);
        uiwait(warndlg(errorMessage));
        return;
        end
    end
end

function [videoObject,vwrite] = video_params(fullFileName,video_write_fname)

% Instantiate a video reader object for this video.
  videoObject = VideoReader(fullFileName);

% Creating object for video writing
  vwrite = VideoWriter(video_write_fname,'MPEG-4');
  open(vwrite);

end

% ========================= videotracker ==================================
%
% Author: Arun Mahendran Niddish anmahendran@crimson.ua.edu
%
% Description:
%    This function tracks the centroid points of the MSoRo and provides the
%    rotation and translation in global (w.r.t. first) and body frame for
%    recorded video.
% 
% Inputs:
% videoObject - structure with properties of video (obtained using
% video_params function).
% vwrite - videowriter object
% start_frame - definition of the global frame (first frame of strating)
% number_of_markers - number of markers. Default - 8
% ifplot - to plot or not plot the data
%
% =========================================================================
function tracking_data = videotracker(videoObject,...
    vwrite,start_frame,number_of_markers,ifplot)

% Setup other parameters
numberOfFrames = videoObject.NumberOfFrame;

figure(1)
for k = start_frame : numberOfFrames   
tic
    if k == start_frame
        centroids = zeros(numberOfFrames,3*number_of_markers);
        newPrevPt = zeros(number_of_markers,3);
        regions = zeros(numberOfFrames,1);  
    end
    
        thisFrame = read(videoObject,k);
%         thisFrame = imcrop(thisFrame,[250,0,1920,1080]);
%         if k == start_frame
%             thisFrame = imcrop(thisFrame,[90,120,640,320]);
%         else
%             thisFrame = imcrop(thisFrame,[90,120,640,320]);
%         end
%         newim = createMaskfixedblue3(thisFrame);
%         newim = createMaskCarpetBlue(thisFrame);
          newim = createMaskhdblue(thisFrame);
%         newim = createMasktemp(thisFrame);
%         newim = createMaskpink2(thisFrame);
%         newim = createMaskpink4(thisFrame);
%         newim = createMaskHarishPink(thisFrame);

        if k == start_frame
            newim = bwareaopen(newim,20);
        else
            newim = bwareaopen(newim,10);
        end
        newim = imfill(newim, 'holes');
        axis on;
        
        [labeledImage, numberOfRegions] = bwlabel(newim);
        frame(k,:) = numberOfRegions;       
        count = 0;
        cent = [];
        stats = regionprops(labeledImage, 'BoundingBox','Centroid','Area','EquivDiameter');
                 for rb = 1:numberOfRegions
                     count = count + 1;
                     cent(count,:) = stats(rb).Centroid;
                     cent(count,2) = 1080 - cent(count,2) ;  % Correction for y-axis.
                 end
        zc = zeros(size(cent,1),1);
        cent = [cent,zc];
        
        if k == start_frame
            P0 = cent;
            PrevPt = cent;
                for i = 1:number_of_markers
                    centroids(k,(3*i)-2:(3*i)) = P0(i,:);
                end
        end


  % Cent is available here. This will be the new one.
  % PPt is also available here.
 
  if k ~= start_frame && count > number_of_markers
      resrvd = zeros(number_of_markers,3);
      for i = 1:number_of_markers
          for j = 1:count
              X = [PrevPt(i,:);cent(j,:)];
              d(j) = pdist(X,'euclidean');
          end
              [dmin,ind] = min(d);  
              if(dmin < 15)
              resrvd(i,:) = cent(ind,:);
              end
      end
  end
 
   
  if k ~= start_frame && count <= number_of_markers
      resrvd = zeros(number_of_markers,3);
      for i = 1:count
          for j = 1:number_of_markers
              X = [cent(i,:);PrevPt(j,:)];
              d(j) = pdist(X,'euclidean');
          end
                [dmin,ind] = min(d);
                if(dmin < 15)
                   resrvd(ind,:) = cent(i,:);
                end
      end
  end
 
if k ~= start_frame
% Calculation of rotation matrix and translation
TF = resrvd(:,1);  % Writing the 1st column of resrvd
index = find(TF == 0);  % Finding those rows which is empty
val = isempty(index);   % Checking whether the index is empty
newPrevPt = PrevPt;
newP0 = P0;             % 1st point
if(val == 0)            % That means checking for index whether it is empty(if yes val is 1 or val is 0)
newPrevPt(index(1:size(index,1)),:) = 0;
newP0(index(1:size(index,1)),:) = 0;      %
end
[Rot,T] = rigid_transform_3D(newPrevPt', resrvd');  % SE2 w.r.t previous frame

theta(k,:) = reshape(Rot,[1,9]);   % Changed ANM
trans(k,:) = T';

if(val == 0)
    for gg = 1:size(index,1)
        newPt = Rot*(PrevPt(index(gg),:))' + T;
        resrvd(index(gg),:) = newPt;
    end
end

[Rot_G,T_G] = rigid_transform_3D(P0', resrvd');  % SE2 w.r.t 1st frame

theta_G(k,:) = reshape(Rot_G,[1,9]);   % Rotation matrix w.r.t 1st frame
trans_G(k,:) = T_G';                   % Translation matrix w.r.t 1st frame

PrevPt = resrvd;
clear d;
% In the respective centroid variables
    for i = 1:number_of_markers
      centroids(k,(3*i)-2:(3*i)) = resrvd(i,:);
    end
end
if ifplot
    % Plotting the points
    imshow(thisFrame)
%     set(gcf, 'Position',  [100, 100, 750, 400])
    set(gcf, 'Position',  [100, 100, 1000, 1000])
%     set(gca,'XLim',[0 700],'YLim',[0 700]);
    hold on
    plot(PrevPt(:,1),PrevPt(:,2),'g*','LineWidth',0.5,'MarkerSize',2)
%     mean_centroid = mean(PrevPt);
    % plot([PrevPt(1,1) PrevPt(2,1)], [PrevPt(1,2) PrevPt(2,2)],'LineWidth',1.5)
    % h = animatedline('LineStyle','-','Color','b','LineWidth',1.5);
    caption = sprintf('%d blobs found in frame #%d 0f %d', count, k, numberOfFrames);
    title(caption, 'FontSize', 20);
%     h = animatedline('Marker','o','Color','b','MarkerSize',1,'MarkerFaceColor','b');
%     h2 = animatedline('LineStyle','-','Color','r','LineWidth',1.5);
%     addpoints(h,mean_centroid(1,1),mean_centroid(1,2))
%     drawnow;
    axis on
    hold off
end
toc 
pframe = getframe(gcf);
writeVideo(vwrite,pframe);
end
% Collectively writing all the tracked points in a single variable.
tracking_data = cat(2,centroids,theta,trans,theta_G,trans_G);
end

 function code = Environment_Switch_BH_DMDmulti_20231209
% generic   Code for a generic VR experiment
%   code = generic   Returns handles to the functions that ViRMEn
%   executes during engine initialization, runtime and termination.


% Begin header code - DO NOT EDIT
code.initialization = @initializationCodeFun;
code.runtime = @runtimeCodeFun;
code.termination = @terminationCodeFun;
% End header code - DO NOT EDIT



% --- INITIALIZATION code: executes before the ViRMEn engine starts.
function vr = initializationCodeFun(vr)
vr.rig.isAcquiring = true;
tt=clock; t = datetime(tt);
t.Format='yyMMddHHmm';
fpath_target='C:\Users\Labmember\Data\ByungHun\';
vr.give_water=1;
vr.lickVoltage=0;
vr.lapmessage=sprintf('Current lap is %d',0);
vr.startTime = now;
vr.time=[];
filename=input('File name is :','s');
filename=char(filename);
% Set up plots
vr.plotSize = 0.15;
scr = get(0,'screensize');
aspectRatio = scr(3)/scr(4)*.85;
vr.plotX = (aspectRatio+1)/2;
vr.plotY = 0.75;

if isequal(vr.exper.movementFunction, @runFromRecording)
    % read from file

    vr.fid = fopen([fpath_target char(t) 'virmenLog.data'],'r');
    vr.data = fread(vr.fid,[11 inf],'double');
    vr.recordedPositions = vr.data(3:6,:);
    % transpose
    vr.recordedPositions = vr.recordedPositions';
    vr.trialNumber=1;
else
    %initial conditions
    vr.trialNumber=1;
    vr.NDMDpattern=1; %multiply cell# and number of stimulation
    vr.stim_given=zeros(1,vr.NDMDpattern);
    vr.reward_given=0;
    vr.zap_time=1;
    vr.endPosition = 115;
    vr.World_change_lap=2;
    vr.reward_pos=[repmat(vr.endPosition*0.4,1,vr.World_change_lap-1) repmat(vr.endPosition*0.8,1,1e4)];
    %first/second environment reward pos
    %stimulation lap
    %vr.stim_lap={[6],[7],[12],[13],[18],[19],[24],[25]};
    vr.stim_lap={[15]};
    %vr.pulse_type=[0 0 0 0 1 1 1 1]; %0=constant, 1=pulsed
    vr.pulse_type=[0]; %0=constant, 1=pulsed
    if length(vr.stim_lap)~=vr.NDMDpattern
        error("Number of stim_lap and NDMDpattern doesn't match")
    end
    %stimulation_position
    %vr.zap_pos=vr.endPosition*[0.2 0.2 0.6 0.6 0.2 0.2 0.6 0.6];
    vr.zap_pos=vr.endPosition*[0.5];
    if length(vr.zap_pos)~=vr.NDMDpattern
        error("Number of zap_pos and NDMDpattern doesn't match")
    end
    vr.lapmessage=[];
    vr.rig.BlueOn=0;
    vr.rig.initializeDaq('Dev3');
   vr.fid = fopen([fpath_target char(t) '_' filename '_virmenLog.data'],'w');
end

vr.zap_map=zeros(vr.NDMDpattern,max(cell2mat(vr.stim_lap)));
for D=1:vr.NDMDpattern
vr.zap_map(D,vr.stim_lap{D})=1;
end
vr.dmdsequence=mod(find(vr.zap_map),vr.NDMDpattern); vr.dmdsequence(vr.dmdsequence==0)=vr.NDMDpattern;

vr.NDMDtrigger=mod(vr.dmdsequence(2:end)-vr.dmdsequence(1:end-1),vr.NDMDpattern);
vr.NDMDtrigger(vr.NDMDtrigger==0)=vr.NDMDpattern;
vr.NDMDtrigger=2*vr.NDMDtrigger-1;
vr.triggInd=1;




% --- RUNTIME code: executes on every iteration of the ViRMEn engine.
function vr = runtimeCodeFun(vr)

if vr.trialNumber < vr.World_change_lap
    vr.currentWorld=1;
else
    vr.currentWorld=2;
end

if (vr.rig.shouldResetPosition) % Reset position
    vr.position(1:4) = vr.worlds{vr.currentWorld}.startLocation;
    vr.rig.shouldResetPosition = false;
    %vr.position(2)=endPosition+1;
end

if vr.position(2) > vr.endPosition % if the animal is at the end of the track
    vr.position(2)=vr.worlds{vr.currentWorld}.startLocation(2); % set the animal2s y position to start position
    vr.dp(:) = 0; % prevent any additional movement during teleportation
    vr.trialNumber = vr.trialNumber + 1;
    vr.ID=1;
    vr.reward_given(vr.trialNumber)=0;
    vr.stim_given(vr.trialNumber,1:vr.NDMDpattern)=zeros(1,vr.NDMDpattern);
    %fprintf(repmat('\b', 1, length(vr.lapmessage))); % Erase the old message
    vr.lapmessage = sprintf('Current lap is %d \n', vr.trialNumber);
    fprintf(vr.lapmessage)

if ismember(vr.trialNumber-1,unique(cell2mat(vr.stim_lap)))
    if ~isempty(vr.timer2)
    start(vr.timer2);
    wait(vr.timer2);
    end
end
end

if vr.position(2) <vr.worlds{vr.currentWorld}.startLocation(2) %if the animal trying to go back right after the teleport
    vr.position(2) = vr.worlds{vr.currentWorld}.startLocation(2);
    vr.dp(:) = 0; % prevent any additional movement during teleportation
end

% Reward
if vr.position(2)>vr.reward_pos(vr.trialNumber) && vr.reward_given(vr.trialNumber)==0
    vr.rig.reward();
    %vr.rig.SendVU();
    vr.reward_given(vr.trialNumber)=1;
end

% Open Blue
if ismember(vr.trialNumber,unique(cell2mat(vr.stim_lap)))
ROItoStim = cellfun(@(x) any(x == vr.trialNumber), vr.stim_lap);
D=find(ROItoStim);
    if vr.position(2)>vr.zap_pos(D) && vr.stim_given(vr.trialNumber,D)==0
        vr.tempT=datetime(datetime(now,'ConvertFrom','datenum'), 'InputFormat', 'yyyy-MM-dd HH:mm:ss.SSS');
        vr.stim_given(vr.trialNumber,D)=1;
        vr.rig.DMDtrigg();
        switch vr.pulse_type(D)
            case 2
            pulsefunction= @(~,~) vr.rig.zap_pulse_short();
            t_pulse_short = timer('TimerFcn', pulsefunction,'Period', 0.067, 'ExecutionMode', ...
                  'fixedRate', 'TasksToExecute', 15);
            start(t_pulse_short);
            disp(['Short Pulse Stimulation is given at lap #' num2str(vr.trialNumber) ' ' num2str(vr.zap_pos(D)) '(VR unit)' 'with DMD#' num2str(D)])

            case 1
            pulsefunction= @(~,~) vr.rig.zap_pulse();
            t_pulse = timer('TimerFcn', pulsefunction,'Period', 0.15, 'ExecutionMode', ...
                  'fixedRate', 'TasksToExecute', 6);
            start(t_pulse);
            disp(['Pulse Stimulation is given at lap #' num2str(vr.trialNumber) ' ' num2str(vr.zap_pos(D)) '(VR unit)' 'with DMD#' num2str(D)])
        case 0
            vr.rig.zap();
            disp(['Square Stimulation is given at lap #' num2str(vr.trialNumber) ' ' num2str(vr.zap_pos(D)) '(VR unit)' 'with DMD#' num2str(D)])
        end

        timerfunction= @(~,~) vr.rig.DMDtrigg();
        t = timer;
        t.StartDelay = vr.zap_time;            
        t.TimerFcn = @(~,~) vr.rig.DMDtrigg();
        start(t);
        if vr.triggInd<sum(vr.zap_map(:))
        if vr.NDMDtrigger(vr.triggInd)>1 
         vr.timer2 = timer('TimerFcn', timerfunction,'StartDelay',0.5,'Period', 0.05, 'ExecutionMode', ...
                  'fixedRate', 'TasksToExecute', vr.NDMDtrigger(vr.triggInd)-1);
        else
         vr.timer2=[];   
        end
        else
        vr.timer2=[];  
        end

        vr.triggInd=vr.triggInd+1;
        %vr.position(2)
        %vr.triggInd        
end
% if vr.stim_given(vr.trialNumber,D)
% if seconds(t_now-vr.tempT)>1.5
%             start(timer2);
%         wait(timer2);
%         vr.ID=vr.ID+1;
% end
% end

end

% plot lick
 t2=datetime(datetime(now,'ConvertFrom','datenum'), 'InputFormat', 'yyyy-MM-dd HH:mm:ss.SSS');
  vr.time=[vr.time second(t2-vr.startTime)];
  if length(vr.lickVoltage)<100
vr.plot(1).x = rescale(vr.time)*vr.plotSize+vr.plotX;
vr.plot(1).y = vr.lickVoltage*vr.plotSize+vr.plotY;
vr.plot(1).color = [1 0 1];
else
vr.plot(1).x = rescale(vr.time(end-99:end))*vr.plotSize+vr.plotX;
vr.plot(1).y = vr.lickVoltage(end-99:end)*vr.plotSize+vr.plotY;
vr.plot(1).color = [1 0 1];    
end


timestamp = now;
CamTrigger = read(vr.rig.SendMicroscope, 1, "OutputFormat", "Matrix");
warning('off','all')
vr.lickVoltage = [vr.lickVoltage read(vr.rig.waterSession, 1, "OutputFormat", "Matrix")]; 
% write timestamp and the x & y components of position and velocity to a file
% using floating-point precision
fwrite(vr.fid, [timestamp vr.currentWorld vr.rig.latestEncoderReading ...
       vr.position vr.trialNumber vr.lickVoltage(end) CamTrigger],'double');



% --- TERMINATION code: executes after the ViRMEn engine stops.
function vr = terminationCodeFun(vr)
%if (vr.rig.isRecording)
%    filepath = fileparts(which('virmenLog.data')) + "\virmenLog.data"
%    writeline(vr.rig.server, filepath)
    fclose(vr.fid);
     vr.rig.delete();
%end

 function code = Environment_Switch_BH
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
tt=clock; t = datetime(tt);
t.Format='yyMMddHHmm';
fpath_target='C:\Users\Labmember\Data\ByungHun\';

if isequal(vr.exper.movementFunction, @runFromRecording)
    % read from file

    vr.fid = fopen([fpath_target char(t) 'virmenLog.data'],'r');
    vr.data = fread(vr.fid,[12 inf],'double');
    vr.recordedPositions = vr.data(3:6,:);
    % transpose
    vr.recordedPositions = vr.recordedPositions';
    vr.trialNumber=1;
else
    %initial conditions
    vr.trialNumber=1;
    vr.stim_given=0;
    vr.reward_given=0;
    vr.endPosition = 115;
    vr.World_change_lap=3;
    vr.reward_pos=[repmat(vr.endPosition*0.3,1,vr.World_change_lap-1) repmat(vr.endPosition*0.8,1,1e4)];
    %first/second environment reward pos
    %stimulation lap
    vr.stim_lap=[4:7];
    %stimulation_position
    vr.zap_pos=vr.endPosition*0.3;
    vr.lapmessage=[];
    
    vr.rig.initializeDaq('Dev3');
    write(vr.rig.moveSession, [0]);
    vr.fid = fopen([fpath_target char(t) 'virmenLog.data'],'w');
end




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
    if vr.trialNumber == vr.stim_lap(1)
    write(vr.rig.moveSession, [1]);
    end
    vr.reward_given(vr.trialNumber)=0;
    vr.stim_given(vr.trialNumber)=0;
    %fprintf(repmat('\b', 1, length(vr.lapmessage))); % Erase the old message
    vr.lapmessage = sprintf('Current lap is %d \n', vr.trialNumber);
    fprintf(vr.lapmessage)
    if vr.trialNumber >= vr.stim_lap(end)
    write(vr.rig.moveSession, [0]);
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

if ismember(vr.trialNumber,vr.stim_lap)
    
    if vr.position(2)>vr.zap_pos && vr.stim_given(vr.trialNumber)==0
        vr.stim_given(vr.trialNumber)=1;
        vr.rig.zap_off();
        disp(['Stimulation is given at lap #' num2str(vr.trialNumber) ' ' num2str(vr.zap_pos) '(VR unit)'])
    end
end

timestamp = now;
CamTrigger = read(vr.rig.SendMicroscope, 1, "OutputFormat", "Matrix");
LickVoltage = read(vr.rig.waterSession, 1, "OutputFormat", "Matrix");  
% write timestamp and the x & y components of position and velocity to a file
% using floating-point precision
fwrite(vr.fid, [timestamp vr.currentWorld vr.rig.latestEncoderReading ...
       vr.position vr.trialNumber LickVoltage CamTrigger],'double');



% --- TERMINATION code: executes after the ViRMEn engine stops.
function vr = terminationCodeFun(vr)
%if (vr.rig.isRecording)
%    filepath = fileparts(which('virmenLog.data')) + "\virmenLog.data"
%    writeline(vr.rig.server, filepath)
%    fclose(vr.fid);
%end

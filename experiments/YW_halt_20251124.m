function code =YW_halt_20251124
% generic   Code for a generic VR experiment
%   code = generic   Returns handles to the functions that ViRMEn
%   executes during engine initialization, runtime and termination.


% Begin header code - DO NOT EDIT
code.initialization = @initializationCodeFun;
code.runtime = @runtimeCodeFun;
code.termination = @terminationCodeFun;
warning('off','MATLAB:subscripting:noSubscriptsSpecified');
% End header code - DO NOT EDIT


end
% --- INITIALIZATION code: executes before the ViRMEn engine starts.
function vr = initializationCodeFun(vr)
vr.rig.isAcquiring = true;
tt=clock; t = datetime(tt);
t.Format='yyMMddHHmm';
fpath_target='D:\Labmember\Data\Yangdong Wang\Optopatch\VRlogs\';
vr.give_water=1;
vr.fake_rate=0; %80% of the lap will be rewarded
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
vr.reward_pos_world=[0.42 0.24 0.69];
vr.reward_pos=vr.reward_pos_world(randi([1 3],1,100000));
vr.UIupdateCounter = 0;
vr.rig.initializeDaq('Dev4');
vr.rig.enableRewardUI();
vr.endPosition=110;
vr.r_av=ones(1,100000);
vr.fid = fopen([fpath_target char(t) '_' filename '_virmenLog.data'],'w');
vr.ishalt = 0;
vr.position_athalt = 0;
if vr.fid == -1
    error('Failed to open log file for writing.');
end
end



% --- RUNTIME code: executes on every iteration of the ViRMEn engine.
function vr = runtimeCodeFun(vr)
endPosition = 110;
if (vr.rig.shouldResetPosition)
    vr.position(1:4) = vr.worlds{vr.currentWorld}.startLocation;
    vr.rig.shouldResetPosition = false;
    vr.position(2)=endPosition+1;
end

vr.rig.updateMonitoring();
% trackLength = eval(vr.exper.variables.fullLength);

if vr.position(2) > vr.endPosition % if the animal is at the end of the track
    vr.position(2)=vr.worlds{vr.currentWorld}.startLocation(2); % set the animal2s y position to start position
    vr.dp(:) = 0; % prevent any additional movement during teleportation
    vr.trialNumber = vr.trialNumber + 1;
    vr.ID=1;
    vr.reward_given(vr.trialNumber)=0;
    vr.stim_given(vr.trialNumber)=0;
    % vr.lapmessage = sprintf('Current lap is %d \n', vr.trialNumber);
    fprintf(vr.lapmessage)
end

if vr.position(2) <1 % test if the animal is at the end of the track
    %vr.rig.reward();
    vr.position(2) = 1; % set the animal-s y position to 0
    vr.dp(:) = 0; % prevent any additional movement during teleportation
end

VR_trigger = read(vr.rig.SendMicroscope, 1, "OutputFormat", "Matrix");
if VR_trigger
    Random_delay=randi([1 500],1); % this is the delay prior to the halt signal
    pausetimer = timer;
    pausetimer.StartDelay = Random_delay/1000;
    pausetimer.TimerFcn = @(~,~)halt(vr);
    start(pausetimer);

end


if vr.textClicked == 1 % check if textbox #1 has been clicked
    vr.rig.reward();
end
% reward
if vr.trialNumber>1
    if vr.position(2)>vr.reward_pos(vr.trialNumber+1)*vr.endPosition && vr.r_av(vr.trialNumber+1)==1
        vr.rig.reward();
        vr.r_av(vr.trialNumber+1)=0;
        vr.reward_pos(vr.trialNumber+1)=0;
        fprintf(repmat('\b', 1, length(vr.lapmessage))); % Erase the old message
        vr.lapmessage = sprintf('Current lap is %d \n', vr.trialNumber);
        fprintf(vr.lapmessage);
    end
end

vr.UIupdateCounter = vr.UIupdateCounter + 1;
if vr.UIupdateCounter >= 30  % update every 10 calls
    if isprop(vr.rig, 'infoLabels') && isfield(vr.rig.infoLabels, 'lap') && isvalid(vr.rig.infoLabels.lap)
        vr.rig.infoLabels.lap.Text = sprintf('Lap: %d', vr.trialNumber);
        vr.rig.infoLabels.world.Text = sprintf('World: %d', vr.currentWorld);
        vr.rig.infoLabels.Position.Text = sprintf('Position: %.2f', vr.position(2));
    end
    vr.UIupdateCounter = 0;  % reset
end


t2=datetime(datetime(now,'ConvertFrom','datenum'), 'InputFormat', 'yyyy-MM-dd HH:mm:ss.SSS');
vr.time=[vr.time second(t2-vr.startTime)];

timestamp = now;

lick = read(vr.rig.waterSession, 1, "OutputFormat", "Matrix");
vr.lickVoltage = lick(1);
fwrite(vr.fid, [timestamp vr.currentWorld vr.rig.latestEncoderReading ...
    vr.position vr.trialNumber vr.lickVoltage vr.ishalt vr.position_athalt VR_trigger],'double');
end



% --- TERMINATION code: executes after the ViRMEn engine stops.
function vr = terminationCodeFun(vr)
if (vr.rig.isAcquiring)
    disp('Session ends')
    %filepath = fileparts(which('virmenLog.data')) + "\virmenLog.data"
    %writeline(vr.rig.server, filepath)
    fclose(vr.fid);
    vr.rig.delete();

end
end

function halt(obj)
% Turn on microscope flag and halt flag
write(obj.moveSession, 1);
obj.ishalt         = 1;

% Remember where to freeze (make this a property on obj!)
obj.position_athalt = obj.position(2);

% Create a one-shot timer that will clear the halt after 500 ms
halttimer = timer( ...
    'ExecutionMode', 'singleShot', ...
    'StartDelay',    0.5, ...   % 500 ms
    'TimerFcn',      @(~,~) clear_halt(vr), ...
    'Tag',           'halt_timer');

start(halttimer);
end

function clear_halt(obj)
% This is what you asked for: just set ishalt to 0
obj.ishalt         = 0;
obj.sendmicroscope = 0;   % optional: also turn off microscope flag
end

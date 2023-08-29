function code =BH_shaping_SpatialCue
% generic   Code for a generic VR experiment
%   code = generic   Returns handles to the functions that ViRMEn
%   executes during engine initialization, runtime and termination.


% Begin header code - DO NOT EDIT
code.initialization = @initializationCodeFun;
code.runtime = @runtimeCodeFun;
code.termination = @terminationCodeFun;
warning('off','MATLAB:subscripting:noSubscriptsSpecified');
% End header code - DO NOT EDIT



% --- INITIALIZATION code: executes before the ViRMEn engine starts.
function vr = initializationCodeFun(vr)
vr.rig.isAcquiring = true;
tt=clock; t = datetime(tt);
t.Format='yyMMddHHmm';
fpath_target='C:\Users\Labmember\Data\ByungHun\';
vr.give_water=1;
vr.fake_rate=0.2; %80% of the lap will be rewarded
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


if isequal(vr.exper.movementFunction, @runFromRecording)
    % read from file
    
     vr.fid = fopen([fpath_target char(t) 'virmenLog.data'],'r');
    vr.data = fread(vr.fid,[7 inf],'double');
    vr.recordedPositions = vr.data(3:6,:);
    % transpose
    vr.recordedPositions = vr.recordedPositions';
else
    vr.rig.initializeDaq('Dev3');
    vr.fid = fopen([fpath_target char(t) '_' filename '_virmenLog.data'],'w');
end



% --- RUNTIME code: executes on every iteration of the ViRMEn engine.
function vr = runtimeCodeFun(vr)
endPosition = 110;
if (vr.rig.shouldResetPosition)
    vr.position(1:4) = vr.worlds{vr.currentWorld}.startLocation;
    vr.rig.shouldResetPosition = false;
    vr.position(2)=endPosition+1;
end

% trackLength = eval(vr.exper.variables.fullLength);

if vr.position(2) > endPosition % test if the animal is at the end of the track
    %vr.rig.reward();
    vr.currentWorld=3-mod(round(rand*100),3);
    vr.position(2) = 1; % set the animal2s y position to 0
    vr.dp(:) = 0; % prevent any additional movement during teleportation
    if (vr.rig.isAcquiring)
        vr.trialNumber = vr.trialNumber + 1;
        %vr.r_av(vr.trialNumber+1)=1; 
        vr.r_av(vr.trialNumber+1)=double(rand>vr.fake_rate); %random fake
        vr.give_water=vr.r_av(vr.trialNumber+1);
        %vr.reward_pos(vr.trialNumber+1)=(endPosition).*rand;
        vr.reward_pos(vr.trialNumber+1)=(endPosition).*vr.reward_pos_world(vr.currentWorld);
    end
end

if vr.position(2) <1 % test if the animal is at the end of the track
    %vr.rig.reward();
    vr.position(2) = 1; % set the animal-s y position to 0
    vr.dp(:) = 0; % prevent any additional movement during teleportation
end

if vr.textClicked == 1 % check if textbox #1 has been clicked
     vr.rig.reward();
end
% reward
if vr.trialNumber>1
if vr.position(2)>vr.reward_pos(vr.trialNumber+1) && vr.r_av(vr.trialNumber+1)==1
    vr.rig.reward();
    vr.r_av(vr.trialNumber+1)=0;
    vr.reward_pos(vr.trialNumber+1)=0;
      fprintf(repmat('\b', 1, length(vr.lapmessage))); % Erase the old message
    vr.lapmessage = sprintf('Current lap is %d', vr.trialNumber);
    fprintf(vr.lapmessage);
end
end
% fake reward
  t2=datetime(datetime(now,'ConvertFrom','datenum'), 'InputFormat', 'yyyy-MM-dd HH:mm:ss.SSS');
  vr.time=[vr.time second(t2-vr.startTime)];
% if seconds(t2-vr.t1)>vr.fake_reward_time
%     vr.rig.reward_fake();
%     vr.fake_reward_time=0.5;
%     vr.t1=t2;
% end
% figure(1);
% clf;
if length(vr.lickVoltage)<100
vr.plot(1).x = rescale(vr.time)*vr.plotSize+vr.plotX;
vr.plot(1).y = vr.lickVoltage*vr.plotSize+vr.plotY;
vr.plot(1).color = [1 0 1];
else
vr.plot(1).x = rescale(vr.time(end-99:end))*vr.plotSize+vr.plotX;
vr.plot(1).y = vr.lickVoltage(end-99:end)*vr.plotSize+vr.plotY;
vr.plot(1).color = [1 0 1];    
end

% Update time text box
%vr.text(2).string = ['TIME ' datestr(now-vr.startTime,'MM.SS')];


if (vr.rig.isAcquiring)
    timestamp = now;
    vr.lickVoltage = [vr.lickVoltage read(vr.rig.waterSession, 1, "OutputFormat", "Matrix")];    

    % write timestamp and the x & y components of position and velocity to a file
    % using floating-point precision
    fwrite(vr.fid, [timestamp vr.give_water vr.position vr.lickVoltage(end) vr.trialNumber vr.currentWorld],'double');

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

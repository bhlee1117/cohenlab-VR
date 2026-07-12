function code =BH_shaping_SpatialCue_20260705
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
        fpath_target=['D:\Labmember\Data\ByungHun\VRlogs\' datestr(now, 'yyyymmdd') '\'];
        if ~exist(fpath_target, 'dir')
            mkdir(fpath_target);
        end

        vr.give_water=1;
        vr.fake_rate=0.2; %80% of the lap will be rewarded
        vr.lickVoltage=0;
        vr.lapmessage=sprintf('Current lap is %d \n',0);
        vr.startTime = now;
        vr.time=[];
        filename=input('File name is :','s');
        filename=char(filename);

        vr.trialNumber=1;
        vr.reward_given = zeros(1, 10000);
        vr.endPosition = 115;
        vr.World_seq=randi([1 3],1,10000);
        vr.give_water=rand(1,10000)>vr.fake_rate;
        vr.rig.nReward=0;

        vr.reward_pos_world=[0.42 0.24 0.69];
        vr.reward_pos=vr.reward_pos_world(vr.World_seq)*vr.endPosition;
        vr.UIupdateCounter = 0;
        vr.rig.initializeDaq('Dev4');
        vr.rig.enableRewardUI();
        vr.fid = fopen([fpath_target char(t) '_' filename '_virmenLog.data'],'w');
        if vr.fid == -1
            error('Failed to open log file for writing.');
        end
    end

% --- RUNTIME code: executes on every iteration of the ViRMEn engine.
    function vr = runtimeCodeFun(vr)
        vr.currentWorld=vr.World_seq(vr.trialNumber);
        vr.rig.updateMonitoring();

        if (vr.rig.shouldResetPosition) % Reset position
            vr.position(1:4) = vr.worlds{vr.currentWorld}.startLocation;
            vr.rig.shouldResetPosition = false;
        end

        % trackLength = eval(vr.exper.variables.fullLength);

        if vr.position(2) > vr.endPosition % test if the animal is at the end of the track
            %vr.rig.reward();
            vr.position(2)=vr.worlds{vr.currentWorld}.startLocation(2); % set the animal2s y position to start position
            vr.dp(:) = 0; % prevent any additional movement during teleportation
            vr.trialNumber = vr.trialNumber + 1;
            vr.reward_given(vr.trialNumber)=0;
            vr.lapmessage = sprintf('Current lap is %d \n', vr.trialNumber);
            fprintf(vr.lapmessage)            
        end

        if vr.position(2) <vr.worlds{vr.currentWorld}.startLocation(2) %if the animal trying to go back right after the teleport
            vr.position(2) = vr.worlds{vr.currentWorld}.startLocation(2);
            vr.dp(:) = 0; % prevent any additional movement during teleportation
        end
        % reward
        if vr.position(2)>vr.reward_pos(vr.trialNumber) && vr.reward_given(vr.trialNumber)==0 && vr.give_water(vr.trialNumber)>0
            vr.rig.reward();
            vr.reward_given(vr.trialNumber)=1;
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

        timestamp = now;
        CamTrigger = read(vr.rig.SendMicroscope, 1, "OutputFormat", "Matrix");
        lick = read(vr.rig.waterSession, 1, "OutputFormat", "Matrix");
        vr.lickVoltage = lick(1);
        fwrite(vr.fid, [timestamp vr.currentWorld vr.rig.latestEncoderReading ...
            vr.position vr.trialNumber vr.lickVoltage CamTrigger],'double');
    end




% --- TERMINATION code: executes after the ViRMEn engine stops.
  function vr = terminationCodeFun(vr)
        fclose(vr.fid);
        vr.rig.delete();
    end
end
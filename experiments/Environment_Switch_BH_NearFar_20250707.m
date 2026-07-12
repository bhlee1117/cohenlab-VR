function code = Environment_Switch_BH_NearFar_20250707
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
        fpath_target=['D:\Labmember\Data\ByungHun\Optopatch\' datestr(now, 'yyyymmdd') '\'];
        if ~exist(fpath_target, 'dir')
            mkdir(fpath_target);
        end
        vr.give_water=1;
        vr.lickVoltage=0;
        vr.lapmessage=sprintf('Current lap is %d',0);
        vr.startTime = now;
        vr.time=[];
        filename=input('File name is :','s');
        filename=char(filename);

        %initial conditions
        vr.trialNumber=1;
        vr.NDMDpattern=1;
        vr.reward_given = zeros(1, 10000);
        vr.stim_given = zeros(1, 10000);
        vr.endPosition = 115;
        vr.World_seq=[1 1 1 repmat([1],1,10000)];
        reward_position=[0.4 0.8 0.42]*vr.endPosition; %Train, Far, Near;
        vr.reward_pos=reward_position(vr.World_seq);
        vr.lapmessage=[];
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

        if vr.position(2) > vr.endPosition % if the animal is at the end of the track
            vr.position(2)=vr.worlds{vr.currentWorld}.startLocation(2); % set the animal2s y position to start position
            vr.dp(:) = 0; % prevent any additional movement during teleportation
            vr.trialNumber = vr.trialNumber + 1;
            vr.ID=1;
            vr.reward_given(vr.trialNumber)=0;
            vr.stim_given(vr.trialNumber)=0;
            vr.lapmessage = sprintf('Current lap is %d \n', vr.trialNumber);
            fprintf(vr.lapmessage)
        end

        if vr.position(2) <vr.worlds{vr.currentWorld}.startLocation(2) %if the animal trying to go back right after the teleport
            vr.position(2) = vr.worlds{vr.currentWorld}.startLocation(2);
            vr.dp(:) = 0; % prevent any additional movement during teleportation
        end

        % Reward
        if vr.position(2)>vr.reward_pos(vr.trialNumber) && vr.reward_given(vr.trialNumber)==0
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

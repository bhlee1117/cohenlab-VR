classdef Rig < handle
    properties
        server
        isAcquiring
        shouldTerminate
        latestEncoderReading
        lastencoder_dig
        shouldResetPosition
        SendMicroscope
        waterSession
        %         fakePump
        moveSession
        encoderStart
        BlueOn
        controlFig
        analogPlotAxes
        analogLines
        digitalLamps
        plotTimer
        analogBuffer
        timeBuffer
        infoLabels
        nReward
    end
    methods
        function obj = Rig()
            obj.server = tcpserver(5001);
            obj.isAcquiring = false;
            obj.shouldTerminate = false;
            obj.shouldResetPosition = true;
            obj.encoderStart = 0;
            obj.latestEncoderReading = 0;
            obj.lastencoder_dig=[0 0];
            %obj.BlueOn=0;
            configureCallback(obj.server, "terminator", @(src,evt)readFcn(obj, src,evt));
        end
        function readFcn(obj,src,~)
            vr.message = readline(src);
            if (vr.message == "start")
                currentPosition = read(obj.moveSession, 1, "OutputFormat", "Matrix");
                obj.encoderStart = currentPosition;
                obj.isAcquiring = true;
                obj.shouldResetPosition = false;
                % resetcounters(rig.daq)
                % clear rig.daq;
                % rig.daq = daq("ni");
                % addinput(rig.daq, "Dev2", 'ctr0', 'EdgeCount');
            else
                %obj.shouldTerminate = true;
                obj.isAcquiring = false;
            end
            disp(vr.message);
        end
        function initializeDaq(obj, deviceName)
            daqreset;
            obj.waterSession = daq("ni"); % background operations
            obj.moveSession = daq("ni"); % on-demand operations
            obj.SendMicroscope=daq("ni");
            %             obj.fakePump=daq("ni");

            obj.waterSession.Rate = 100;
            obj.moveSession.Rate = 1000;
            obj.SendMicroscope.Rate= 1000;
            %             obj.fakePump.Rate= 1000;

            addinput(obj.moveSession, deviceName, 'ctr0', 'EdgeCount');
            addinput(obj.moveSession, deviceName, 'port1/line3', 'Digital'); % Direction (from Arduino)
            addoutput(obj.moveSession, deviceName, 'port1/line0', 'Digital'); % DMD

            addoutput(obj.waterSession, deviceName, 'ao0', 'Voltage'); % Pump
            addinput(obj.waterSession, deviceName, 'ai3', 'Voltage'); % Lick voltage

            %             addoutput(obj.fakePump, deviceName, 'ao1', 'Voltage');

            addinput(obj.SendMicroscope, deviceName, 'port1/line2', 'Digital'); % Acquire
            addinput(obj.SendMicroscope, deviceName, 'port0/line7', 'Digital'); % Reward Self
            addinput(obj.SendMicroscope, deviceName, 'port0/line6', 'Digital'); % Blue Self

        end
        function reward(obj)
            % for some reason, background signal output does not work
            % preload(obj.waterSession, [ones(1,100)*10 0]');
            % start(obj.waterSession);
            write(obj.waterSession, [10]);
            obj.nReward=obj.nReward+1;
            fprintf('Reward is given, # reward: %d\n',obj.nReward);
            t = timer;
            t.StartDelay = 0.07;
            t.TimerFcn = @(~,~)write(obj.waterSession, [0]);
            start(t);
        end

        function enableRewardUI(obj)
            obj.controlFig = uifigure('Name', 'Rig Control Panel', 'Position', [100 100 500 380]);

            uibutton(obj.controlFig, 'Text', 'Give Reward', 'Position', [40 200 200 150], 'ButtonPushedFcn', @(btn, event)obj.reward());
            uibutton(obj.controlFig, 'Text', 'Terminate VR', 'Position', [260 200 200 150], 'ButtonPushedFcn', @(btn, event)obj.terminateVR());

            obj.analogPlotAxes = uiaxes(obj.controlFig, 'Position', [30 30 300 150], 'XLim', [-5 0], 'YLim', [-10 10]);
            title(obj.analogPlotAxes, 'Analog Inputs');
            obj.timeBuffer = linspace(-5, 0, 100);
            obj.analogBuffer = zeros(1, 100);
            hold(obj.analogPlotAxes, 'on');
            obj.analogLines = plot(obj.analogPlotAxes, obj.timeBuffer, obj.analogBuffer, 'b');

            labels = {'Direction', 'Is acquiring', 'Reward', 'Blue'};
            obj.digitalLamps = gobjects(1, numel(labels));
            for i = 1:numel(labels)
                uilabel(obj.controlFig, 'Text', labels{i}, 'Position', [350 191 - 23*i 100 22]);
                obj.digitalLamps(i) = uilamp(obj.controlFig, 'Position', [460 191 - 23*i 20 20], 'Color', 'red');
            end

            obj.infoLabels.lap = uilabel(obj.controlFig, ...
                'Text', 'Lap: 0', ...
                'Position', [350 30 100 22]);

            obj.infoLabels.world = uilabel(obj.controlFig, ...
                'Text', 'World: 0', ...
                'Position', [350 53 100 22]);

            obj.infoLabels.Position = uilabel(obj.controlFig, ...
                'Text', 'Position: 0', ...
                'Position', [350 76 100 22]);

            obj.plotTimer = timer;
            obj.plotTimer.Period = 0.5;
            obj.plotTimer.ExecutionMode = 'fixedRate';
            obj.plotTimer.TimerFcn = @(~,~)obj.updateMonitoring();
            start(obj.plotTimer);
        end

        function updateDistancePerTurn(obj, newVal)
            disp(['Slider set distancePerTurn = ' num2str(newVal)]);
            if isvalid(obj.server)
                writeline(obj.server, sprintf('distancePerTurn:%.3f', newVal));
            end
        end

        function updateMonitoring(obj)
            if obj.shouldTerminate || isempty(obj.controlFig) || ~isvalid(obj.controlFig)
                return;
            end
            try
                analogData = read(obj.waterSession, 1, "OutputFormat", "Matrix");
                analogData = analogData(1); % Only ai3
                obj.analogBuffer = [obj.analogBuffer(2:end), analogData];
                obj.analogLines.YData = obj.analogBuffer;

                digitalValues = read(obj.moveSession, 1, "OutputFormat", "Matrix");
                digitalMicroscope = read(obj.SendMicroscope, 1, "OutputFormat", "Matrix");
                digStates = [digitalValues(2), digitalMicroscope(1:2), digitalMicroscope(3)];

                for i = 1:numel(obj.digitalLamps)
                    if isgraphics(obj.digitalLamps(i), 'uilamp')
                        obj.digitalLamps(i).Color = digStates(i) * [0 1 0] + (1 - digStates(i)) * [1 0 0];
                    end
                end
            catch e
                disp(['Monitor update failed: ' e.message]);
            end
        end

        %            function reward_fake(obj)
        %             % for some reason, background signal output does not work
        %             % preload(obj.waterSession, [ones(1,100)*10 0]');
        %             % start(obj.waterSession);
        %             write(obj.fakePump, [10]);
        %             t = timer;
        %             t.StartDelay = 0.03;
        %             t.TimerFcn = @(~,~)write(obj.fakePump, [0]);
        %             start(t);
        %            end

        function zap(obj)
            % trigger the shutter on the rig to open for 1 second
            write(obj.moveSession, [1]);
            %obj.BlueOn=1;
            t = timer;
            t.StartDelay = 1;
            t.TimerFcn = @(~,~)write(obj.moveSession, [0]);
            obj.BlueOn=0;
            start(t);
        end

        function zap_off(obj)
            % trigger the shutter on the rig to open for 1 second
            write(obj.moveSession, [0]);
            obj.BlueOn=0;
            t = timer;
            t.StartDelay = 1;
            t.TimerFcn = @(~,~)write(obj.moveSession, [1]);
            obj.BlueOn=1;
            start(t);
        end

        %         function SendVU(obj)
        %             % for some reason, background signal output does not work
        %             % preload(obj.waterSession, [ones(1,100)*10 0]');
        %             % start(obj.waterSession);
        %             write(obj.SendMicroscope, [1]);
        %             t = timer;
        %             t.StartDelay = 0.025;
        %             t.TimerFcn = @(~,~)write(obj.SendMicroscope, [0]);
        %             start(t);
        %         end

        function delete(obj)
            try
                stop(obj.waterSession);
                stop(obj.moveSession);
                stop(obj.SendMicroscope);
                stop(obj.plotTimer);
                delete(obj.plotTimer);
            catch
            end
            obj.server.delete();
        end

        function terminateVR(obj)
            disp('VR terminated by user.');
            obj.shouldTerminate = true;
            obj.isAcquiring = false;
            obj.server.delete();

            if isvalid(obj.controlFig)
                close(obj.controlFig);
            end
        end
    end
end
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
            addinput(obj.moveSession, deviceName, 'port1/line3', 'Digital');
            addoutput(obj.moveSession, deviceName, 'port1/line0', 'Digital');
      
            addoutput(obj.waterSession, deviceName, 'ao0', 'Voltage');
            addinput(obj.waterSession, deviceName, 'ai3', 'Voltage');

%             addoutput(obj.fakePump, deviceName, 'ao1', 'Voltage');

            addinput(obj.SendMicroscope, deviceName, 'port1/line2', 'Digital');
            addinput(obj.SendMicroscope, deviceName, 'port0/line7', 'Digital');
            addinput(obj.SendMicroscope, deviceName, 'port0/line6', 'Digital');

        end
        function reward(obj)
            % for some reason, background signal output does not work
            % preload(obj.waterSession, [ones(1,100)*10 0]');
            % start(obj.waterSession);
            write(obj.waterSession, [10]);
            t = timer;
            t.StartDelay = 0.05;
            t.TimerFcn = @(~,~)write(obj.waterSession, [0]);
            start(t);
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
            t.StartDelay = 0.5;
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
            catch
                % do nothing
            end
            obj.server.delete();
        end
    end
end
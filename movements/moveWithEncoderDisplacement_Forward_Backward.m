function [movement, movementType] = moveWithEncoderDisplacement_Forward_Backward(vr)
%forward = vr.daq.inputSingleScan;

encoder = read(vr.rig.moveSession, 1, "OutputFormat", "Matrix");
if encoder(1)~=vr.rig.lastencoder_dig(1)
    if encoder(2)==1
        dir=-1;
    else
        dir=1;
    end
else
    dir=1;
end
encoderDisplacement=dir*(encoder(1)-vr.rig.lastencoder_dig(1));
%datetime(clock,'Format','mm:ss:sss')
%currentEncoderReading2 = read(vr.rig.moveSession, 2, "OutputFormat", "Matrix")
%encoderDisplacement = currentEncoderReading - vr.rig.latestEncoderReading;
vr.rig.lastencoder_dig=encoder;
vr.rig.latestEncoderReading = vr.rig.latestEncoderReading + encoderDisplacement;
%fprintf('disp:%d, dir:%d\n',encoderDisplacement,dir);
%vr.rig.latestEncoderReading
% convert from encoder units to VR spatial units
    function transformedDisplacement = transformDisplacement(vr, encoderDisplacement)
        encoderCPR = 500; % clock cycles per rotation
        numTurns = encoderDisplacement/encoderCPR;
        circumference = eval(vr.exper.variables.distancePerTurn);
        totalDisplacement = numTurns * circumference;

        transformedDisplacement = [0, totalDisplacement, 0, 0]; % [x, y, z, view angle]
    end
movement = transformDisplacement(vr, encoderDisplacement);
movementType = 'd';
end
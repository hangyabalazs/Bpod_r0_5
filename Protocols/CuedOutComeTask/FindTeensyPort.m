function [TeensyPort] = FindTeensyPort
%FINDTEENSYPORT  Teensy Soundcard automatic recognition
% This code finds the current COMport of the Teensy Souncard via searching
% it in the raw string which contains all the available instruments (name,
% port, vendorID, productID etc..)
% 
% delete(instrfindall); %deleting former

[Status RawString] = system('wmic path Win32_SerialPort Where "PNPDeviceID LIKE ''%VID_16C0&PID_0483%''" Get DeviceID'); %Search for the available ports at the moment
PortLocations = strfind(RawString, 'COM'); %searching the COM word from the former string
TeensyPorts = cell(1,100);
nPorts = length(PortLocations);
for x = 1:nPorts
    Clip = RawString(PortLocations(x):PortLocations(x)+6);
    TeensyPorts{x} = Clip(1:find(Clip == 32,1, 'first')-1);
end
TeensyPort = TeensyPorts(1:nPorts);
function CuedOutComeTask
%CUEDOUTCOME Cued outcome task protocol
%

% Load Bpod variables
global BpodSystem

% Define parameters
S = BpodSystem.ProtocolSettings; % Load settings chosen in launch manager into current workspace as a struct called S
S = struct;
if isempty(fieldnames(S))  % If settings file was an empty struct, populate struct with default settings
    %GUI parameters
    S.GUI.NumTrialTypes = 2;   % different trial types corresponding different cues and outcome contingencies
    S.GUI.DirectWater = 10; %How many times do the animals receive 'free water' during the inintial training
    S.GUI.SinWavekHz1 = 10; % Cue tone #1 in kHz - tone #1
    S.GUI.SinWavedB1 = 40; % Cue tone #1 dB SPL
    S.GUI.SinWavekHz2 = 4; % Cue tone #2 in kHz - tone #2
    S.GUI.SinWavedB2 = 40; % Cue tone #2 dB SPL
    
    %Other Bpod Parameters for the protocol
    S.NoLick = 1.5; %s
    S.ITI = 1; % ITI duration is set to be exponentially distributed later
    S.SoundDuration = 1; % s
    S.RewardValveCode = 1;   % port #1 controls water valve
    S.PunishValveCode = 2;   % port #2 controls air valve
    S.RewardAmount = 3; % ul
    S.PunishValveTime = 0.2; % s
    S.RewardValveTime =  GetValveTimes(S.RewardAmount, S.RewardValveCode);
    S.DirectDelivery = 1; % 0 = 'no' 1 = 'yes'; controls whether a response is accepted in the delay period
    S.NoPunish = false;   % true = initial training: no airpuff
    S.Type1 = 0.5; %Probability of trial type 1
    S. Type2 = 0.5; %Probability of trial type 2
end
% Initialize parameter GUI plugin
BpodParameterGUI('init', S);

% Define trials
MaxTrials = 1000;
rng('shuffle')   % reset pseudorandom seed
TrialType1 = ones(1,(S.Type1*MaxTrials)); %Generates an array for trial type 1 in the given percentage S.Type1
TrialType2 = repmat(2,1,(S.Type2*MaxTrials)); %Generates an array for trial type 2 in the given percentage S.Type2

Trials = [TrialType1, TrialType2];
num_elements=length(Trials);
TrialTypes = randperm(num_elements);
out=zeros(1,num_elements);

%Generates the random array of the two trial types in the given percentage
for i=1:num_elements
    out(i)=Trials(TrialTypes(i));
end

%Defining outcome contingencies
p = rand(1,MaxTrials);   % control outcome contingencies
UsOutcome = zeros(size(Trials));

if S.GUI.NumTrialTypes == 1 %If there is only one type of trial (you can change the contingencies here)
    UsOutcome(p <= 0.8 & out == 1) = 1;  %TrialType1, 80% reward
    %     UsOutcome(p > 0.8 & p <= 0.9 & out == 1) = 2;    % Type #1: 10% punishmnet (10% omission)
else
    UsOutcome(p <= 0.8 & out == 1) = 1;  %TrialType1, 80% reward
    UsOutcome(p > 0.65 & p <= 0.9 & out == 2) = 1; %TrialType2, 25% reward, 10% omission
    if ~S.NoPunish
        UsOutcome(p > 0.8 & p <= 0.9 & out == 1) = 2;    % Type #1: 10% punishmnet (10% omission)
        UsOutcome(p <= 0.65 & out == 2) = 2; %TrialType2, 65% punishment
    end
    %     UsOutcome(p <= 0.85 & out == 1) = 1;  %TrialType1, 80% reward
    %     UsOutcome(p > 0.70 & p <= 0.9 & out == 2) = 1; %TrialType2, 25% reward, 10% omission
    %     if ~S.NoPunish
    %         UsOutcome(p > 0.85 & p <= 0.9 & out == 1) = 2;    % Type #1: 10% punishmnet (10% omission)
    %         UsOutcome(p <= 0.70 & out == 2) = 2; %TrialType2, 65% punishment
    %     end
    
end

% Define delays (variable delay between 400 and 600 ms)
Delaymin = 400; % ms
Delaymax = 600; % ms
T = randi([Delaymin, Delaymax], 1, MaxTrials );

Delay = T/1000;

BpodSystem.Data.Delay = Delay;
BpodSystem.Data.TrialTypes = []; % The trial type of each trial completed will be added here.


% Define stimuli and send to sound server
SF = 44100; % Sound card sampling rate
%
% [TeensyPort] = FindTeensyPort;
TeensySoundServer ( 'init' , 'COM26' )
FilePath = fullfile(BpodSystem.BpodPath,'Protocols','TeensyCalibration','TeensyCalData.mat');
load(FilePath); % Load Calibration data as a reference
%
% Tones 1 and 2 Creation
Tg1 = S.GUI.SinWavedB1; % Wanted dB for tone 1
Tg2 = S.GUI.SinWavedB2; % Wanted dB for tone 2
Fr1 = S.GUI.SinWavekHz1;
Fr2 = S.GUI.SinWavekHz2;
SPL1 = TeensyCalData.SPL(Fr1); % Recalls calibrated dB for the frequency of tone 1
SPL2 = TeensyCalData.SPL(Fr2); % Recalls calibrated dB for the frequency of tone 2
Ampl1 = TeensyCalData.Amplitude(Fr1); % Recalls calibrated amplitude for the tone 1 frequency
Ampl2 = TeensyCalData.Amplitude(Fr2); % Recalls calibrated amplitude for the tone 2 frequency
NewAmpl1  = AmplAdjst(SPL1,Tg1,Ampl1); % Calculates new amplitude for tone 1
NewAmpl2  = AmplAdjst(SPL2,Tg2,Ampl2); % Calculates new amplitude for tone 2
sinewave1  = NewAmpl1.*sin(2*pi*Fr1*1000/44100.*(0:44100*S.SoundDuration)); % Creates the sinewave of tone 1
sinewave2  = NewAmpl2.*sin(2*pi*Fr2*1000/44100.*(0:44100*S.SoundDuration)); % Creates the sinewaves of tone 2
TeensySoundServer ('loadwaveform', Fr1, sinewave1); % Uploads the sinewave for tone 1
TeensySoundServer ('loadwaveform', Fr2, sinewave2); % Uploads the sinewave for tone 2

% Main trial lopp
% for currentTrial = 1:5
% %         Pre-training protocol
%     
%     sma = NewStateMatrix();
%     sma = AddState(sma,'Name', 'Start', ...
%         'Timer', S.NoLick,...
%         'StateChangeConditions', {'Tup', 'WaitforLick','Port1In','Reward'},...
%         'OutputActions', {});
%     sma = AddState(sma,'Name', 'Reward', ...
%         'Timer',S.RewardValveTime,...
%         'StateChangeConditions', {'Tup', 'PostUS'},...
%         'OutputActions', {'ValveState', S.RewardValveCode});   % deliver water
%     sma = AddState(sma,'Name','WaitforLick',...
%         'Timer',0,...
%         'StateChangeConditions',{'Port1In','Reward'},...
%         'OutputActions',{});
%     sma = AddState(sma,'Name','PostUS',...
%         'Timer',1,...
%         'StateChangeConditions',{'Port1In','ResetDrinkingTimer','Tup','exit'},...
%         'OutputActions',{});   % drinking
%     sma = AddState(sma,'Name','ResetDrinkingTimer',...
%         'Timer',0,...
%         'StateChangeConditions',{'Tup','PostUS'},...
%         'OutputActions',{});   % keep the animal in PostUS until licking stops for 1 s
%     SendStateMatrix(sma);
%     
%     RawEvents = RunStateMatrix;
%     if ~isempty(fieldnames(RawEvents)) % If trial data was returned
%         BpodSystem.Data = AddTrialEvents(BpodSystem.Data,RawEvents); % Computes trial events from raw data
%         BpodSystem.Data.TrialSettings(currentTrial) = S; % Adds the settings used for the current trial to the Data struct (to be saved after the trial ends)
%         SaveBpodSessionData; % Saves the field BpodSystem.Data to the current data file
%     end
%     if currentTrial == 10
%         continue
%     end
%     HandlePauseCondition;
%     if BpodSystem.BeingUsed == 0
%         return
%         
%     end
% end

%         % Initialize plots
BpodSystem.ProtocolFigures.OutcomePlotFig = figure('Position', [400 400 1000 200],'Name','Outcome plot','numbertitle','off', 'MenuBar', 'none', 'Resize', 'off');
BpodSystem.GUIHandles.OutcomePlot = axes('Position', [.075 .3 .89 .6]);
OutcomePlot_Pavlov(BpodSystem.GUIHandles.OutcomePlot,'init',1-out, UsOutcome);

%Main trial loop
for currentTrial = 1:MaxTrials
    
    S = BpodParameterGUI('sync', S); % Synchronize the GUI
    
    
    cTg1 = S.GUI.SinWavedB1;
    cTg2 = S.GUI.SinWavedB2;
    cFr1 = S.GUI.SinWavekHz1;
    cFr2 = S.GUI.SinWavekHz2;
    
    if ~isequal(Tg1,cTg1) || ~isequal(Fr1,cFr1) % Controls if parameters for tone 1 are changed: if so, it is modified accordingly
        SPL1 = TeensyCalData.SPL(S.GUI.SinWavekHz1);
        Ampl1 = TeensyCalData.Amplitude(S.GUI.SinWavekHz1);
        NewAmpl1  = AmplAdjst(SPL1,cTg1,Ampl1);
        sinewave1  = NewAmpl1.*sin(2*pi*cFr1*1000/44100.*(0:44100*S.SoundDuration));
        TeensySoundServer ('loadwaveform', S.GUI.SinWavekHz1, sinewave1);
        Tg1 = cTg1;
        Fr1 = cFr1;
    end
    if  ~isequal(Tg2,cTg2) || ~isequal(Fr2,cFr2) % Controls if parameters for tone 2 are changed: if so, it is modified accordingly
        SPL2 = TeensyCalData.SPL(S.GUI.SinWavekHz2);
        Ampl2 = TeensyCalData.Amplitude(S.GUI.SinWavekHz2);
        NewAmpl2  = AmplAdjst(SPL2,cTg2,Ampl2);
        sinewave2  = NewAmpl2.*sin(2*pi*cFr2*1000/44100.*(0:44100*S.SoundDuration));
        TeensySoundServer ('loadwaveform', S.GUI.SinWavekHz2, sinewave2);
        Tg2 = cTg2;
        Fr2 = cFr2;
    end
    %
    %Audio Teensy
    if out(currentTrial) == 1
        Audio = Fr1;
    else
        Audio = Fr2;
    end
    
    % Outcome
    switch UsOutcome(currentTrial)
        case 1
            StateChangeArgument1 = 'Reward';  % UsOutcome = 1: reward
            if S.DirectDelivery == 1;
                StateChangeArgument2 = 'Reward';   % DirectDeivery: give water regardless of response
            else
                StateChangeArgument2 = 'PostUS';
            end
            
        case 2
            StateChangeArgument1 = 'Punish';   % UsOutcome = 2: punishment
            StateChangeArgument2 = 'Punish';
            
        case 0
            StateChangeArgument1 = 'PostUS';   % UsOutcome = 0: omission
            StateChangeArgument2 = 'PostUS';
    end
    
    
    % Inter-trial interval
    S.ITI = 10;
    while S.ITI > 3   % ITI dustribution: 1 + exponential, truncated at 4 s
        S.ITI = exprnd(1)+1;
    end
    
    S = BpodParameterGUI('sync', S); % Sync parameters with BpodParameterGUI plugin
    
    % Assemble state matrix
    sma = NewStateMatrix();
    sma = SetGlobalTimer(sma, 1, S.SoundDuration + Delay(currentTrial));
    sma = AddState(sma,'Name', 'NoLick', ...
        'Timer', S.NoLick,...
        'StateChangeConditions', {'Tup', 'ITI','Port1In','RestartNoLick'},...
        'OutputActions', {'PWM1', 255});
    sma = AddState(sma,'Name', 'RestartNoLick', ...
        'Timer', 0,...
        'StateChangeConditions', {'Tup', 'NoLick',},...
        'OutputActions', {'PWM1', 255});
    sma = AddState(sma, 'Name', 'ITI', ...
        'Timer',S.ITI,...
    'StateChangeConditions', {'Tup', 'StartStimulus','Port1In','RestartNoLick'},...
'OutputActions', {'PWM1', 255});  % 1 + exponential foreperiod < 4s

sma = AddState(sma, 'Name', 'StartStimulus', ...
    'Timer', S.SoundDuration,...
    'StateChangeConditions', {'Port1In','WaitForUS','Tup','Delay'},...
    'OutputActions', {'Serial1Code', Audio,'BNCState', 1, 'GlobalTimerTrig',1});   % play tone
sma = AddState(sma, 'Name','Delay', ...
    'Timer', Delay(currentTrial),...
    'StateChangeConditions', {'Port1In','WaitForUS','Tup',StateChangeArgument2},...
    'OutputActions', {'PWM1', 255});
sma = AddState(sma, 'Name', 'WaitForUS', ...
    'Timer',3,...
    'StateChangeConditions', {'GlobalTimer1_End', StateChangeArgument1},...
    'OutputActions', {'BNCState', 0,'PWM1', 255});   % wait for timer (1.2 s)
sma = AddState(sma,'Name', 'Reward', ...
    'Timer',S.RewardValveTime,...
    'StateChangeConditions', {'Tup', 'PostUS'},...
    'OutputActions', {'ValveState', S.RewardValveCode,'PWM1', 255});   % deliver water
sma = AddState(sma, 'Name', 'Punish', ...
    'Timer',S.PunishValveTime, ...
    'StateChangeConditions', {'Tup', 'PostUS'}, ...
    'OutputActions', {'ValveState', S.PunishValveCode,'PWM1', 255}); %deiliver air puff
sma = AddState(sma,'Name','PostUS',...
    'Timer',1,...
    'StateChangeConditions',{'Port1In','ResetDrinkingTimer','Tup','exit'},...
    'OutputActions',{'PWM1', 255});   % drinking
sma = AddState(sma,'Name','ResetDrinkingTimer',...
    'Timer',0,...
    'StateChangeConditions',{'Tup','PostUS'},...
    'OutputActions',{'PWM1', 255});   % keep the animal in PostUS until licking stops for 1 s
SendStateMatrix(sma);

RawEvents = RunStateMatrix;
if ~isempty(fieldnames(RawEvents)) % If trial data was returned
    BpodSystem.Data = AddTrialEvents(BpodSystem.Data,RawEvents); % Computes trial events from raw data
    BpodSystem.Data.TrialSettings(currentTrial) = S; % Adds the settings used for the current trial to the Data struct (to be saved after the trial ends)
    BpodSystem.Data.TrialTypes(currentTrial) = out(currentTrial); % Adds the trial type of the current trial to data
    Outcomes = UpdateOutcomePlot(out, BpodSystem.Data, UsOutcome); % update outcome plot
    BpodSystem.Data.TrialOutcome(currentTrial) = Outcomes(currentTrial);
    SaveBpodSessionData; % Saves the field BpodSystem.Data to the current data file
end
HandlePauseCondition;
if BpodSystem.BeingUsed == 0
    return
    
end

end

% -------------------------------------------------------------------------
function Outcomes = UpdateOutcomePlot(out, Data, UsOutcome)

% Load Bpod variables
global BpodSystem
Outcomes = zeros(1,Data.nTrials);

% Outcome
for x = 1:Data.nTrials
    Lick = ~isnan(Data.RawEvents.Trial{x}.States.WaitForUS(1)) ;
    if ~isnan(Data.RawEvents.Trial{x}.States.Reward(1)) && Lick == 1
        Outcomes(x) = 1;   % lick, reward
    elseif UsOutcome(x) == 1  && Lick ==0
        Outcomes(x) = 2;   % lick, no reward
    elseif ~isnan(Data.RawEvents.Trial{x}.States.Punish(1)) && Lick == 1
        Outcomes(x) = 0;   % lick, punish
    elseif ~isnan(Data.RawEvents.Trial{x}.States.Punish(1))
        Outcomes(x) = 4;   % no lick, punish
    elseif Lick == 1
        Outcomes(x) = 5;   % lick, omission
    else
        Outcomes(x) = 3;   % no lick, omission
    end
end
OutcomePlot_Pavlov(BpodSystem.GUIHandles.OutcomePlot,'update',Data.nTrials+1,1-out,Outcomes, UsOutcome)

function [CalAmpl] = AmplAdjst(SPL,Tg,Ampl) % Calculate the new proper sinewave amplitude
y = SPL - Tg;
b =  20 * log10(Ampl) - y;
c = b / 20;
CalAmpl = 10 .^ c;
function ScopeMath_Arduino
%ScopeMath_Arduino a simple oscilloscope for Arduino 
%
%   SCOPEMATH_ARDUINO was derived from SCOPEMATH_SIMPLE.
%   It displays data from the Analog channels of an Arduino 
%   Unlike other versions of ScopeMath, ScopeMath_Arduino does not use the Instrument Control Toolbox. 
%
% The user has the option to save the data to BrainVision Analyzer Format
%  You can analyze BrainVision files with EEGLAB, ELEcro, or other tools
%
% Arduino acquisition code is in startDeviceType1, getDataFromDeviceType1, stopDeviceType1 
% Simulated acquisition code is in startDeviceType0, getDataFromDeviceType0, stopDeviceType0 
%  This makes it easy to add a new deviceType, e.g. startDeviceType2, getDataFromDeviceType2, stopDeviceType2 
%
% THE ARDUINO MUST BE RUNNING THE SKETCH FROM
%   http://www.mccauslandcenter.sc.edu/CRNL/tools/oscilloscope
%
%   NOTE: This function requires MATLAB ver. 7.0 or later.  
%
%   Derived from ScopeMath_Simple (available on the MATLAB File Exchange) August-21-2007 (Gautam.Vallabha@mathworks.com)
%   Version 1.0 March-19-2013 (Chris Rorden)

hzChoices = [100 200 500 1000 2000]; %acquisition rate: maximum depends on hardware 
chChoices = [1 2 3 4 5 6]; %number of channels: maximum depends on hardware (Leonardo supports 6, Teensy3 supports 14)
saveDataDefault = 0; %if 1 data will be saved to disk by default, if 0 data will be discarded
hzDefaultIndex = 2; %e.g. if 2, 2nd option of HzChoices is the default
chDefaultIndex = 2; %e.g. if 2, 2nd option of ChChoices is the default
serDefaultIndex = 0; % 0 for auto-select, 1 for simulated data, 2 for Arduino on port 1, 3 for Arduino on port 3, etc
gGraphTotalTimeSec = 2; %e.g. if 1 then the last 1 second of data is displayed
%Typically no need to edit lines below.... 
gSecPerScreenRefresh = 0.1; %e.g. if 0.1 then screen is updated 10 times per second
deviceType = 0; %0 for simulated data, 1 for Arduino 
gOscHz = 100; %current sampling rate
gOscChannels = 1; %current number of channels we are recording
showPower = false; %should we conduct a FFT on recent data?
gSecPerSample = [];
gGraphSamples = []; 
xData = []; %time values for samples
yData = []; %most recent data channels*samples
gUnsavedData = []; %data not yet saved to disk
xUnits = 'Sec'; 
yUnits = 'Signal';
gSaveNumber = 1; %counts time since last save
gSaveEveryNRefreshes = 10; %eg. if 10, then we will save to disk every tenth screen update
gSampleNumber = 1; %only used to determine phase for simulated data
gSaveDataBaseFilename = []; %
% GUI variables
hFigure = [];
hAxisRaw = [];%[0 xData(end) -1 1];
hAxesRaw = [];
hAxesMath = [];
hStartButton = [];
hSaveCheck = [];
hSerialPopup = []; %popup menu lists available serial ports
hChannelPopup = []; %popup menu lists available channels to record
hHzPopup = []; %popup menu lists available sampling rates
acquiringData = false; %are we currently sampling data?
serialObj = []; %serial port
rawData = []; %raw data from device - data that still needs to be decoded into discrete samples
newSamples = []; %samples acquired in most recent screen refresh
% set up a timer to periodically get the data 
timerObj = timer('Period', gSecPerScreenRefresh, 'ExecutionMode', 'fixedSpacing', 'timerFcn', @getDataFromDeviceType);
makeGUI(); %set up user interface

  %%---------------------------------------------------
   function getDataFromDeviceType(hObject, eventdata)
       switch deviceType
        case 1
            [newData] = getDataFromDeviceType1();
           otherwise
            [newData] = getDataFromDeviceType0();
        end; %switch deviceType 
     if length(newData) < 1
         return
     end;
     yData = [yData newData]; %append new data
     yData = yData(:,length(yData)-gGraphSamples+1:end);
     if ~isempty(gSaveDataBaseFilename)
        gUnsavedData  = [gUnsavedData newData]; %append new data
        gSaveNumber = gSaveNumber + 1;
        if (gSaveNumber > gSaveEveryNRefreshes)  %flush unsaved data to disk
            flushSaveDataSub();
        end; %if SaveNumber
     end %if SaveData
     % check the user closed the window while we were waiting
     % for the device to return the waveform data
     if ishandle(hFigure),       
        axes(hAxesRaw);
        plot(xData,yData);
        axis(hAxisRaw);
        xlabel(xUnits); ylabel(yUnits);
        if showPower
            axes(hAxesMath);
            [freq,fftdata] = powerSpectrum(xData, yData);
            plot(freq, fftdata);
            xlabel('Frequency (Hz)'); ylabel('Amplitude');
        end;%showPower
     end
   end % getDataFromDeviceType()

  %%---------------------------------------------------
    function [newSamples] = getDataFromDeviceType0        
        %create - we create precisely the same number of observations per
        %  screen refresh, so sampling rate may be approximate
        new = round(gOscHz*gSecPerScreenRefresh);
        if (new < 1) 
            new = 1;
        end
        for s = 1:new,
            for c=1:gOscChannels,
                newSamples(c,s) = sin(30*2*pi*(gSecPerSample*(s+gSampleNumber)) ) + randn()*0.2; 
            end;
        end
        gSampleNumber = gSampleNumber + new;
   end %getDataFromDeviceType0()

  %%---------------------------------------------------
    function [newSamples] = getDataFromDeviceType1        
        packetBytes = 4 + (2 * (gOscChannels-1)); %16-bits data per channel plus 4 bytes header
        count = packetBytes;
        if (serialObj.BytesAvailable + length(rawData)  < packetBytes) 
            newSamples = [];
            return;
        end;
        [newRawData,count] = fread(serialObj,serialObj.BytesAvailable,'uchar');
        %fprintf('serial bytes: %d new and %d left from previous samples \n', length(newRawData), length(rawData));
        rawData = [rawData; newRawData];
        if (length(rawData) < 1) 
            return;
        end;
        [newSamples, rawData] = serDecodeSub(rawData);
   end %getDataFromDeviceType1()

  %%---------------------------------------------------         
   function [freq,fftdata] = powerSpectrum(x,y)
      n = length(x);
      Fs = 1/(x(2)-x(1));
      freq = ((0:n-1)./n)*Fs;
      fftdata = 20*log10(abs(fft(y)));
      idx = 1:floor(length(freq)/2);
      freq = freq(idx);
      fftdata = fftdata(idx);
   end %powerSpectrum()

  %%---------------------------------------------------   
   function makeGUI
      hFigure = figure('deleteFcn', @figureCloseCallback,'name',mfilename,'units','pixels','position',[10, 10, 1024, 512]);
      if showPower
        hAxesRaw  = axes('position', [0.05  0.60  0.9 0.35]);
        title('Raw Data');
        hAxesMath = axes('position', [0.05  0.15  0.9 0.35]);      
        title('Processed Data');
      else
        hAxesRaw  = axes('position', [0.05  0.15  0.9 0.80]);
        title('Raw Data');
      end;
      hStartButton = uicontrol('Style', 'PushButton','String', 'Start Acquisition','units', 'pixels','position', [5 10 100 20],'callback', @startStopCallback);
      hSaveCheck = uicontrol('Style','checkbox','units', 'pixels','position', [110 10 80 20],'string','Save data','Value',saveDataDefault);
      hHzText = uicontrol('Style', 'text','units', 'pixels','position', [200 8 20 20],'String', 'Hz:', 'backgroundcol', get(gcf, 'color')); 
      hHzPopup = uicontrol('Style', 'popupmenu','units', 'pixels','position', [221 10 80 20],'String', hzChoices,'Value' , hzDefaultIndex); 
      hChannelText = uicontrol('Style', 'text','units', 'pixels','position', [300 8 50 20],'String', 'Channels:', 'backgroundcol', get(gcf, 'color'));
      hChannelPopup = uicontrol('Style', 'popupmenu','units', 'pixels','position', [351 10 60 20],'String', chChoices,'Value' , chDefaultIndex); 
      if (ispc) %provide list of serial ports
            ser = ['COM1'; 'COM2'; 'COM3'; 'COM4'; 'COM5'; 'COM6'; 'COM7'; 'COM8'];
      else
        [ok, ser] = system('ls /dev/cu.*');
        ser = regexp(ser,'\s','split');
        ser = ser(~cellfun(@isempty, ser)); %deblank
        ser = ['Simulate data', ser ];
      end;
      if (serDefaultIndex == 0) %attempt to auto-select Arduino, which has name like /dev/cu.usbmodem12341 
        Index = find(not(cellfun('isempty', strfind(ser, '1234'))));
        if isempty(Index)
            serDefaultIndex = 1;
        else
            serDefaultIndex = Index(1); %choose first port that matches our search string
        end;
       end; %serDefaultIndex = 0
      hSerialPopup = uicontrol('Style', 'popupmenu','units', 'pixels','position', [420 10 180 20],'String', ser,'Value' , serDefaultIndex); 
      set(hStartButton, 'callback', @startStopCallback);
   end %makeGUI()
  
  %%---------------------------------------------------
   function startDeviceType
    gUnsavedData = [];
    rawData = []; %raw data from device - data that still needs to be decoded into discrete samples
    newSamples = []; %samples acquired in most recent screen refresh
    gOscHz = hzChoices(get(hHzPopup,'Value'));
    gOscChannels = chChoices(get(hChannelPopup,'Value'));
    gSecPerSample = 1/gOscHz;
    gGraphSamples = round(gOscHz * gGraphTotalTimeSec);
    xData = linspace(0,gGraphSamples/gOscHz,gGraphSamples); 
    hAxisRaw = [0 xData(end) -1 1];
    gSampleNumber = 1;
    if get(hSaveCheck,'Value') == 1
        gSaveDataBaseFilename = saveBrainVisionSub([]);
        fprintf('Saving data as %s\n',gSaveDataBaseFilename);
    else
        gSaveDataBaseFilename = [];
        fprintf('Warning: data not being saved to disk\n');
    end %if gSaveData 
    if (get(hSerialPopup,'Value') == 1)
        deviceType = 0; %simulated data
        startDeviceType0;
    else
        deviceType = 1; %arduino
        gOscChannels = gOscChannels + 1; %include extra channel for digital data
        list=get(hSerialPopup,'String');
        val=get(hSerialPopup,'Value');
        %str=list{val}; 
        startDeviceType1 (list{val});
    end;   
    yData = zeros(gOscChannels,gGraphSamples);
   end %startDeviceType()

  %%---------------------------------------------------
   function startDeviceType0 %DeviceType 0 = simulated data
        fprintf('Simulated Data: Recording %d channels at %d Hz\n',gOscChannels,gOscHz);
        hAxisRaw(3) = -1.5;  hAxisRaw(4) = 1.5; %simulated signal in range -1..+1 plus noise
   end %startDeviceType0()

   %%---------------------------------------------------
   function startDeviceType1 (DeviceName) %DeviceType 1 = Arduino on serial port
        if isempty(DeviceName)
            fprintf('Arduino Data: Recording %d channels at %d Hz\n',gOscChannels,gOscHz);
        else
            fprintf('Arduino Data: Recording %d channels at %d Hz attached to port "%s"\n',gOscChannels,gOscHz,DeviceName);
        end;
        fcloseSerialSub();
        if (gOscChannels < 2) 
            fprintf('Error in %s: set gOscChannels to be at least 2 (one analog and one digital channel)\n',mfilename('fullpath'));
            OK = false;
            return;
        end;
        hAxisRaw(4) = 66000; %16-bit acquisition data ranges 0..65535
        serialObj=serDeviceIndexSub (DeviceName);
        %serialObj=serDeviceIndexSub;
        fwrite(serialObj,[177,133,0,gOscChannels-1]);% [kCmd1Set kCmd2OscChannels,kCmd34ModeOsc,kCmd34ModeOsc];
        %nb -1 analog channels as we will also record one digital channel to record button presses
        fwrite(serialObj,[177,132,bitand(bitshift(gOscHz,-8),255),bitand(gOscHz,255)]);% [kCmd1Set, kCmd2OscHz, HzHIGH, HzLOW);
        fwrite(serialObj,[177,163,162,162]); %Set Oscilloscope Mode [kCmd1Set kCmd2Mode,kCmd34ModeOsc,kCmd34ModeOsc];       
   end %startDeviceType1()

  %%---------------------------------------------------
   function stopDeviceType
   switch deviceType
     case 1
        stopDeviceType1;
     otherwise
         stopDeviceType0;
    end %switch deviceType 
    flushSaveDataSub(); %save any residual data to disk
    fcloseSerialSub();
   end %stopDeviceType()

   function stopDeviceType0
         disp('Simulated acquisition halted');
   end %stopDeviceType0()

  %%---------------------------------------------------
   function stopDeviceType1
        disp('Arduino acquisition halted');
        fwrite(serialObj,[177,163,169,169]); %Set Keyboard Mode [kCmd1Set kCmd2Mode,kCmd34ModeKey,kCmd34ModeKey];
   end %stopDeviceType1()

  %%---------------------------------------------------
   function flushSaveDataSub
    if isempty(gSaveDataBaseFilename) 
        return; 
    end
    gSaveNumber = 1;
    saveBrainVisionSub(gUnsavedData,gOscHz,false, true, gSaveDataBaseFilename);
    gUnsavedData = [];
   end; %flushSaveDataSub()  
   
  %%---------------------------------------------------   
   function startStopCallback(hObject, eventdata)
      if acquiringData
         if strcmp(timerObj.running, 'on')
            stop(timerObj);      
         end
         stopDeviceType;
         acquiringData = false;
         set(hObject, 'string', 'Start Acquisition');
      else
          startDeviceType;
          acquiringData = true;
         set(hObject, 'string', 'Stop Acquisition');
         if strcmp(timerObj.running, 'off')
             start(timerObj);
         end
      end         
   end %startStopCallback()

  %%---------------------------------------------------   
   function figureCloseCallback(hObject, eventdata)
      cleanupObjects();
   end %figureCloseCallback()

  %%---------------------------------------------------   
   function cleanupObjects()
      if isvalid(timerObj) 
         stop(timerObj); 
         delete(timerObj);
      end
      fcloseSerialSub;
      if ishandle(hFigure), 
         delete(hFigure); 
      end
   end %cleanupObjects()

  %%---------------------------------------------------   
   function fcloseSerialSub()
       if ~isnumeric(serialObj) &&  isvalid(serialObj) 
        if (serialObj.BytesAvailable > 0)
            fread(serialObj, serialObj.BytesAvailable); %flush buffer
        end;
        Cmd =[177,163,169,169];% [kCmd1Set kCmd2Mode,kCmd34ModeKey,kCmd34ModeKey];
        fwrite(serialObj,Cmd);
        fclose(serialObj); 
        delete(serialObj);
        disp('closed serial port');
      end
   end %fcloseSerialSub()

%%---------------------------------------------------
    function [theSamples, rawResidual] =serDecodeSub(rawData)
        theSamples =[];
        len = length(rawData);
        samples = 0;
        is16bit = -1;
        packetBytes = 4 + (2 * (gOscChannels-1)); %16-bits data per channel plus 4 bytes header
        pos = 1;
        while ((len-pos+1) >= packetBytes) 
           checkSum  = 0;
           for c=0:(packetBytes-2),
            checkSum = checkSum + rawData(pos+c);
           end;
           while (checkSum > 255) 
               checkSum=(bitshift(checkSum,-8))+bitand(checkSum,255); %fold checksum
           end
           checkSumStored = rawData(pos+packetBytes-1);
           analogChannels  = bitand(rawData(pos),15);
           if ((checkSumStored == checkSum) && (analogChannels == (gOscChannels-1))) 
            is16bit  = bitand(bitshift(rawData(pos), -6),1);
            samples = samples + 1;
            for i=1:(gOscChannels-1)
             theSamples(i,samples) =  bitshift(rawData(pos+1+(i*2)), 8) +rawData(pos+2+(i*2)) ;
            end;
            theSamples(gOscChannels,samples) = rawData(pos+2);
            %if ((samples > 1) && (theSamples(gOscChannels,samples) ~= theSamples(gOscChannels,samples-1)) )
            % fprintf('Button press detected %d\n',theSamples(gOscChannels,samples));
            %end;
            pos = pos + packetBytes;
           else
            pos = pos + 1;
            disp('parity error');
           end;
        end;
        if (pos < len) 
            rawResidual = rawData(pos:end);
        else
            rawResidual = [];    
        end;
        if ((is16bit == 0) && (hAxisRaw(4) > 1024))
            hAxisRaw(4) = 1024; %10-bit data has the range 0..1023
        end;
        length(newSamples);
        %if (pos < len)
        %    fprintf('partial transfer pos %d len %d packetBytes %d residual %d precision %d\n',pos, len, packetBytes, length(rawResidual), is16bit);
        %end;
    end; % serDecodeSub()

%%---------------------------------------------------
    function ser=serDeviceIndexSub(DeviceName)
        if ~nargin || isempty(DeviceName)
            if (ispc) 
                DeviceName = 'COM2';
            else
                %DeviceName = '/dev/tty.usbmodem12341';
                DeviceName = '/dev/cu.usbmodem12341';
            end;
        end; %DeviceName not specified
        if (ispc)
            fprintf('Assuming device is named "%s", use the Device Manager to show active ports.\n', DeviceName);   
        else
            fprintf('Assuming device is named "%s", available port names are\n', DeviceName);   
            system('ls /dev/cu.*');
        end;
        ser = serial(DeviceName,'InputBufferSize',16384);% <-set large buffer
        fopen(ser);
    end % SerDeviceIndexSub()

    %%---------------------------------------------------   
    function [baseFilename] = saveBrainVisionSub(data,sampleRateHz,finalChannelDigital, appendData, filename)
    %save data in BrainVisionAnalyzer format
    %   data : an array with channels*samples of data
    %   sampleRateHz : sampling rate in Hz, e.g. if 10ms per sample then 100 Hz
    %   finalChannelDigital : often last channel is digital data (codes conditions or button presses)
    %   appendData : if true, and filename.eeg exists new data will be added to existing data
    %   filename : [optional] base name of file, e.g. ~/dir/f1 will create files  ~/dir/f1.vhdr and ~/dir/f1.eeg
    %EXAMPLE
    %  samplingRateHz = 100;
    %  time = [1/samplingRateHz:1/samplingRateHz:1]; %one second of data
    %  freqHz1 =2.0;
    %  data(1,:) = sin(2*pi*freqHz1*time);
    %  freqHz2 =10.0;
    %  data(2,:) = sin(2*pi*freqHz2*time);
    %  plot(time,data)
    %  samples = length(data(1,:))
    %  channels = length(data(:,1))
    %  basename = saveBrainVision(data,samplingRateHz);
    %  %to append more data to this file
    %  saveBrainVision(data,samplingRateHz,false,true,basename);
    %FORMAT DETAILS
    %  see "Brain Vision Analyzer OLE Automation Reference Manual Version 1.05"
    %     campus.uni-muenster.de/fileadmin/einrichtung/biomag/EEG-Labor/VisionAnalyserReference.doc

    if ~exist('filename','var')
        baseFilename =  [pwd filesep datestr(now,'yymmdd_HHMMSS')];
    else
        baseFilename =  filename;
        %[pth,nam,ext] = fileparts(filename);
        %baseFilename = [pth filesep nam]; %<- option: strip file extension
    end;
    if (~exist('sampleRateHz','var') || (sampleRateHz == 0))
        sampleRateHz = 1000;
        fprintf('%s warning: assuming %dHz sampling rate\n', mfilename,sampleRateHz);
    end;
    if ~exist('finalChannelDigital','var')
        finalChannelDigital = false;
    end;
    if ~exist('appendData','var')
        appendData = false;
    end; 
    VECTORIZED = false; %Warning: vectorized data storage incompatible with appending data
    if (length(data) < 1) 
        %note: user can call this function with data=[] to get basefilename for future appends...
        %fprintf('%s warning: no data to save\n', mfilename);
        return;
    end;
    samples = length(data(1,:));
    channels = length(data(:,1));
    headerFilename = [baseFilename '.vhdr'];
    dataFilename = [baseFilename '.eeg'];
    prevSamples = 0;
    if ((appendData) && (exist(dataFilename) ) )
       fileInfo = dir(dataFilename);
       fileSize = fileInfo.bytes;
       if (mod(fileSize,(channels*4)) ~= 0) % singles are 4 bytes each
            fprintf('%s warning: unable to append data to %s - filesize should be evenly disible by channels*4 (size of single)\n', mfilename,dataFilename);
            return;
       end;
       prevSamples = fileSize/(channels*4); % singles are 4 bytes each
       %fprintf(' Appending to %s with %d samples \n',dataFilename, prevSamples);
    end
    %next: write header file
    f = fopen(headerFilename,'w'); %overwrite existing header
    fprintf(f, 'Brain Vision Data Exchange Header File Version 1.0\n');
    fprintf(f, '; Data created by Matlab script %s\n',mfilename);
    fprintf(f,  '[Common Infos]\n');
    fprintf(f, 'DataFile=%s\n',dataFilename);
    fprintf(f,  'DataFormat=BINARY\n');
    if VECTORIZED 
        fprintf(f,  'DataOrientation=VECTORIZED\n');
    else
        fprintf(f, 'DataOrientation=MULTIPLEXED\n');
    end;
    fprintf(f, 'DataType=TIMEDOMAIN\n');
    fprintf(f, 'NumberOfChannels=%d\n',channels);
    fprintf(f, 'SamplingInterval=%f\n',1000000/sampleRateHz);
    % SamplingInterval: Resolution in microseconds for data in the time domain and in hertz for data in the frequency domain.
    fprintf(f,  'DataPoints=%d\n',samples+prevSamples);
    fprintf(f,  '[Binary Infos]\n');
    fprintf(f,  'BinaryFormat=IEEE_FLOAT_32\n');   
    fprintf(f,  '[Channel Infos]\n');
    for c=1:channels,
        if (finalChannelDigital) && (c == channels)
          fprintf(f, 'Ch%d=%d,,1,Digital\n',c,c);
        else
          fprintf(f, 'Ch%d=%d,,1,µV\n',c,c);
        end
    end %for each channel
    fclose(f);
    %next: write data file
    if (prevSamples > 0) %append
        f = fopen(dataFilename,'a','ieee-le'); %overwrite existing header
    else
        f = fopen(dataFilename,'w','ieee-le'); %overwrite existing header
    end;
    if VECTORIZED 
        fwrite(f, data', 'single'); %precision must match header "BinaryFormat"
    else
        fwrite(f, data, 'single'); %precision must match header "BinaryFormat"
    end
    fclose(f);
  end % saveBrainVisionSub()

end % of ScopeMath_Arduino


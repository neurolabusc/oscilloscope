function [baseFilename] = saveBrainVision(data,sampleRateHz,finalChannelDigital, appendData, filename)
%save data in BrainVisionAnalyzer format

% see "Brain Vision Analyzer OLE Automation Reference Manual Version 1.05"
%     campus.uni-muenster.de/fileadmin/einrichtung/biomag/EEG-Labor/VisionAnalyserReference.doc

% samplingRateHz = 100;
% time = [1/samplingRateHz:1/samplingRateHz:1]; %one second of data
% freqHz1 =2.0;
% data(1,:) = sin(2*pi*freqHz1*time);
% freqHz2 =10.0;
% data(2,:) = sin(2*pi*freqHz2*time);
% plot(time,data)
% samples = length(data(1,:))
% channels = length(data(:,1))
% basename = saveBrainVision(data,samplingRateHz);
% %to append more data to this file
% saveBrainVision(data,samplingRateHz,false,true,basename);

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
   fprintf(' Appending to %s with %d samples \n',dataFilename, prevSamples);
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

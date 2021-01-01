//
//  ViewController.m
//  ArduinoSerial
//
//  Created by Pat O'Keefe on 4/30/09.
//  Copyright 2009 POP - Pat OKeefe Productions. All rights reserved.
//
//	Portions of this code were derived from Andreas Mayer's work on AMSerialPort.
//	AMSerialPort was absolutely necessary for the success of this project, and for
//	this, I thank Andreas. This is just a glorified adaptation to present an interface
//	for the ambitious programmer and work well with Arduino serial messages.
//
//	AMSerialPort is Copyright 2006 Andreas Mayer.
//



#import "ViewController.h"
#import "AMSerialPortList.h"
#import "AMSerialPortAdditions.h"
#import "AMView.h"


@implementation ViewController

static int gOscHz = 500;
static int gOscChannels = 3; //number of channels to report
//static int analogChannels = 0;
static int samples = 0;
static int graphTimepoints = 100;
static int graphSamplesPerTimepoint = 10;


- (void)serialTimerTick:(NSTimer *)timer {
    if (graphView == nil) {
        return;
    }
    //NSLog(@"C: %f %d\n",0.5, analogChannels);
    if ((gOscChannels < 1)  || (gOscChannels > kMaxChannels))  return;

    
    GraphStruct lGraph;
    lGraph.blackBackground = FALSE;
    lGraph.enabled = TRUE;
    lGraph.timepoints = graphTimepoints;
    lGraph.verticalScale = 1.0;
    lGraph.selectedTimepoint = 1;
    lGraph.lines = gOscChannels;
    lGraph.data = (float *) malloc(lGraph.timepoints*lGraph.lines*sizeof(float));
    

    int p = 0;
    for (int c = 0; c < lGraph.lines; c++) {
        int sample = samples- (graphTimepoints* graphSamplesPerTimepoint);
        while (sample < 0) sample = kMaxSamples - sample;
        
        for (int i = 0; i < lGraph.timepoints; i++) {
            /*if (c == 0)
                lGraph.data[p] = channelA[sample];
            if (c == 1)
                lGraph.data[p] =  channelB[sample];
            if (c == 2)
                lGraph.data[p] = channelC[sample];*/
            //lGraph.data[p] = (float)rand()/(float)RAND_MAX;
            lGraph.data[p] = channelData[c][sample];
            p++;
            sample = sample + graphSamplesPerTimepoint;
            if (sample >= kMaxSamples) sample = sample - kMaxSamples;
        }
    }
    [graphView updateData: lGraph];
    free(lGraph.data);
}
-(void) startTimer {
    if (serialTimer == nil) {
        float theInterval = 1.0/60.0;
        serialTimer = [NSTimer scheduledTimerWithTimeInterval:theInterval target:self selector:@selector(serialTimerTick:) userInfo:nil repeats:YES];
    }
}

//- (void)viewWillClose {
//    //Not called???
//    //NSLog(@"bye!");
//
//}
//
//- (void)dealloc {
//     NSLog(@"bye");
//    if(serialTimer) {
//        [serialTimer invalidate];
//        serialTimer = nil;
//        NSLog(@"bye");
//    }
//    [super dealloc];
//}

- (void)awakeFromNib
{
    [theWindow setDelegate:self];
    serialBuffer = [[NSMutableData alloc] init];
    //channelA = (float *) malloc(kMaxSamples*sizeof(float));
    //channelB = (float *) malloc(kMaxSamples*sizeof(float));
    //channelC = (float *) malloc(kMaxSamples*sizeof(float));
    
    NSLog(@"Created buffer");
	[sendButton setEnabled:NO];
	
	/// set up notifications
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didAddPorts:) name:AMSerialPortListDidAddPortsNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didRemovePorts:) name:AMSerialPortListDidRemovePortsNotification object:nil];
	
	/// initialize port list to arm notifications
	[AMSerialPortList sharedPortList];
	[self listDevices];
    [super awakeFromNib];
    
	
}

- (IBAction)attemptConnect:(id)sender {
    //[serialScreenMessage setStringValue:@"Attempting to Connect..."];
	[self initPort];
    [self startTimer];
    //NSLog(@"attempted connection")
}

	
# pragma mark Serial Port Stuff

const  u_char kCmd1Set = 177;
const  u_char kCmd1Get = 169;
const  u_char kCmd2Mode = 163;
const  u_char kCmd2KeyDown = 129;
const  u_char kCmd2KeyUp = 130;
const  u_char kCmd2KeyTrigger = 131;
const  u_char kCmd2OscHz = 132;
const  u_char kCmd2OscChannels = 133;
const  u_char kCmd2EEPROMSAVE = 134;
const  u_char kCmd34ModeKey = 169;
const  u_char kCmd34ModeuSec = 181;
const  u_char kCmd34ModeOsc = 162;

- (void)disconnectPort
{
    NSLog(@"discon");
    if([port isOpen]) {
        u_char chrArrayMode[5] = {kCmd1Set,kCmd2Mode,kCmd34ModeKey,kCmd34ModeKey};
        [port writeData:[NSData dataWithBytes:& chrArrayMode length:4] error:NULL];
        NSLog(@"device placed in keyboard mode [disconnected]");
    }
    
}
	- (void)initPort
	{
		NSString *deviceName = [serialSelectMenu titleOfSelectedItem];
        
        gOscChannels = [[channelSelectMenu titleOfSelectedItem] intValue];
        if (gOscChannels < 1) gOscChannels = 1;
        if (gOscChannels > kMaxChannels) gOscChannels = kMaxChannels;
        gOscHz = [[samplingRateSelectMenu titleOfSelectedItem] intValue];
        if (gOscHz < 10) gOscHz = 10;
        
        //if (gOscChannels > 44000) gOscChannels = 44000;
        NSLog(@"Connecting with %d channels at %d Hz\n",gOscChannels, gOscHz);
        
		if (true) {
        
		//if (![deviceName isEqualToString:[port bsdPath]]) {
			[self disconnectPort];
            [port close];
			
			[self setPort:[[[AMSerialPort alloc] init:deviceName withName:deviceName type:(NSString*)CFSTR(kIOSerialBSDModemType)] autorelease]];
			[port setDelegate:self];
			
			if ([port open]) {
				
				//Then I suppose we connected!
				NSLog(@"successfully connected");

				//[connectButton setEnabled:NO];
				[sendButton setEnabled:YES];
				//[serialScreenMessage setStringValue:@"Connection Successful!"];

				//TODO: Set appropriate baud rate here. 
				
				//The standard speeds defined in termios.h are listed near
				//the top of AMSerialPort.h. Those can be preceeded with a 'B' as below. However, I've had success
				//with non standard rates (such as the one for the MIDI protocol). Just omit the 'B' for those.
			
				[port setSpeed:B57600];

                //set Channels
                u_char chrArrayChan[5] = {kCmd1Set,kCmd2OscChannels,0,gOscChannels};
                [port writeData:[NSData dataWithBytes:& chrArrayChan length:4] error:NULL];
                //set sample rate
                u_char chrArrayHz[5] = {kCmd1Set,kCmd2OscHz,(gOscHz >> 8) & 0xff,gOscHz & 0xff};
                [port writeData:[NSData dataWithBytes:& chrArrayHz length:4] error:NULL];
                
                //command: set mode
                u_char chrArrayMode[5] = {kCmd1Set,kCmd2Mode,kCmd34ModeOsc,kCmd34ModeOsc};
                [port writeData:[NSData dataWithBytes:& chrArrayMode length:4] error:NULL];
                //[port flushInput: true Output:true];
                //[port send:@"±£µµ"];
				

				// listen for data in a separate thread
				[port readDataInBackground];
				
				
			} else { // an error occured while creating port
				
				NSLog(@"error connecting");
				//[serialScreenMessage setStringValue:@"Error Trying to Connect..."];
				[self setPort:nil];
				
			}
		}
	}
	
	- (void)serialPortReadData:(NSDictionary *)dataDictionary
	{
        int packetBytes = 4 + (gOscChannels *2); //bytes in a packet of data
        Byte serialBytes[packetBytes];
        AMSerialPort *sendPort = [dataDictionary objectForKey:@"serialPort"];
		NSData *data = [dataDictionary objectForKey:@"data"];
		//[serialBuffer appendData:data];
		if ([data length] > 0) {
            // continue listening
            [sendPort readDataInBackground];
            
            [serialBuffer appendData:data];
            int len = [serialBuffer length];
            int pos = 0;
            
            Byte *byteData = (Byte*)malloc(len);
            memcpy(byteData, [data bytes], len);
            
            while ((len-pos) >= packetBytes) {
                for (int c=0; c<packetBytes; c++)
                    serialBytes[c] = byteData[pos+c]; //initialize output so unused channels report 0
                int checkSumStored = serialBytes[packetBytes-1];
                int checkSum = 0;
                for (int i = 0; i <= (packetBytes-2); i++)
                    checkSum = checkSum + serialBytes[i];
                while (checkSum > 0xff) checkSum=(checkSum >> 8)+(checkSum & 0xff);
                int analogChannels  = serialBytes[0] & 0x0f; //channels reported by Arduino
                //NSLog(@"A: %d %d\nf",checkSum, checkSumStored);
                if ((checkSum == checkSumStored) && (gOscChannels == analogChannels)) {
                    /*channelA[samples]=  (serialBytes[3]  << 8) +serialBytes[4] ;
                    channelB[samples]=  (serialBytes[5]  << 8) +serialBytes[6] ;
                    channelC[samples]=  (serialBytes[7]  << 8) +serialBytes[8] ;*/
                    for (int i = 0; i < gOscChannels; i++)
                        channelData[i][samples] = (serialBytes[3+(i*2)]  << 8) +serialBytes[4+(i*2)] ;
                    
                    int digitalByte = serialBytes[2];
                    int is16bit  = (serialBytes[0] >> 6) & 0x01;
                    
                        if (is16bit == 1) {
                            for (int i = 0; i < gOscChannels; i++)
                                channelData[i][samples] = channelData[i][samples] /65535;
                        } else {
                            for (int i = 0; i < gOscChannels; i++)
                                channelData[i][samples] = channelData[i][samples] /1023;

                            
                        }
                    //NSLog(@"B: %f %d\nf",channelA[samples], analogChannels);
                        samples = samples + 1;
                        if (samples >= kMaxSamples)
                            samples = 0;
                    pos = pos + packetBytes;

                } else {//checksum matches
                    //the checksum does not match - disregard oldest byte and try again
                    pos = pos + 1;
                }
            }//while potential blocks to read
            if (pos > 0)  [serialBuffer replaceBytesInRange:NSMakeRange(0, pos) withBytes:NULL length:0];
                //NSLog(@" Buffer= %d  Val= %d",[serialBuffer length], val0);
                free(byteData);
            } else {
                // port closed
                NSLog(@"Serious problem with serialPortReadData");
            }
		
	}
	
	- (void)listDevices
	{
		// get an port enumerator
		NSEnumerator *enumerator = [AMSerialPortList portEnumerator];
		AMSerialPort *aPort;
        [channelSelectMenu removeAllItems];
        for (int i = 1; i <= kMaxChannels; i++)
            [channelSelectMenu addItemWithTitle:[NSString stringWithFormat:@"%d",i]];
        [channelSelectMenu selectItemAtIndex: 0];
        
        [samplingRateSelectMenu removeAllItems];
        [samplingRateSelectMenu addItemWithTitle:[NSString stringWithFormat:@"%d",125]];
        [samplingRateSelectMenu addItemWithTitle:[NSString stringWithFormat:@"%d",250]];
        [samplingRateSelectMenu addItemWithTitle:[NSString stringWithFormat:@"%d",500]];
        [samplingRateSelectMenu addItemWithTitle:[NSString stringWithFormat:@"%d",1000]];
            [samplingRateSelectMenu addItemWithTitle:[NSString stringWithFormat:@"%d",2000]];
		[samplingRateSelectMenu selectItemAtIndex: 3];
		
        [serialSelectMenu removeAllItems];
        NSRange textRange;
        int index =0;
        int found = 0;
        while (aPort = [enumerator nextObject]) {
			[serialSelectMenu addItemWithTitle:[aPort bsdPath]];
            textRange =[[aPort bsdPath] rangeOfString:@"123"];
            if(textRange.location != NSNotFound)
                found = index;
            index++;
		}
        [serialSelectMenu selectItemAtIndex: found];
	}
	
	- (IBAction)send:(id)sender
	{
		
		NSString *sendString = [[textField stringValue] stringByAppendingString:@"\r"];
		
		 if(!port) {
		 [self initPort];
		 }
		 
		 if([port isOpen]) {
		 [port writeString:sendString usingEncoding:NSUTF8StringEncoding error:NULL];
		 }
	}
	
	- (AMSerialPort *)port
	{
		return port;
	}
	
	- (void)setPort:(AMSerialPort *)newPort
	{
		id old = nil;
		
		if (newPort != port) {
			
            old = port;
			port = [newPort retain];
			[old release];
		}
	}
	
	
# pragma mark Notifications
	
	- (void)didAddPorts:(NSNotification *)theNotification
	{
		NSLog(@"A port was added");
		[self listDevices];
	}
	
	- (void)didRemovePorts:(NSNotification *)theNotification
	{
		NSLog(@"A port was removed");
		[self listDevices];
	}

- (void)windowWillClose:(NSNotification *)aNotification {
    if(serialTimer) {
            [serialTimer invalidate];
           serialTimer = nil;
            //NSLog(@"bye");
        }
    
    [self disconnectPort];
    //NSLog(@"bye");
    [NSApp terminate:self];
}






@end

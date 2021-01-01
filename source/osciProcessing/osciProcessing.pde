int serialPortNumber = 6; //set to 0 for automatic detection
int gOscHz = 2000;
int gOscChannels = 4; //number of channels to report
float gGraphTotalTimeSec = 2; //e.g. if 1 then the last 1 second of data is displayed
int screenWid = 1000; //width of scrren, in pixels
int screenHt = 600; //height of screen, in pixels
//no need to edit lines below here...
int BAUD_RATE =  115200; //older boards may have issues with 115200; 
import processing.serial.*;
import javax.swing.JOptionPane;//For user input dialogs
Serial port;      // Create object from Serial class
int[]  val;              // Data received from the serial port
int[] serialBytes;
int packetBytes = 4 + (2 * gOscChannels); // for each sample the Arduino sends 16-bits per channel plus 4 bytes header
int bytesInBuffer = 0;
int cnt; //sample count
int wm1; //screenWidth -1
int[][] values; //data for up to 3 analog channels

float screenScale10bit = float(screenHt-1)/1023;
float screenScale16bit = float(screenHt-1)/65535;
int halfScreenHt = screenHt / 2;
int positionHt = 200; //height of vertical bar shown at leading edge of oscilloscope
long valuesReceived = 0; 
long calibrationFrames = 120;
long plotEveryNthSample = 1000;
long startTime;
int kOscMaxChannels = 15;
int[][] lineColorsRGB = { {255,0,0}, {0,255,0}, {0,0,255}, {255,255,0}, {0,255,255}, {255,0,255},
                         {128,0,0}, {0,128,0}, {0,0,128}, {128,128,0}, {0,128,128}, {128,0,128},
                         {64,0,0}, {0,64,0}, {0,0,64} };

int kCmdLength = 4; //length of commands
byte  kCmd1Set = (byte) 177;
byte kCmd1Get = (byte) 169;
byte kCmd2Mode = (byte) 163;
byte kCmd2KeyDown = (byte) 129;
byte kCmd2KeyUp = (byte) 130;
byte kCmd2KeyTrigger = (byte) 131;
byte kCmd2OscHz = (byte) 132;
byte kCmd2OscChannels = (byte) 133;
byte kCmd2EEPROMSAVE =(byte) 134;
byte kCmd34ModeKey = (byte) 169;
byte kCmd34ModeuSec = (byte) 181;
byte kCmd34ModeOsc = (byte) 162;

void writeCmd(boolean setNotGet, byte b2, byte b3, byte b4) { //get or set Arduino settings
  //byte serialBytes[kCmdLength];
  //serialBytes = new byte[kCmdLength];
  byte[] serialBytes = new byte[kCmdLength];
  //serialBytes = new byte[4]; 
        serialBytes[0] = kCmd1Set; //debounceTime
        serialBytes[1] = b2; 
        serialBytes[2] = b3;
        serialBytes[3] = b4;
        port.write(serialBytes);  
} //writeCmd()


void exit()  { //put the Arduino back into default keyboard mode
    writeCmd(true,kCmd2Mode,kCmd34ModeKey,kCmd34ModeKey); //set to uSec Mode
    super.exit();
} //exit()

void calibrateFrameRate()
{
  if (valuesReceived < 1) {
    println("Error: No samples detected: either device is not connected or serialPortNumber is wrong.");
    exit();
  }
  
  //float gGraphTotalTimeSec = 0.5; %e.g. if 1 then the last 1 second of data is displayed
  //int screenWid = 800; //width of scrren, in pixels
  plotEveryNthSample = round(gGraphTotalTimeSec/float(screenWid)* float(gOscHz));
 
  if (plotEveryNthSample < 1) plotEveryNthSample = 1; 
  float estHz = (1000*valuesReceived)/(millis()-startTime);
  print("Requested ");  print(gOscHz); print("Hz, so far we have observed "); print(estHz); println("Hz");
  print ("Will plot once every ");  print(plotEveryNthSample); print(" samples, so the screen shows "); print((screenWid *plotEveryNthSample)/ gOscHz); println(" Sec");
} //calibrateFrameRate()

void setPortNum() 
{
   String[] portStr = Serial.list();
   int nPort = portStr.length;
   if (nPort < 1) {
      javax.swing.JOptionPane.showMessageDialog(frame,"No devices detected: please check Arduino power and drivers.");  
      exit();    
   }
   for (int i=0; i<nPort; i++) 
     portStr[i] =  i+ " "+portStr[i] ;  
   String respStr = (String) JOptionPane.showInputDialog(null,
      "Choose your device (if not listed: check drivers and power)", "Select Arduino",
      JOptionPane.PLAIN_MESSAGE, null,
      portStr, portStr[0]);
   //System.out.printf("Selected port %s.\n", respStr);
   serialPortNumber = Integer.parseInt(respStr.substring(0, 1));  
} //setPortNum()

void setup() 
{
  if (gOscChannels > lineColorsRGB.length) {
    println("Error: you need to specify more colors to the array lineColorsRGB.");
    exit();   
  } 
  if (gOscChannels > kOscMaxChannels) {
    print("Error: you requested "); print(gOscChannels); print(" channels but this software currently only supports ");println(kOscMaxChannels);
    exit();   
  } 
  if (serialPortNumber == 0) 
    setPortNum();
  else {
    print("Will attempt to open port "); println(serialPortNumber); 
    println(", this should correspond to the device number in this list:");
    println(Serial.list());
    println("Hint: if you set serialPortNumber=0 the program will allow the user to select from a drop down list of available ports");
  }
  port = new Serial(this, Serial.list()[serialPortNumber], BAUD_RATE);    
  writeCmd(true,kCmd2OscChannels,(byte) 0, (byte)gOscChannels); //set sampling rate to 125 Hz
  writeCmd(true,kCmd2OscHz, (byte) ((gOscHz >> 8) & 0xff), (byte) (gOscHz & 0xff)); //set sampling rate to 125 Hz
  writeCmd(true,kCmd2Mode,kCmd34ModeOsc,kCmd34ModeOsc); //set to uSec Mode
  startTime = 0;
  size(screenWid, screenHt);                                  //currently set to 5 sec
  serialBytes = new int[packetBytes];
  val = new int[gOscChannels]; //most recent sample for each channel
  values = new int[gOscChannels][width]; //previous samples for each channel
  wm1= width-1; 
  cnt = 1;     
  frameRate(60);                                //read/draw 180 samples/sec
  for (int c=0;c<gOscChannels;c++) {
    for (int s=0;s<width;s++) {                 //set initial values to midrange
      values[c][s] = 0;
    }
  }  
} //setup() 

void draw() {
  while (port.available() >= (packetBytes-bytesInBuffer)) {                  //read the latest value
        for (int c=bytesInBuffer; c<packetBytes; c++) { 
            serialBytes[c] = port.read();
         } //initialize output so unused channels report 0
         int checkSum  = 0;
         for (int c=0; c <(packetBytes-1); c++)
           checkSum = checkSum + serialBytes[c];
         while (checkSum > 0xff) checkSum=(checkSum >> 8)+(checkSum & 0xff); //fold checksum
         int checkSumStored = serialBytes[packetBytes-1];
         int analogChannels  = serialBytes[0] & 0x0f; //channels reported by Arduino
         if ( (checkSum == checkSumStored) && (gOscChannels == analogChannels)) {
           //int timingByte = serialBytes[1]; //we ignore timing data is passed from the Arduino
           //int digitalByte = serialBytes[2]; //we ignore digital inuts - this reports button presses
           for (int i = 0; i < gOscChannels; i++)
             val[i] =  (serialBytes[3+(i*2)]  << 8) +serialBytes[4+(i*2)] ;
           int is16bit  = (serialBytes[0] >> 6) & 0x01;
           if (is16bit == 1) { //16 bit ADC
              for (int i = 0; i < gOscChannels; i++) val[i] = round(val[i]*screenScale16bit); 
 
            } else { //10 bit ADC
              for (int i = 0; i < gOscChannels; i++) val[i] = round(val[i]*screenScale10bit);               
            }
            valuesReceived++;
            if ((calibrationFrames == 0) && (valuesReceived >= plotEveryNthSample)) {
                for (int i = 0; i < gOscChannels; i++) values[i][cnt] = val[i];                              //put it in the array#
                cnt++;                                                 //increment the count
                if (cnt > wm1) cnt = 1;
                valuesReceived = 0;
             }//plot value
            bytesInBuffer = 0;
         } else {//checksum matches   
            //the checksum does not match - disregard oldest byte and try again
            bytesInBuffer = packetBytes-1;
            println("checkSum mismatch");
            for (int c=1; c<packetBytes; c++) 
              serialBytes[c-1] = serialBytes[c];
         }   
      } //while samples to read
      if (calibrationFrames > 0) {
        if ((startTime == 0) && (valuesReceived > 0)){
          valuesReceived = 0; 
          startTime = millis();
        }
        calibrationFrames--;
        if (calibrationFrames == 0) {
          calibrateFrameRate(); 
        }
        return;
      } //if still in initial calibration frames period
      //NEXT : DRAW GRAPH
      background(0); //clear background
      //next: vertical lines for seconds...
      stroke(60);
      for (int d = 0; d < width-1; d = d + 180) {   
      line(d,0,d,screenHt);
      }
      //draw the leading edge line
      stroke(255,255,0);
      line(cnt,halfScreenHt-positionHt,cnt,halfScreenHt+positionHt);  
      //plot incoming data      
      for (int i = 0; i < gOscChannels; i++) {
        stroke(lineColorsRGB[i][0],lineColorsRGB[i][1],lineColorsRGB[i][2]);  
        for (int x=2; x<wm1; x++) line (x-1,  values[i][x-1], x, values[i][x]);
      }        
 } //draw()

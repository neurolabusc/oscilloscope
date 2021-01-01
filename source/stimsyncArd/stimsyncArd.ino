// '±£©©' sets keyboard, '±£µµ' sets uSec, '±£¢¢' sets oscilloscope

//#define IS_LEONARDO
//#define IS_TEENSY2
#define IS_TEENSY3
//#define ANALOG_KEYS
//#define PROTO_BOARD
//no need to edit lines below here....

#include <EEPROM.h> //used to store key mappings
#include <usb_keyboard.h> //used to store key mappings
#define BAUD_RATE 230400 
const int kCmdLength = 4; //length of commands
byte gCmdPrevBytes[kCmdLength] = {0, 0,0,0};
const byte  kCmd1Set = 177;
const byte kCmd1Get = 169;
const byte kCmd2Mode = 163;
const byte kCmd2KeyDown = 129;
const byte kCmd2KeyUp = 130;
const byte kCmd2KeyTrigger = 131;
const byte kCmd2OscHz = 132;
const byte kCmd2OscChannels = 133;
const byte kCmd2EEPROMSAVE = 134;
const byte kCmd2NumAnalogKeys = 135;
const byte kCmd34ModeKey = 169;
const byte kCmd34ModeuSec = 181;
const byte kCmd34ModeOsc = 162;


/*COMMANDS FROM COMPUTER TO ARDUINO AND RESPONSES FROM ARDIUNO TO THE COMPUTER
All commands are 4 bytes long, the first byte is either SET (177) or GET (169)
SET commands change Arduino settings
 SET commands will typically be forgotten when the ARDUINO restarts
 However, the SET:EEPROMSAVE command will have the ARDUINO remember keyboard settings (keyup, keydown, keytrigger and debounce values)
GET commands request the Arduino to report its current settings
 SET: 177 -Have Arduino Change Settings 
  SET:MODE: 163 -change whether Arduino acts as a USB Keyboard, Microsecond Timer or Oscilloscope
   SET:MODE:KEYBOARD 169,169 - digital inputs mimic a USB keyboard [177,163,169,169]
   SET:MODE:USEC 181,181 - used for precise timing and to change keyboard mapping [177,163,181,181]
   SET:MODE:OSC 162,162- used to plot analog inputs [177,163,162,162]
   -Example: [177,163,181,181] switches the Arduino to uSec mode
   -**Tip: From Arduino SerialMonitor sending '±£©©' sets keyboard, '±£µµ' sets uSec, '±£¢¢' sets oscilloscope
  SET:KEYDOWNPRESS:[LINE]:[MAPPING] 129 - change USB key stroke sent when key depressed
   -Example [177,129,2,72] pressing 2nd button will elicit 'H' (ASCII=32)
   -Special: MAPPING 0 means no response is generated
     -Example [177,129,3,0] pressing 3rd button will not create a response
   -Special: LINE 0 changes debounce time
     -Example [177,129,0,44] sets debounce time to 44ms
  SET:KEYUPPRESS:[LINE]:[MAPPING] 130 - change USB key stroke sent when key released
   -Example [177,130,2,72] releasing 2nd button will elicit 'H' (ASCII=32)
   -Special: MAPPING 0 means no response is generated
     -Example [177,130,3,0] releasing 3rd button will not create a response
  SET:KEYTRIGGER:[LINE]:[MAPPING] 131 - bing digital out to digital input
   -Example [177,131,2,3] down/up of second button determines on/off of 3rd output line
   -Special: MAPPING 0 removes binding
     -Example [177,131,3,0] status of 3rd button does not influence any outputs
  SET:OSCHZ:[HZhi]:[HZlo] 132 - set sample rate of Oscilloscope (Hz)
   -Example [177,132,1,244] sets 500Hz sampling rate
   -Example [177,132,0,125] sets 125Hz sampling rate
  SET:OSCCHANNELS:[CHANNELShi]:[CHANNELSlo] 133 - set number of analog inputs reported by Oscilloscope
   -Example [177,133,0,6] sets recording to 6 inputs 
  SET:EEPROMSAVE:EEPROMSAVE:EEPROMSAVE 134 - save current settings to EEPROM so it will be recalled
  -Example [177,134,134,134] stores current settings in persistent memory
  SET:NUMANALOGKEYS:[NUMhi]:[NUMlo] 135 - bing digital out to digital input
   -Example [177,135,0,1] enable 1 analog key (currently 0,1,2)

 GET: 169 -Same functions as SET, but have Arduino Report Settings rather than change settings  
  -Same commands as 'SET'
  -Example: [169,163,0,0] requests mode, if Arduino is in uSec mode it will respond [169,163,181,181]
  -Example: [169,129,5,0] requests down-press mapping for fifth key, if this is 'i' (ASCII=105) the Arduino responds [169,129,5,105]

SIGNALS IN MIRCROSECOND (USEC) MODE
  0: kuSecSignature (254)
  1: HIGH(1) byte keybits
  2: LOW(0) byte of keybits
  3: HIGH(3) byte of uSec
  4: 2 byte of uSec
  5: 1 byte of uSec
  6:  0 byte of uSec
  7: Checksum - sum of all previous bytes folded to fit in 0..255
For example, if only the first (binary 1) and tenth (binary 512) buttons are pressed, the keybits is 513, with 2 stored in the HIGH byte and 1 stored in the LOW BYTE
Likewsie, the time in microsenconds is sent as a 32-bit value.

SIGNALS IN OSCILLOSCOPE MODE
 When the Arduino is in Osc mode, it will send the computer a packet of data each sample. The sample rate is set by OSCHZ and the number of channels by OSCCHANNELS (1..15).
 The length of the packet is X+2*OSCCHANNELS
 These 8 bytes are:
  0: Signature - bits as specified
      7 (MSB): ALWAYS 0 (so packet can not be confused with a COMMAND)
      6: 1 for 16-bit precision, 0 for 10-bit precision
      5-4: Sample Number: allows software to detect dropped samples and decode timing byte. Increments 0,1,2,3,0,1,2,3.... 
      3-0 (LSB): OSCCHANNELS (1..15)
  1: Timing in milliseconds. This byte is used to encode time. Time is acquired Sample Number is 0, with sample numbers 0,1,2,3 reflecting the HIGH(3),2,1,LOW(0) byte of this 4-byte value 
  2: Digital inputs - status of all 8 digital inputs
  FOR EACH CHANNEL K=1..OSCCHANNELS 
    1+(K*2): HIGH(1) byte for Channel K
    2+(K*2): HIGH(1) byte for Channel K
  3+(OSCCHANNELS*2): Checksum - sum of all previous bytes folded to fit in 0..255
*/
//DIGITAL OUTPUTS - we can switch on or off outputs
const int kMaxNumAnalog = 2;
#ifdef ANALOG_KEYS
int kKeyNumAnalog = 2; //number of analog inputs
#else
int kKeyNumAnalog = 0; //number of analog inputs
#endif

#ifdef  IS_TEENSY3
  const int kFirstDigitalInPin = 2; //for example if digital inputs are pins 2..9 then '1', since pins0/1 are UART, this is typically 2
  const int kOutLEDpin = 13; //location of in-built light emitting diode - 11 for Teensy, 13 for Arduino
  const int kOutNum = 7;
  int kOutPin[kOutNum+1] = {0, 10,11,12};
  #define ARM_CPU //Comment this line out 10-bit sampling (0..1023), else 16-bit sampling (0..65535)
  #define ADC_16BIT //Comment this line out 10-bit sampling (0..1023), else 16-bit sampling (0..65535)
  #define USE_BLUETOOTH //Comment this line out to disable bluetooth support
  #ifdef ANALOG_KEYS
    const int kOscMaxChannels = 4; // must be 1..15
  #else
    const int kOscMaxChannels = 14;//The Teensy3 has 14 Analog inputs A0..A13, must be 1..15
  #endif
#endif

#ifdef  IS_TEENSY2
  const int kFirstDigitalInPin = 2; //for example if digital inputs are pins 2..9 then '1', since pins0/1 are UART, this is typically 2
  const int kOutLEDpin = 11; //location of in-built light emitting diode - 11 for Teensy, 13 for Arduino
  const int kOutNum = 5;
  #define USE_BLUETOOTH //Comment this line out to disable bluetooth support
  int kOutPin[kOutNum+1] = {0, 10,12,13,14,15};
  #ifdef ANALOG_KEYS
    const int kOscMaxChannels = 4; // must be 1..15
  #else
    const int kOscMaxChannels = 6; //We will use 6 Analog inputs A0..A5 must be 1..15
  #endif
#endif

#ifdef  IS_LEONARDO
  const int kFirstDigitalInPin = 2; //for example if digital inputs are pins 2..9 then '1', since pins0/1 are UART, this is typically 2
  const int kOutLEDpin = 13; //location of in-built light emitting diode - 11 for Teensy, 13 for Arduino
  const int kOutNum = 3;
  int kOutPin[kOutNum+1] = {0, 10,11,12};
  #ifdef ANALOG_KEYS
    const int kOscMaxChannels = 4; // must be 1..15
  #else
    const int kOscMaxChannels = 6; //LEONARDO has 6 Analog inputs A0..A5, must be 1..15
  #endif
#endif

#ifdef USE_BLUETOOTH 
  HardwareSerial Uart = HardwareSerial();
#endif 

#ifdef ARM_CPU
 //
#else
 //#include <avr/io.h>
 //#include <avr/interrupt.h>
 //#include <avr/sleep.h>
#endif

//MODE VALUES - device can operate as a keyboard, a microsecond timer, or an oscilloscope
const int  kModeKeyboard = 0;
const int kModeuSec = 1;
const int kModeOsc =  2;
int gMode = kModeKeyboard;//kModeKeyboard; //Current mode for device 
//VALUES FOR KEYBOARD MODE
const int kKeyNumDigital = 8;
int kKeyNum = kKeyNumDigital + kKeyNumAnalog; //digital inputs, e.g. if you have 8 buttons and 2 analog inputs, set to 10
const int kMaxKeyNum = kKeyNumDigital + 2; //digital inputs, e.g. if you have 8 buttons and 2 analog inputs, set to 10
char gKeyDown[kMaxKeyNum+1] = {100, '1','2','3','4','5','6','7','8','a','b'}; //key mapping when button depressed
char gKeyUp[kMaxKeyNum+1] = {0, 0,0,0,0,0,0,0,0,0,0}; //key mapping when button depressed
byte gKeyTrigger[kMaxKeyNum+1] = {0, 0,0,0,0,0,0,0,0,0,0}; //key binding - will a digital output line map the key status?
int gKeyOldDownStatus[kMaxKeyNum+1] = {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0}; //keys previously depressed
int gKeyNewDownStatus[kMaxKeyNum+1] = {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0}; //keys currently depressed
unsigned long gKeyTimeLastChange[kMaxKeyNum+1] = {};
//VALUES FOR OSCILLOSCOPE MODE

int gOscChannels = 1; //number of channels to report
int gOscHz = 250; //sample rate in Hz
int gOscSample = 3; //increment sample numbers
unsigned long gOscTimeMsec;



//values stored in EEPROM
//Address : Value
// 0: repeatRateMS
// 1..10: key mapping for down-stroke of buttons 1..10
// 101..110: key mapping for up-stroke of buttons 1..10
// 201..210: key binding for buttons 1..10

//MODE: KEYBOARD (DEFAULT)
// 8 DIGITAL INPUTS
//  pins 2-9 are inputs. When pulled to ground a button press is generated
// 2 THRESHOLED ANALOG INPUTS
//  when votge of A0(A1) exceeds A2(A3) a button press is generated and light on A4(A5) is turned on
// 3 DIGITAL OUTPUT (7 for Teensy)
//   Serial communication can send a byte 0..127 which controls output of pins 10..12, xx..xx

boolean readKeys() { //reads which keys are down, returns true if keys have changed 
  boolean statusChange = false;
  //read digital buttons
  for (int i = 1; i <= kKeyNumDigital; i++) {
      gKeyNewDownStatus[i] = !digitalRead(i+kFirstDigitalInPin-1); 
      if (gKeyNewDownStatus[i] != gKeyOldDownStatus[i]) statusChange = true;
  }
  if (kKeyNumAnalog < 1) return statusChange;
  int c = 0;
  for (int a = 0; a < kKeyNumAnalog; a++) {
        #ifdef PROTO_BOARD
        int ref = analogRead(a*2); //read analog channel
        int value = analogRead((a*2)+1); //read threshold potentiometer
      #else
        int ref = analogRead(a); //read analog channel
        int value = analogRead(a+(kKeyNumAnalog) ); //read threshold potentiometer
      #endif
    int index = kKeyNumDigital+a+1;
    if (value > ref) {
      gKeyNewDownStatus[index] = HIGH;
    } else {
      gKeyNewDownStatus[index] = LOW; 
    }
    if (gKeyNewDownStatus[index] != gKeyOldDownStatus[index]) {
      statusChange = true;
      #ifdef PROTO_BOARD
      digitalWrite(kOutLEDpin+a+1, gKeyNewDownStatus[index]);  //turn analog status light on
      #else
      digitalWrite(A0+kKeyNumAnalog+kKeyNumAnalog+a, gKeyNewDownStatus[index]);  //turn analog status light on
      #endif
    }
  } //for each analog channel
  return statusChange;
} //readKeys()

void writeROM() { //save settings to ROM
  //Keyboard.print('updateROM');
  EEPROM.write(0, gKeyDown[0]);//repeatRateMS
  for (int i = 1; i <= kMaxKeyNum; i++) {
      EEPROM.write(i, gKeyDown[i]);    
      EEPROM.write(i+100, gKeyUp[i]); 
      EEPROM.write(i+200, gKeyTrigger[i]);
  } 
} //writeROM()

void readROM() {
  //writeROM(); return;
  if (EEPROM.read(0) == 0) { //initialize EEPROM
    writeROM();
    return;
  } 
    gKeyDown[0] = EEPROM.read(0);//repeatRateMS
    for (int i = 1; i <= kMaxKeyNum; i++) {
      gKeyDown[i] = EEPROM.read(i);    
      gKeyUp[i] = EEPROM.read(i+100);
      gKeyTrigger[i] = EEPROM.read(i+200);
    }
} //readROM()

void setup()
{
  analogReference(DEFAULT);  //  set range: analogReference(DEFAULT); or analogReference(INTERNAL); 
  #ifdef ADC_16BIT
    analogReadRes(16);          // Teensy 3.0: set ADC resolution to this many bits
  #endif
  readROM();
  //set KEY values - inputs
  unsigned long timeNow = millis();
  for (int i = 0; i <= kMaxKeyNum; i++)
    gKeyTimeLastChange[i] = timeNow;    
  for (int i = kFirstDigitalInPin; i < (kFirstDigitalInPin+kKeyNumDigital); i++) {
    pinMode(i, INPUT);           // set pin to input
    digitalWrite(i, HIGH);       // turn on pullup resistors
  } 

  readKeys(); //scan inputs
  for (int i = 1; i <= kMaxKeyNum; i++)
    gKeyOldDownStatus[i] = gKeyNewDownStatus[i];
  //Set OUT values - digital outputs
  for (int i = 1; i <= (kOutNum); i++)  //set analog status lights as outputs1
    pinMode(kOutPin[i], OUTPUT); //lights that signal if an LED is on
  
  pinMode(kOutLEDpin, OUTPUT); //set light as an output
  digitalWrite(kOutLEDpin, HIGH);

  Serial.begin(BAUD_RATE);
  #ifdef USE_BLUETOOTH
    Uart.begin(BAUD_RATE);
  #endif
} //setup()

void sendUSec() {
  const int numSerialBytes = 8; 
  const byte kuSecSignature = 254;
  byte serialBytes[numSerialBytes];
  int keyBits = 0;
  unsigned long uSec = micros();
  for (int i = 1; i <= kKeyNum; i++) 
          if (gKeyNewDownStatus[i] > 0) keyBits = keyBits + (1 << (i-1));
  serialBytes[0] = kuSecSignature;//gKeyRepeatRateMS; //debounceTime
  serialBytes[1] = ( keyBits >> 8) & 0xff; //keys 9..16 as bits 8..15
  serialBytes[2] = ( keyBits & 0xff);       //keys 1..8 as bits 0..7
  serialBytes[3] = ( uSec >> 24) & 0xff; //event time bits 24..31
  serialBytes[4] = ( uSec >> 16) & 0xff; //event time bits 16..23
  serialBytes[5] = ( uSec >> 8) & 0xff; //event time bits 8..15
  serialBytes[6] = ( uSec & 0xff);    //event time bits 0..7
  int checkSum = 0;
  for (int i = 0; i <= (numSerialBytes-2); i++) 
     checkSum = checkSum + serialBytes[i];
  while (checkSum > 0xff) checkSum=(checkSum >> 8)+(checkSum & 0xff); 
  serialBytes[numSerialBytes-1] = checkSum;
  Serial.write(serialBytes, numSerialBytes);  
  #ifdef USE_BLUETOOTH
    Uart.write(serialBytes, 8);
  #endif
} //sendUSec()



//#define SIMULATE_DATA //create fake data
#ifdef SIMULATE_DATA
   int gSamp = 0;
#endif

void sendOsc(void) {   
  if ((gOscChannels < 1) || (gOscChannels > kOscMaxChannels)) return;
  int numSerialBytes = 4+ (2 * gOscChannels); //16-bits per channel + 4 bytes header and checksum
  byte serialBytes[numSerialBytes];
  //sample inputs
  int analogInput[gOscChannels];
  for (int i = 0; i < gOscChannels; i++) 
    analogInput[i] = analogRead(i);
  #ifdef SIMULATE_DATA
   gSamp = gSamp + 1;
   #ifdef ADC_16BIT
     if (gSamp > 64000) gSamp = 0;
   #else
     if (gSamp > 900) gSamp = 0;
   #endif
   for (int i = 0; i < gOscChannels; i++) 
     analogInput[i] = gSamp+(i * 10);
  #endif //only if simulatedata
  byte digitalInput = 0;
  for (int i = 0; i < kKeyNumDigital; i++) 
    digitalInput = digitalInput + ((!digitalRead(i+kFirstDigitalInPin)) << i); 
  gOscSample = gOscSample +1;
  if (gOscSample == 4) gOscSample = 0; //we sample the milliseconds every 4th sample
  if (gOscSample == 0) gOscTimeMsec  = millis();  
  #ifdef ADC_16BIT
    serialBytes[0] = (1 << 6) +(gOscSample << 4) + gOscChannels; //set flag for 16-bit data
  #else
    serialBytes[0] = (gOscSample << 4) + gOscChannels;
  #endif
  serialBytes[1] = (gOscTimeMsec >> (8*(3- gOscSample)))  & 0xff;//TIMING, from bits 31..24 gOscSample=0 to bits 7..0 when gOscSample = 3
  serialBytes[2] = digitalInput;
   for (int i = 0; i < gOscChannels; i++) {
    serialBytes[3+(i*2)] = (analogInput[i] >> 8) & 0xff;
    serialBytes[4+(i*2)] = analogInput[i]  & 0xff;
  }
  int checkSum = 0;
  for (int i = 0; i <= (numSerialBytes-2); i++) 
     checkSum = checkSum + serialBytes[i];
  while (checkSum > 0xff) checkSum=(checkSum >> 8)+(checkSum & 0xff); 
  serialBytes[numSerialBytes-1] = checkSum;
  Serial.write(serialBytes, numSerialBytes);
  #ifdef USE_BLUETOOTH
    Uart.write(serialBytes, 8);
  #endif
}

#ifdef  ARM_CPU

// Constants for bitvalues within the TCTRL1 register
#define TIE 2
#define TEN 1

void pit1_isr(void) {  //ARM interrupt  
  PIT_TFLG1 = 1; 
  sendOsc();
}

void timer_setup() { //setup ARM interupts
  //see https://github.com/loglow/PITimer/blob/master/PITimer.cpp
  SIM_SCGC6 |= SIM_SCGC6_PIT; // Activates the clock for PIT
  PIT_MCR = 0x00; // Turn on PIT
  // Set the period of the timer.  The µC runs at F_BUS (48MHz on Teensy3)
  // So interrupt length can be determined by F_BUS/FREQ.
  PIT_LDVAL1 = F_BUS/gOscHz-1; //a 32-bit unsigned integer, -1 since timer resets to 0 not 1 
  PIT_TCTRL1 = TIE; // Enable interrupts on timer1
  PIT_TCTRL1 |= TEN; // Start the timer
  NVIC_ENABLE_IRQ(IRQ_PIT_CH1); // Another step to enable PIT channel 1 interrupts
}

void timer_stop() {
  NVIC_DISABLE_IRQ(IRQ_PIT_CH1); //stop timer for oscilloscope 
}
#else //not ARM_CPU : assume this device uses an Atmel AVR CPU

ISR(TIMER1_COMPA_vect)//timer0 interrupt
{
  sendOsc();
}

void timer_setup() {
  cli();                                     // disable interrupts while messing with their settings
  // Mode 4, CTC using OCR1A
   // TCCR1A = 1<<WGM12;  // WGM12 is not located in the TCCR1A register
   TCCR1A = 0;
  // CS12 CS11 CS10 prescaler these 3 bits set clock scaling, e.g. 0,1,0= 8, so 8Mhz CPU will increment timer at 1MHz 
  //    0    0    1  /1
  //    0    1    0  /8
  //    0    1    1  /64 *  2000 Hz
  //    1    0    0  /256   500 Hz
  //    1    0    1  /1024  125 Hz
  int prescaler = 1;
  if (gOscHz < 250) prescaler = 8;
  if (gOscHz < 50) prescaler = 64;
  if (gOscHz < 5) prescaler = 256;
  switch (prescaler) { 
    case 1:
      TCCR1B = (1 << WGM12) | (1<<CS10); 
      break;
    case 8:
       TCCR1B = (1 << WGM12) | (1<<CS11);
       break;
    case 64:
      TCCR1B = (1 << WGM12) | (1<<CS10) | (1<<CS10);
      break;
    case 256:
       TCCR1B = (1 << WGM12) | (1<<CS12);
       break;
    default: 
      TCCR1B = (1 << WGM12) | (1<<CS12)  | (1<<CS10); // /1024
  }
  // Set OCR1A for running at desired Hz
   OCR1A = ((F_CPU/ prescaler) / (gOscHz)) - 1;   //a 16-bit unsigned integer -1 as resets to 0 not 1
   TIMSK1 = 1<<OCIE1A;
  sei(); // turn interrupts back on
}  

void timer_stop() {
  cli();  // disable interrupts while messing with their settings, aka noInterrupts(); 
  TIMSK1 = 0; //disable timer1 
    sei(); // turn interrupts back on, aka interrupts();         
}//timer_stop

#endif

void sendGetResponse(byte b2, byte b3, byte b4) { //report key press mapping for pin bitIndex 
  byte serialBytes[kCmdLength];
        serialBytes[0] = kCmd1Get; 
        serialBytes[1] = b2; 
        serialBytes[2] = b3;
        serialBytes[3] = b4;
        Serial.write(serialBytes, kCmdLength);
        #ifdef USE_BLUETOOTH
        Uart.write(serialBytes, 8);
        #endif  
} //sendGetResponse()

boolean isNewCommand(byte Val) {
//responds to any commands from PC - either reporting settings or changing settings
//update queue of recent bytes
 for (int i = 1; i < kCmdLength; i++) //e.g. 1 to 3
   gCmdPrevBytes[i-1] = gCmdPrevBytes[i];
 gCmdPrevBytes[kCmdLength-1] = Val;
 boolean possibleCmd = false;
 if ((gCmdPrevBytes[0] == kCmd1Set) ) 
     possibleCmd = true; 
 for (int i = 0; i < kCmdLength; i++) {//e.g. 0 to 3
   if ((gCmdPrevBytes[i] == kCmd1Get) ) 
     possibleCmd = true;  
 }
 if (!possibleCmd)
   return possibleCmd; //input is not a new command
 if ((gCmdPrevBytes[0] != kCmd1Set) && (gCmdPrevBytes[0] != kCmd1Get) )
   return possibleCmd; //only part of a Command has been received...wait for the complete message
 switch (gCmdPrevBytes[1]) { //decode the command
   case kCmd2Mode: //command: mode
        if (gCmdPrevBytes[0] == kCmd1Get) {
         //sendMode;
         byte mode34 = kCmd34ModeKey;
         if (gMode == kModeuSec) mode34 = kCmd34ModeuSec;
         if (gMode == kModeOsc) mode34 = kCmd34ModeOsc;
         sendGetResponse(kCmd2Mode,mode34,mode34);
         break; 
        }
        if ((gCmdPrevBytes[2] == kCmd34ModeuSec) && (gCmdPrevBytes[3] == kCmd34ModeuSec))  {
          gMode = kModeuSec; //switch to microsecond mode
        }
        if ((gCmdPrevBytes[2] == kCmd34ModeKey) && (gCmdPrevBytes[3] == kCmd34ModeKey)) {
          timer_stop();
          gMode = kModeKeyboard; //switch to keyboard mode
          digitalWrite(kOutLEDpin,HIGH); //ensure power light is on
        }
        if ((gCmdPrevBytes[2] == kCmd34ModeOsc) && (gCmdPrevBytes[3] == kCmd34ModeOsc)) {
          gMode = kModeOsc;  //switch to Oscilloscope mode 
          timer_setup(); //turn on timer   
        } 
        break;
   case kCmd2KeyDown: //keyDown
        if ((gCmdPrevBytes[2] < 0) || (gCmdPrevBytes[2] > kKeyNum)) return possibleCmd;
        if (gCmdPrevBytes[0] == kCmd1Get) {
          sendGetResponse(kCmd2KeyDown,gCmdPrevBytes[2],gKeyDown[gCmdPrevBytes[2]]);
          break; 
        }
        gKeyDown[gCmdPrevBytes[2]] = gCmdPrevBytes[3];
        break;
   case kCmd2KeyUp: //key release mapping
        if ((gCmdPrevBytes[2] < 0) || (gCmdPrevBytes[2] > kKeyNum)) return possibleCmd;
        if (gCmdPrevBytes[0] == kCmd1Get) {
          sendGetResponse(kCmd2KeyUp,gCmdPrevBytes[2],gKeyUp[gCmdPrevBytes[2]]);
         break; 
        }
        gKeyUp[gCmdPrevBytes[2]] = gCmdPrevBytes[3];        
        break;
   case kCmd2KeyTrigger: //key release mapping
        if ((gCmdPrevBytes[2] < 0) || (gCmdPrevBytes[2] > kKeyNum)) return possibleCmd;
        if (gCmdPrevBytes[0] == kCmd1Get) {
          sendGetResponse(kCmd2KeyTrigger,gCmdPrevBytes[2],gKeyTrigger[gCmdPrevBytes[2]]);
          break; 
        }
        gKeyTrigger[gCmdPrevBytes[2]] = gCmdPrevBytes[3];          
        break;
   case kCmd2NumAnalogKeys: //number of analog keys supported
        if (gCmdPrevBytes[0] == kCmd1Get) {
          sendGetResponse(kCmd2NumAnalogKeys,(kKeyNumAnalog >> 8) & 0xff,kKeyNumAnalog & 0xff);
          break; 
       }
       //kKeyNumAnalog = (gCmdPrevBytes[2] << 8) + gCmdPrevBytes[3];   
      //if (kKeyNumAnalog < 0) kKeyNumAnalog = 0;
      //if (kKeyNumAnalog > kMaxNumAnalog) kKeyNumAnalog = kMaxNumAnalog;
       break;
   case kCmd2OscHz: //oscilloscope sampling rate
        if (gCmdPrevBytes[0] == kCmd1Get) {
          sendGetResponse(kCmd2OscHz,(gOscHz >> 8) & 0xff,gOscHz & 0xff);
          break; 
        }       
        gOscHz =  (gCmdPrevBytes[2] << 8) + gCmdPrevBytes[3];
        if (gMode == kModeOsc) {  //if timer is running, reset timer with new speed
          timer_stop(); //halt previous timer   
          timer_setup(); //turn on timer   
        } 
        break;
   case kCmd2OscChannels: //osciloscope channels
        if (gCmdPrevBytes[0] == kCmd1Get) {
          sendGetResponse(kCmd2OscChannels,(gOscChannels << 8) & 0xff,gOscChannels & 0xff);
          break; 
        }       
        gOscChannels =  (gCmdPrevBytes[2] >> 8) + gCmdPrevBytes[3];
        if (gOscChannels > kOscMaxChannels) gOscChannels = kOscMaxChannels;
        if (gOscChannels < 1) gOscChannels = 1;
        break;
    case kCmd2EEPROMSAVE: //save EEPROM
      if ((gCmdPrevBytes[0] == kCmd1Set) && (gCmdPrevBytes[1] == kCmd2EEPROMSAVE) && (gCmdPrevBytes[2] == kCmd2EEPROMSAVE) && (gCmdPrevBytes[3] == kCmd2EEPROMSAVE))
          writeROM();
      break;
    //default : //if no known message type 
 } //switch
 return possibleCmd;
} //isNewCommand()

void writePins(byte Val) {
  for (int i = 1; i <= kOutNum; i++) {
    if ((( Val >> (i-1)) & 0x01) == 1) 
      digitalWrite(kOutPin[i],HIGH);
    else 
       digitalWrite(kOutPin[i],LOW);
   } 
} //writePins

void sendTrigger(byte Index, int Val) {
  if ((Index < 1) || (Index > kOutNum)) return;
  digitalWrite(kOutPin[Index],Val);
} //sendTrigger()

void loop() {
 unsigned long timeNow = millis();
 if ((gMode == kModeKeyboard) || (gMode == kModeuSec)) {
   //READ digital inputs
   boolean newStatus = false;
   readKeys();
   for (int i = 1; i <= kKeyNum; i++) {
     if (gKeyNewDownStatus[i] != gKeyOldDownStatus[i]) {
       if (gKeyNewDownStatus[i] > 0)  { //downPress
         if ( (timeNow > ( gKeyTimeLastChange[i]+gKeyDown[0]))  || (timeNow < gKeyTimeLastChange[i]) )  {//gKeyDown[0] = repeatRate
           if ((gMode == kModeKeyboard) && (gKeyDown[i] > 0)) Keyboard.print(gKeyDown[i]);
           sendTrigger(gKeyTrigger[i],HIGH);
           newStatus = true;
           gKeyTimeLastChange[i] = timeNow; 
           gKeyOldDownStatus[i] = gKeyNewDownStatus[i];
         }//debounce
       }//down press
       if (gKeyNewDownStatus[i] == 0)  { //upPress
        if ( (timeNow > ( gKeyTimeLastChange[i]+gKeyDown[0]))  || (timeNow < gKeyTimeLastChange[i]) )  { //gKeyDown[0] = repeatRate
          if ((gMode == kModeKeyboard) && (gKeyUp[i] > 0)) Keyboard.print(gKeyUp[i]);
          sendTrigger(gKeyTrigger[i],LOW);
          newStatus = true;
          gKeyTimeLastChange[i] = timeNow;
          gKeyOldDownStatus[i] = gKeyNewDownStatus[i];
         } //debounce
       } //up press
     } //if key change
   } //for each key
   #ifndef IS_LEONARDO
   if ((gMode == kModeKeyboard) && (newStatus))  Keyboard.send_now();
   #endif
   if ((gMode == kModeuSec) && (newStatus))  sendUSec();
   //BLINK power light in uSec mode
  if (gMode == kModeuSec) {
    int modulo = timeNow % 1000; 
    if ((modulo == 1) || (modulo == 201) ) digitalWrite(kOutLEDpin, HIGH);
    if ((modulo == 100) || (modulo == 300)) digitalWrite(kOutLEDpin, LOW);   
  } //ModeUSec   
 } 
  //Write digtal outputs - check for new commands
  if (Serial.available()) {
        while (Serial.available()) {
          byte val = Serial.read();
          if (!isNewCommand(val)) writePins(val);
        }
   } 
   #ifdef USE_BLUETOOTH
   if (Uart.available()) {
        while (Uart.available()) {
          byte val = Uart.read();
          if (!isNewCommand(val)) writePins(val);
        }
   }
   #endif
   //flash status light in Oscilloscope mode
   if (gMode == kModeOsc) {
    int modulo = timeNow % 1000;
    if (modulo == 1)  digitalWrite(kOutLEDpin, HIGH);
    if (modulo == 500) digitalWrite(kOutLEDpin, LOW);

   }
} //loop()

// Bluetooth Programming Sketch for Teensy 3.0 v0.9
// By: Chris Rorden based on Arduino code by Ryan Hunt <admin@nayr.net>
// License: CC-BY-SA
//
// Standalone Bluetooth Programer for setting up inexpensive bluetooth modules running linvor firmware.
// This Sketch expects a BT device to be plugged in upon start. 
// You can open Serial Monitor to watch the progress or wait for the LED to blink rapidly to signal programing is complete.
// If programming fails it will enter command where you can try to do it manually through the Arduino Serial Monitor.
// When programming is complete it will send a test message across the line, you can see the message by pairing and connecting
// with a terminal application. (screen for linux/osx, hyperterm for windows)
//
// Hookup BT-RX to PIN 1 (Arduino TX), BT-TX to PIN 0 (Arduino-RX), 5v and GND to your bluetooth module.
//
// WARNING: Some Arduino's (Uno) and Teensy 2 use 5v signalling, but Bluetooth expects 3.3v. For these devices use a voltage divider
//            http://www.instructables.com/id/Cheap-2-Way-Bluetooth-Connection-Between-Arduino-a/step3/Wiring-the-Arduino-Bluetooth-transceiver/
//         Fortunately,  Teensy3 and Leonardo use 3.3v signalling so they can be connected directly without resistors
//
// Defaults are for OpenEMG Use, For more information visit: http://wiki.openpilot.org/display/Doc/Serial+Bluetooth+Telemetry
//  For details see https://github.com/ArcBotics/Hexy/wiki/Bluetooth


#define Hardserial //define Hardserial for Teensy3, for Arduino Leonardo comment out this line


 char* name =     "bt922k1234"; //any name you want - Teensy set hard serial name to usbmodem12341, so string "1234" can help detect if Teensy is attached, you could also add pin number (0000)
 char*  pin =         "0000";                    // Pairing Code for Module, 4 digits only.. (0000-9999)
 int led =         13;                      // Pin of Blinking LED, default should be fine.
 
 #ifdef Hardserial
   HardwareSerial bt = HardwareSerial(); 
 #else
   //#include <SoftwareSerial.h> //warning: you probably need to comment this line out for Hardserial (Arduino compiler still uses includes despite ifdef clauses
   SoftwareSerial    bt(0, 1);  //If you get an error here: uncomment line "#define Hardserial"
 #endif

 long bps =         921600; //options 1200, 2400, 4800, 9600, 19200, 38400, 57600,115200, 230400, 460800, 921600, 1382400
 const int numPossibleBps = 12;
 int possibleBps[numPossibleBps] = {1200, 2400, 4800, 9600, 19200, 38400, 57600,115200, 230400, 460800, 921600, 1382400};
 long origBpsIndex = 3; //original BPS - typically 3rd index = 9600 bps
 int wait =        1000;                    // How long to wait between commands (1s), dont change this.
 
 void setup()
{
  pinMode(led, OUTPUT);
  Serial.begin(possibleBps[origBpsIndex]);                      // Speed of Debug Console
  Serial.println("Configuring bluetooth module for use with OpenEMG, please wait.");
  digitalWrite(led, HIGH);                 // Turn on LED to signal programming has started
  //attempt connection
  int index = index;
  bt.begin(possibleBps[index]);                          // Speed of your bluetooth module, 9600 is default from factory.
  delay(wait);
  bt.print("AT");
  delay(wait);
  //test for good connection
  int resp = bt.read();
  if (resp == -1) index = 0;
  while ((resp == -1) && (index < numPossibleBps)) {
     bt.begin(possibleBps[index]);// Speed of your bluetooth module, 9600 is default from factory.
     Serial.print("Attempting to connect at "); Serial.print(possibleBps[index]); Serial.println("bps");
     delay(wait);
     bt.print("AT");
     delay(wait);
     resp = bt.read();
     if (resp == -1) index ++;
  } //while no response
  if (resp == -1) {
    Serial.println("ERROR: no response from Bluetooth device. Please check connections and origbps ");
    digitalWrite(led, LOW);
  } else {
     Serial.print("Successfully connected at "); Serial.print(possibleBps[index]); Serial.println("bps");  
  }   
  bt.print("AT+VERSION");
    delay(wait);
 
    
  Serial.print("Setting PIN : ");          // Set PIN
  Serial.println(pin);
  bt.print("AT+PIN"); 
  bt.print(pin); 
    delay(wait);
  Serial.print("Setting NAME: ");          // Set NAME
  Serial.println(name);
  bt.print("AT+NAME");
  bt.print(name); 
    delay(wait);
  Serial.print("Setting BAUD: "); Serial.println(bps); //Report baud rate
  switch (bps) {
    case 1200:
      bt.print("AT+BAUD1");
      break;
    case 2400:
      bt.print("AT+BAUD2");
      break;
    case 4800:
      bt.print("AT+BAUD3");
      break;
    case 9600:
      bt.print("AT+BAUD4");
      break;
    case 19200:
      bt.print("AT+BAUD5");
      break;
    case 38400:
      bt.print("AT+BAUD6");
      break;
    case 57600:
      bt.print("AT+BAUD7");
      break;
    case 115200:
      bt.print("AT+BAUD8");
      break;
    case 230400:
       bt.print("AT+BAUD9");
       break;
    case 460800:
      bt.print("AT+BAUDA");
      break;
    case 921600:
      bt.print("AT+BAUDB");
      break;
    case 1382400:
      bt.print("AT+BAUDC");
      break;  
    default: 
      bt.print("AT+BAUD4"); //9600 
      Serial.println("WARNING: Unknown baud rate - setting to default 9600bps"); 
  }
  delay(wait);
  Serial.println("Hopefully bluetooth device is reset");
}

void loop() {
  // nothing to do, its all in the interrupt handler!
}  
 

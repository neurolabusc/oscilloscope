// Bluetooth Programming Sketch for Arduino v1.1
// By: Ryan Hunt <admin@nayr.net>
// License: CC-BY-SA
//
// Standalone Bluetooth Programer for setting up inexpnecive bluetooth modules running linvor firmware.
// This Sketch expects a BT device to be plugged in upon start. 
// You can open Serial Monitor to watch the progress or wait for the LED to blink rapidly to signal programing is complete.
// If programming fails it will enter command where you can try to do it manually through the Arduino Serial Monitor.
// When programming is complete it will send a test message across the line, you can see the message by pairing and connecting
// with a terminal application. (screen for linux/osx, hyperterm for windows)
//
// Hookup BT-RX to PIN 11, BT-TX to PIN 10, 5v and GND to your bluetooth module.
//
// Defaults are for OpenEMG Use, For more information visit: http://wiki.openpilot.org/display/Doc/Serial+Bluetooth+Telemetry

#include <SoftwareSerial.h>
#define k230
// --- START CONFIGURATION ---
#ifdef k230
 char* name =     "OpenEMG230K";           // Name for Bluetooth Device. (alphanumeric, 20 char max, no spaces)
#else
 char* name =     "OpenEMG57K";           // Name for Bluetooth Device. (alphanumeric, 20 char max, no spaces)
#endif

#ifdef k230
 long bps =         230400;                    // Pairing Code for Module, 4 digits only.. (0000-9999)
#else
 long bps =         57600;                    // Pairing Code for Module, 4 digits only.. (0000-9999)
#endif
char*  pin =         "0000";                    // Pairing Code for Module, 4 digits only.. (0000-9999)
long origbps = 115200; //original BPS - typically 57600
int led =         13;                      // Pin of Blinking LED, default should be fine.
SoftwareSerial    bt(10, 11);              // Pins for RX, TX on Arduino Side.
char* testMsg =   "OpenEMG"; //
                                           // --- END CONFIGURATION ---

int wait =        1000;                    // How long to wait between commands (1s), dont change this.
char* response = "OKOKlinvorV1.5OKsetPINOKsetnameOK57600"; // Expected response from BT module after programming is done.

void setup()
{
  pinMode(led, OUTPUT);
  Serial.begin(9600);                      // Speed of Debug Console
  Serial.println("Configuring bluetooth module for use with OpenEMG, please wait.");

  bt.begin(origbps);                          // Speed of your bluetooth module, 9600 is default from factory.
  digitalWrite(led, HIGH);                 // Turn on LED to signal programming has started
    delay(wait);
  bt.print("AT");
    delay(wait);
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
  Serial.print("Setting BAUD: ");   // Set baudrate to 57600
  Serial.println(bps); 
  if (bps = 230400) {
    bt.print("AT+BAUD9"); 
    Serial.println(" HIGH SPEED");    
  } else {
    bt.print("AT+BAUD7");                   
  }
   delay(wait);
  
  if (verifyresults()) {                   // Check configuration
    Serial.println("Configuration verified, entering test mode..");
    Serial.println("To do another module plug it in and then hit reset");
    testloop();                            // Start Test Loop
  } 
   digitalWrite(led, LOW);                 // Turn off LED to show failure.
   Serial.println("Entering Command mode, you can now attempt a manual configuration");
}

void loop()                                // If verification fails lets bridge the serial ports so programming can be done manually.
{
  if (bt.available())
    Serial.write(bt.read());               // Pipe Bluetooth to Debug Console
  if (Serial.available())
    bt.write(Serial.read());               // Pipe Debug Console to Bluetooth
} 

int verifyresults() {                      // This function grabs the response from the BT Module and compares it for validity.
  int makeSerialStringPosition;
  int inByte;
  char serialReadString[50];
  
  inByte = bt.read();
  makeSerialStringPosition=0;
  if (inByte > 0) {                                                // If we see data (inByte > 0)
    delay(100);                                                    // Allow serial data time to collect 
    while (makeSerialStringPosition < 38){                         // Stop reading once the string should be gathered (37 chars long)
      serialReadString[makeSerialStringPosition] = inByte;         // Save the data in a character array
      makeSerialStringPosition++;                                  // Increment position in array
      inByte = bt.read();                                          // Read next byte
    }
    serialReadString[38] = (char) 0;                               // Null the last character
    if(strncmp(serialReadString,response,37) == 0) {               // Compare results
     return(1);                                                    // Results Match, return true..
     }
     Serial.print("VERIFICATION FAILED!!!, EXPECTED: ");           // Debug Messages
     Serial.println(response);
     Serial.print("VERIFICATION FAILED!!!, RETURNED: ");           // Debug Messages
     Serial.println(serialReadString);
     return(0);                                                    // Results FAILED, return false..
  }
}

void testloop() {                          // This function is ran when programming is complete.
  bt.end();
  bt.begin(bps);                         // Reconnect @ 57600 BAUD.
  while(1) {                               // Begin Endless Loop.
    bt.println(testMsg);                   // Send this string out the BT Module.
    digitalWrite(led, LOW);                // Flash the LED on and off to signal programing is complete.
    delay(250);            
    digitalWrite(led, HIGH);
    delay(250);
  }
}

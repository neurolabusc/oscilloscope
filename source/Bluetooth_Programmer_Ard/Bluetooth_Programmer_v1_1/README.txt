The purpose of this sketch is to quickly and painlessly configure a Linvor based Bluetooth Device for use with OpenPilot. There's many ways to do this but alot of us may have an Arduino in the drawer and the process can be quite tricky if your not aware. I wanted a standalone system that could be used for rapid programing of a stack of modules, having it verify the settings took and sending data over bluetooth was very important to ensure quality.. Blindly sending commands without checking output was not acceptable so this is what I came up with.

here is how it operates:
	1	Initializes the standard serial port for status output.
	2	Initializes pins 10 & 11 as a serial port to connect to the Bluetooth Module.
	3	Turns LED on to signal programming has started.
	4	Sends all the commands needed in at a very specific rate while updating status.
	5	Verifies the output from the BT module matches what is expected.
	6	If Verification passes - enter a test mode where LED flashes and a string is sent to the BT module in an infinite loop.
	7	If Verification fails - LED is turned off & it shows the returned output before entering a command mode where you can attempt direct configuration.
	8	(optional) When done testing you can plugin another module then reset the Arduino to repeat the process.
Simply write the code to your Arduino and hookup the BT module as documented in the script.. It can operate in standalone mode w/no PC connected.
There is a configuration section at the top of the sketch if you wish to modify any of the default values.

Copyright CC-BY-SA by Ryan Hunt <admin@nayr.net>
More info: http://forums.openpilot.org/topic/15044-bluetooth-programming-sketch-for-arduino/
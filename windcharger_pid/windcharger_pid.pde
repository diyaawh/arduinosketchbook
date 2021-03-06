

/* 
    TODO
    * add something that changes the setpoint depending on the battery's health.
    * add RPM (hw/sw)
    * add logging to pachube
*/

#include <PID_v1.h>
#include <TimedAction.h>
#include <LiquidCrystal.h>
#include <EEPROM.h>

//system variables
#define LOW_BATTERY_VOLTAGE 10.0
//#define DEBUG //define this for PID debugging
#define CURRENT_CHARGING_VALUE 50
#define SERIAL_LOG

//ERRORS
#define ERR_LOW_BATTERY 1

//global vars
//PID vars
double Setpoint;
unsigned int rawCurrent = 0, avgCurrent = 0, rawTurbineVoltage = 0;
double rawBattVoltage, dumpPercent, pwmDumpLoad = 255, current,turbineVoltage,battVoltage; //real values
boolean statusLED = false;
#define numErrors 1
boolean errors[numErrors];
byte history [16];
char buff[8];
const int currentArrayLength = 5;
int rawCurrentArray [currentArrayLength];
unsigned int eepromLogAddress;

//timed actions
TimedAction actionUpdateLCD = TimedAction(500,updateLCD);
TimedAction actionFlashLED = TimedAction(500,flashLED);
TimedAction actionUpdateElectrical = TimedAction(100,updateElectrical);
TimedAction actionCheckBattery = TimedAction(2000,checkBattery); //2 secs
TimedAction actionAddToHistory = TimedAction(300000,addToHistory); //5 minutes
#ifdef DEBUG
TimedAction actionRXTXPID = TimedAction(200,RXTXPID);
#endif
#ifdef SERIAL_LOG
TimedAction actionSerialLog = TimedAction(200,serialLog);
#endif

//PID: Specify the links and initial tuning parameters
//for details on tuning params see http://en.wikipedia.org/wiki/PID_controller
//PID myPID(&rawBattVoltage, &pwmDumpLoad, &Setpoint,0.01,1,0, REVERSE); //DIRECT
PID myPID(&battVoltage, &pwmDumpLoad, &Setpoint,25,40,5, DIRECT); //DIRECT
//TODO lcd setup
// rs (4), enable (6) , d4 (11), d5 (12), d6(13), d7(14)) 
LiquidCrystal lcd(A3, A4, A5, 13,3,4);

//control pin defs
#define PIN_pwmDumpLoad 10
//TODO
#define PIN_ledGreen 7
#define PIN_ledRed 6
#define PIN_phoneChargerSwitch 9
//analog input pin defs
#define PIN_battVoltage A0
#define PIN_turbineVoltage A1
#define PIN_current A2


void setup()
{
  Serial.begin(9600);
  Serial.println( "started" );
  setupErrors();
  createBars();
  //pin setups
  pinMode( PIN_ledGreen, OUTPUT );
  pinMode( PIN_ledRed, OUTPUT );
  pinMode( PIN_phoneChargerSwitch, OUTPUT );
  digitalWrite( PIN_ledGreen, LOW );
  digitalWrite( PIN_ledRed, LOW );  
  lcd.begin(16, 2);
  lcd.clear();
  lcd.setCursor(0,0);
  lcd.print("wind charger" );
  delay(1000);
  initialiseAvgArray( rawCurrentArray, currentArrayLength );
  calibrate();
  //get first readings before enabling PID
  updateElectrical();
  
  Setpoint = 13.0; //v
  myPID.SetSampleTime(200); //ms
  //turn the PID on
  myPID.SetMode(AUTOMATIC);
}


void loop()
{

  myPID.Compute();
  //as we don't ever want to put a dump load on the battery
  if( turbineVoltage < battVoltage )
    pwmDumpLoad = 255;
  analogWrite(PIN_pwmDumpLoad,pwmDumpLoad);
  
  //repeating stuff
  actionUpdateLCD.check();
  actionUpdateElectrical.check();
  actionFlashLED.check();
  actionCheckBattery.check();
 // actionAddToHistory.check();
  
#ifdef DEBUG 
  actionRXTXPID.check();
#endif
#ifdef SERIAL_LOG
  actionSerialLog.check();
#endif
  
}



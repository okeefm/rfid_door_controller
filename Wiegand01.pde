#include <avr/interrupt.h>
#include <avr/io.h>
#include <EEPROM.h>
#include <Servo.h>

unsigned char timeout;
unsigned char time_idx;
unsigned char num_entries;
unsigned int cards[255];
unsigned int apt[10] = { 40269, 22862, 25007, 44476, 32088, 28931, 273, 45016, 25965, 22161 };
// { Tergis, Archie, Wickberg, Okeefe, McMullan, Prime, Greg, Tom, Maggie, Gearns }
char num_apt = 10;
unsigned int card;
unsigned int lastcard;
unsigned char card_idx;
boolean partymode;
boolean card_read;
Servo servo;
char open;
unsigned char pos;
char buttonlast;
char close;
boolean card_present;
boolean card_timr;
unsigned long lock_idx;
boolean servotimer;
int servoidx;

void setup(){
  Serial.begin(19200);
  card = 0x00000000;
  card_idx = 0;
  lastcard = 0;
  card_read = false;
  partymode = false;
  servotimer = false;
  servoidx = 0;
  Serial.println("Initializing Timer");  
  time_idx = 0;
  buttonlast = 0;
  open = 145;
  close = 30;
  timeout = 30;
  attachInterrupt(0, int0, FALLING);
  attachInterrupt(1, int1, FALLING);
  TCCR2A = 0;
  TCCR2B |= (1 << CS22)|(1 << CS20);
  TIMSK2 |= (1 << TOIE2);
  Serial.println("Reading EEPROM");
  num_entries = EEPROM.read(0);
  for (int i=0;i<num_entries;i++){
    cards[i] = EEPROM.read((i*2)+1) << 8;
    cards[i] |= EEPROM.read((i*2)+2);
  }
  Serial.println("Other misc Setup...");
  pinMode(4, INPUT);  
  pinMode(5, INPUT);
  pinMode(6, OUTPUT);  
  Serial.println("Initialized!");
}

void loop(){
  menu();
  digitalWrite(6,LOW);
  servo.attach(9);
  card = 0;
  pos = open;
  servo.attach(9);
  servo.write(pos);
  while(1){
    checker();
    //servotune();
  }
}

void servotune(){
  Serial.println(pos,DEC);
    while(Serial.available() < 0) {}
    char temp = Serial.read();
    if (temp == 'w')
      pos = pos+2;
    else if (temp == 's')
      pos = pos-2;
    servo.attach(9);
    servo.write(pos);
    servotimer = true;
}

void checker(){
  if (card_read){
      if ((card_exists(card))&(lastcard == card)){
        Serial.println("Duplicate swipe! Closing.");
        pos = close;
        servo.attach(9);
        servotimer = true;
        card_timr = true;
        lock_idx = 0;
        lastcard = 0;
      } else if (card_exists(card)){
        Serial.println("Good card!");
        pos = open;
        servo.attach(9);
        servotimer = true;
        card_timr = true;
        lock_idx = 0;
        lastcard = card;
      } else {
        Serial.println("Bad card!");
        pos = close;
        servo.attach(9);
        servotimer = true;
      }
      card = 0;
      card_read = false;
      buttonlast = 0;
    }
    if ((digitalRead(4) == 1)&(buttonlast != 4)){
      Serial.println("Door Close (switch)");
      pos = close;
      servo.attach(9);
      servotimer = true;
      buttonlast = 4;
    }
    if ((digitalRead(5) == 1)&(buttonlast != 5)&(lastcard != 0)){
      if (partymode){
        partymode = false;
        Serial.println("Party mode now disabled");
        digitalWrite(6,LOW);
        buttonlast = 5;
      } else {
        partymode = true;
        Serial.println("Party mode now enabled");
        digitalWrite(6,HIGH);
        buttonlast = 5;
      }
    } else if ((digitalRead(5) == 1)&(buttonlast != 5)){
      Serial.println("Door Open (switch)");
      card_timr = true;      
      lock_idx = 0;      
      pos = open;
      servo.attach(9);
      servotimer = true;
      buttonlast = 5;
    }
    servo.write(pos);
}

void menu(){
  boolean run = true;
  digitalWrite(6,HIGH);
  while(run){
    Serial.println("What do you want to do?");
    Serial.println("Options include 'e,r,w,x'");
    char temp = -1; 
    while (temp == -1) {
      if (digitalRead(4) == 1){
        Serial.println("Door Close (switch)");
        temp = 'x';
      } else {
        temp = Serial.read();
      }
    }
    switch (temp) {
      case 'e':
        Serial.println("Eeprom Status:");
        Serial.print("Number of entries: ");
        Serial.println(num_entries,DEC);
        Serial.println("Card entries:");
        for (int i=0;i<num_entries;i++){
          Serial.print(i,DEC);
          Serial.print('-');
          Serial.println(cards[i],DEC);
        }
        break;
      case 'r':
        Serial.println("Please swipe your card.");
        card = 0;
        while(card == 0) {delay(250);}
        Serial.println(card,DEC);
        break;
      case 'w':
        Serial.println("Please swipe your card.");
        card = 0;
        while(card == 0) {delay(250);}
        Serial.println(card,DEC);
        if (card_exists(card))
          Serial.println("card exists!");
        else {
          Serial.println("Card does not exist!");
          add_card(card);
          Serial.println("Card added!");
        }
        break;
      case 'x':
        Serial.println("Exiting menu");
        run = false;
    } 
  }
}

boolean card_exists(unsigned int thecard){
  boolean temp = false;
  if (partymode){
    for (int i=0;i<num_entries;i++){
      if (cards[i] == thecard)
        temp = true;
    }
  } else {
    for (int i=0;i<num_apt;i++){
      if (apt[i] == thecard)
        temp = true;
    }
  }
  return temp;
}

void add_card(unsigned int thecard){
  cards[num_entries] = thecard;
  num_entries++;
  EEPROM.write(0,num_entries);
  delay(5);
  EEPROM.write((num_entries*2)-1,(thecard >> 8) & 0xFF);
  delay(5);
  EEPROM.write((num_entries*2),(thecard & 0xFF));
  delay(5);
}

ISR(TIMER2_OVF_vect){
  if ((time_idx < timeout)&(card_present)){
    time_idx += 1;
  } else if ((time_idx >= timeout)&(card_present)) {
    time_idx = 0;
    //Serial.println("d");
    Serial.println(card,DEC);
    card_read = true;
    card_present = false;
    card_idx = 0;
  }
  if ((lock_idx < 30000)&(card_timr)){
    lock_idx += 1;
  } else if ((lock_idx >= 30000)&(card_timr)){
    pos = close;
    servo.attach(9);
    servo.write(pos);
    servotimer = true;
    lock_idx = 0;
    card_timr = false;
    lastcard = 0;
  }
  if ((servoidx < 1000)&(servotimer)){
    servoidx += 1;
  } else if ((servoidx >= 1000)&(servotimer)) {
    servoidx = 0;
    servotimer = false;
    servo.detach();
    Serial.println("Servo detaching due to timeout!");
  }
}


void int0(){
  card_idx++;
  //Serial.print('0');
  time_idx = 0;
  //TCCR2B |= (1 << CS22)|(1 << CS20);
  card_present = true;
}

void int1(){
  if ((card_idx > 8)&(card_idx < 25))
    card |= (1 << (15 - (card_idx - 9)));
  card_idx++;
  //Serial.print('1');
  time_idx = 0;
  card_present = true;
  //TCCR2B |= (1 << CS22)|(1 << CS20);
}

/*
 Copyright (C) 2011 J. Coliz <maniacbug@ymail.com>

 This program is free software; you can redistribute it and/or
 modify it under the terms of the GNU General Public License
 version 2 as published by the Free Software Foundation.
 */

/**
 * Example RF Radio Ping Pair
 *
 * This is an example of how to use the RF24 class.  Write this sketch to two different nodes,
 * connect the role_pin to ground on one.  The ping node sends the current time to the pong node,
 * which responds by sending the value back.  The ping node can then see how long the whole cycle
 * took.
 */

#include <SPI.h>
#include "nRF24L01.h"
#include "RF24.h"
#include "printf.h"
#include "Ethernet.h"

unsigned long HeartBeatPeriod = 1000000; // about 30 sec
unsigned long hearbeat_counter;

void httpRequest(int, unsigned long);
// Setup Ethernet
 byte mac[] = { 
   0xDE, 0xAD, 0xBE, 0xEF, 0xFE, 0xED};
   IPAddress ip(192,168,1,99);
   IPAddress myDns(192,168,1,1);

   // initialize the library instance:
   EthernetClient client;
  
    char server[] = "zserg.net";
    boolean lastConnected = false;                 // state of the connection last time through the main loop


// Set up nRF24L01 radio on SPI bus plus pins 9 & 10

RF24 radio(6,7);

// sets the role of this unit in hardware.  Connect to GND to be the 'pong' receiver
// Leave open to be the 'ping' transmitter

//
// Topology
//

// Radio pipe addresses for the 2 nodes to communicate.
const uint64_t pipes[2] = { 0xF0F0F0F0E1LL, 0xF0F0F0F0D2LL };

void setup(void)
{

  Serial.begin(57600);
  printf_begin();
  printf("\n\rRF24 Server is active\n\r");
  
  Ethernet.begin(mac, ip, myDns);
  // print the Ethernet board/shield's IP address:
     Serial.print("My IP address: ");
     Serial.println(Ethernet.localIP());
  //
  // Setup and configure rf radio
  //

  radio.begin();

  // optionally, increase the delay between retries & # of retries
  radio.setRetries(15,15);

  // optionally, reduce the payload size.  seems to
  // improve reliability
  radio.setPayloadSize(8);
  radio.setDataRate( RF24_250KBPS );

  //
  // Open pipes to other nodes for communication
  //


    radio.openWritingPipe(pipes[1]);
    radio.openReadingPipe(1,pipes[0]);
  //
  // Start listening
  //

  radio.startListening();

  //
  // Dump the configuration of the rf unit for debugging
  //

  radio.printDetails();
  hearbeat_counter = 0;
}

void loop(void)
{

   if(hearbeat_counter == HeartBeatPeriod){
      httpRequest(255,0);
      hearbeat_counter = 0;
   }   
   hearbeat_counter++;
   // if there is data ready
    if ( radio.available() )
    {
      // Dump the payloads until we've gotten everything
      unsigned long got_time;
      bool done = false;
      while (!done)
      {
        // Fetch the payload, and see if this was the last one.
        done = radio.read( &got_time, sizeof(unsigned long) );

        // Spew it
        printf("Got payload %lu...",got_time);

	// Delay just a little bit to let the other unit
	// make the transition to receiver
	delay(20);
      }

      // First, stop listening so we can talk
      radio.stopListening();

      // Send the final one back.
      radio.write( &got_time, sizeof(unsigned long) );
      printf("Sent response.\n\r");

      // Now, resume listening so we catch the next packets.
      radio.startListening();
      httpRequest(1,got_time);
    }
  }
// vim:cin:ai:sts=2 sw=2 ft=cpp

void httpRequest(int id, unsigned long data) {
 //if there's a successful connection:
   if (client.connect(server, 8000)) {
       Serial.println("connecting...");
      // send the HTTP PUT request:
       client.print("GET /smarthome/add?id=");
       client.print(id);
       client.print(",data=");
       client.print(data);
       client.println(" HTTP/1.1");
       client.println("Host: arduno.zserg.home");
       client.println("User-Agent: arduino-ethernet");
       client.println("Connection: close");
       client.println();
       printf("Successfull connection! Data is sent.\n\r");

       // note the time that the connection was made:
       //lastConnectionTime = millis();
   } 
   else {
    // if you couldn't make a connection:
    Serial.println("connection failed");
    Serial.println("disconnecting.");
  }
  client.stop();
  client.flush();
}


#!/bin/sh

#This script is a fork of the script here http://www.pinkfishmedia.net/forum/showthread.php?t=165465
#Mentioned here: https://forums.slimdevices.com/forum/user-forums/3rd-party-software/99363-squeezelite-soft-power-off-on-detect?p=1187491#post1187491
#Almost lost to time except for the diligent work of the heroes at the Internet Archive, who archived it
#here: https://web.archive.org/web/20150919144202/http://www.pinkfishmedia.net/forum/showthread.php?t=165465
#It was originally designed to work with GPIO, which .. presumedly, flipped a relay? Seems extreme :)
#This script works using cec-client to send "on" commands.
#It's not clear if these commands are specific to my particular Onkyo player. e.g., is my player always device 5? I dunno.


#===========================================================================
# Set the following according to your setup
#---------------------------------------------------------------------------
# I'm not sure why the original script set a MAC_ADDR -- maybe it limited
# the LMS response to interactions with this specific player ... which technically
# we care about? This script assumes only a single player is attached.
#MAC_ADDR=c0:1c:30:2f:fc:d0
LMS_IP=192.168.1.10                          # LMS IP address
INTERVAL=0.5                                # Set Poll interval
COMMAND="status 0 0"                        # LMS player status command -- If you're using the "Material Skin", find docs for this at Information/Technical Information/Command Line Interface.
DELAYOFF=10                                    # Delay in no. of intervals
COUNT=0
#---------------------------------------------------------------------------

if [ -n "$VERBOSE" ]; then
    echo
    echo "MAC_ADDR : "$MAC_ADDR
    echo "LMS_IP   : "$LMS_IP
    echo "INTERVAL : "$INTERVAL
    echo "COMMAND  : "$COMMAND
    echo "DELAYOFF : "$DELAYOFF
    echo
fi

if [ -n "$DEBUG" ]; then
  set -x
fi

ISSUED_START=false
ISSUED_STOP=false

log_verbose() {
  if [ -n "$VERBOSE" ]; then
    echo $1
  fi
}

log_debug() {
  if [ -n "$DEBUG"]; then
    echo $1
  fi
}

get_mode() {
  #It might be possible to use COUNT in place of tracking whether or not we've issued
  #start/stop, but that makes the code more difficult to reason about.
  RESULT=`( echo "$MAC_ADDR $COMMAND"; echo exit ) | nc $LMS_IP 9090`
  echo $RESULT | grep "mode%3Aplay" > /dev/null 2>&1
  if [ $? = 0 ]; then
    log_verbose  "Playing. Count: $COUNT"
    COUNT=0
    ISSUED_STOP=false
    if [ $ISSUED_START = false ]; then
      log_verbose "Issuing cec start"
      START_RESULT=$(echo 'on 5' | cec-client -s)
      log_debug $START_RESULT
      ISSUED_START=true
    fi
  else
    log_verbose "Stopped. Count: $COUNT"
    ISSUED_START=false
    if [ $COUNT -ge $DELAYOFF ] && [ $ISSUED_STOP = false ]; then
      log_verbose "Issuing cec stop"
      STOP_RESULT=$(echo 'standby 5' | cec-client -s)
      log_debug $STOP_RESULT
      ISSUED_STOP=true
    fi
    COUNT=$(($COUNT + 1))
  fi
}
#===========================================================================
# Loop forever. This uses less the 1% CPU (according to the original script comments), so it should be OK.
#---------------------------------------------------------------------------
while true
do
    get_mode
    sleep $INTERVAL
done

#!/bin/sh

#set -euo pipefail

# Yes, /bin/sh, but for tiny core (where we'll be running this), it seems like most of bash is supported.

# THIS IS EXPECTED TO RUN AS ROOT!!

# This script is a fork of the script here http://www.pinkfishmedia.net/forum/showthread.php?t=165465
# Mentioned here: https://forums.slimdevices.com/forum/user-forums/3rd-party-software/99363-squeezelite-soft-power-off-on-detect?p=1187491#post1187491
# Almost lost to time except for the diligent work of the heroes at the Internet Archive, who archived it
# here: https://web.archive.org/web/20150919144202/http://www.pinkfishmedia.net/forum/showthread.php?t=165465
# It was originally designed to work with GPIO, which .. presumedly, flipped a relay? Seems extreme :)
# This script works using cec-client to send "on" commands.
# It's not clear if these commands are specific to my particular Onkyo player. e.g., is my player always device 5? I dunno.
# 2024-12-01 -- and now, I've adapted this to work with cec-ctl.


#===========================================================================
# Set the following according to your setup
#---------------------------------------------------------------------------
# I'm not sure why the original script set a MAC_ADDR -- maybe it limited
# the LMS response to interactions with this specific player ... which technically
# we care about? This script assumes only a single player is attached.
# MAC_ADDR=c0:1c:30:2f:fc:d0
# LMS IP address or FQDN -- for the host! This _will_ accept a fqdn, BUT if you're using a reverse proxy to route to your music server, that's probably not what you want.
LMS_IP=smradio-docker.agaskar.com
# Set Poll interval (in seconds)
INTERVAL=1
# LMS player status command -- If you're using the "Material Skin", find docs for this at Information/Technical Information/Command Line Interface.
COMMAND="status 0 0"
# Delay in no. of intervals (e.g. 10 * .5, check every 5 seconds)
DELAYOFF=5
#this is used to track state.
COUNT=0
ISSUED_START=false
ISSUED_STOP=false
#---------------------------------------------------------------------------

init() {
  if [ -n "$VERBOSE" ]; then
      echo
      echo "MAC_ADDR : "$MAC_ADDR
      echo "LMS_IP   : "$LMS_IP
      echo "INTERVAL : "$INTERVAL
      echo "COMMAND  : "$COMMAND
      echo "DELAYOFF : "$DELAYOFF
      echo
  fi

  if [ -n "$SET_X" ]; then
    set -x
  fi

  log_verbose "Starting CEC device"
  startup_result=$(cec-ctl -d/dev/cec0 --playback -S) #this emits a BUNCH of data, maybe we want some of it? hard to say.)
  log_verbose "$startup_result"
}

log_verbose() {
  if [ -n "$VERBOSE" ]; then
    >&2 echo $1
  fi
}

log_debug() {
  if [ -n "$DEBUG" ]; then
    >&2 echo $1
  fi
}

cec_stop() {
  cec-ctl -d/dev/cec0 -t5 --standby
}

cec_start() {
  #cec-ctl -d/dev/cec0 --active-source phys-addr=1.0.0.0
  #holy shit, this took forever to figure out. Basically, we use --raw-msg to say "I don't give a fuck, send it"
  #we also use --from to spoof from 1.0.0.0 ... not sure if this is needed?
  #pulled this from hints from the debug of using the old cec-client.
  cec-ctl -t5 --from 1.0.0.0 --user-control-pressed ui-cmd=power --raw-msg
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
      log_verbose "Issuing active source (power on)"
      START_RESULT=$(cec_start)
      log_debug $START_RESULT
      ISSUED_START=true
    fi
  else
    log_verbose "Stopped. Count: $COUNT"
    ISSUED_START=false
    if [ $COUNT -ge $DELAYOFF ] && [ $ISSUED_STOP = false ]; then
      log_verbose "Issuing stop (standby)"
      STOP_RESULT=$(cec_stop)
      log_debug $STOP_RESULT
      ISSUED_STOP=true
    fi
    COUNT=$(($COUNT + 1))
  fi
}
#===========================================================================
# Loop forever. This uses less the 1% CPU (according to the original script comments), so it should be OK.
#---------------------------------------------------------------------------
init
while true
do
    get_mode
    sleep $INTERVAL
done


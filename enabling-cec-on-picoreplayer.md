## 

I had this running on raspbi, but wanted to try picoreplayer since it seemed nice. 

first, from [here](https://forums.slimdevices.com/forum/user-forums/3rd-party-software/1698024-pcp-9-and-hdmi-cec-using-tv-remote-to-control-jivelite#post1698024), I see we can get cec-ctl via installing  v4l2-utils.tcz. 

I also found it useful to install vim.tcz

I have NOT found a way to install tcz packages from ssh yet. The web interface is ... weird? You have to go to the "Main" page, then click "Extensions", then wait ... until the Information page you land on loads completely, before hitting the "Available" tab to install more extensions. If you do not wait, the list does not populate correctly. There's also a weird "Reset" button you have to hit after using the page.. supposedly? Ah old cgi-bin days.

As mentioned, you do probably need to grow your parititon -- I was surprised to find I only had 12mb leftover (after a "standard" coreplayer only install + upgrading core picoreplayer)!!! I wonder if this also contributed to the crash probs I was seeing with wifi and slow responsees?

I gave it another gig. 

In my case, I then got the following: 

```
tc@living-room-speakers:~$ cec-ctl
Failed to open /dev/cec0: No such file or directory
tc@living-room-speakers:~$ sudo cec-ctl
Failed to open /dev/cec0: No such file or directory
```

Sounds like the cec drivers aren't supported?

According to some messages further down, some tweaks are needed. In config.txt, at least: 

```
# Change our graphice driver for HDMI-CEC support                              
dtoverlay=vc4-kms-v3d    
```

Editing config.txt can't be done during "normal" operation, see [here](https://docs.picoreplayer.org/how-to/edit_config_txt/)

After this you should be able to run sudo cec-ctl and get output, e.g.: 

```
tc@living-room-speakers:~$ sudo cec-ctl
Driver Info:
	Driver Name                : vc4_hdmi
	Adapter Name               : vc4-hdmi
	Capabilities               : 0x0000011e
		Logical Addresses
		Transmit
		Passthrough
		Remote Control Support
		Connector Info
	Driver version             : 6.1.77
	Available Logical Addresses: 1
	DRM Connector Info         : card 0, connector 32
	Physical Address           : 1.0.0.0
	Logical Address Mask       : 0x0000
	CEC Version                : 2.0
	OSD Name                   : ''
	Logical Addresses          : 0
```

Now, once you edit this, your squeezelite (may) stop working, because you now have a NEW HDMI out you need to use (you can see outputs with `aplay -l`)

In my case, `aplay -l` gave: 

```
tc@living-room-speakers:~$ aplay -l
**** List of PLAYBACK Hardware Devices ****
card 0: Headphones [bcm2835 Headphones], device 0: bcm2835 Headphones [bcm2835 Headphones]
  Subdevices: 8/8
  Subdevice #0: subdevice #0
  Subdevice #1: subdevice #1
  Subdevice #2: subdevice #2
  Subdevice #3: subdevice #3
  Subdevice #4: subdevice #4
  Subdevice #5: subdevice #5
  Subdevice #6: subdevice #6
  Subdevice #7: subdevice #7
card 1: vc4hdmi [vc4-hdmi], device 0: MAI PCM i2s-hifi-0 [MAI PCM i2s-hifi-0]
  Subdevices: 1/1
  Subdevice #0: subdevice #0
```

OK, looks like we don't have the HDMI0 we were previously using, and now have a HDMI1 vc4-hdmi.

You'll want to switch outputs. I have been using the web interface when in doubt around changes being preserved, so you can do this from the squeezelite settings page.

For whatever reason, in the dropdown, it's marked as "Pi 4/5" only (e.g., mine says `HDMI1 vc4 audio (PI 4/5)`).

But, haha! This is the wrong card!!! In my case, I can see during bootup that it says "Waiting for sound card vc4hdmi to populate....." and then eventually fails out.

Weirdly, after this boot, I see that my card "moved" to HDMI0 (the "headphones" card disappeared -- maybe had to do with prior settings???): 

```
tc@living-room-speakers:~$ aplay -l
**** List of PLAYBACK Hardware Devices ****
card 0: vc4hdmi [vc4-hdmi], device 0: MAI PCM i2s-hifi-0 [MAI PCM i2s-hifi-0]
  Subdevices: 1/1
  Subdevice #0: subdevice #0
```

So, let's try again with `HDMI0 vc4 audio (PI 4/5)`.

And .... failed -- it's not actually vc4hdmi0 -- it's vc4hdmi. BUT, good news! I didn't read the above linked thread completely. It's necessary to configure some of this manually, see [here](https://forums.slimdevices.com/forum/user-forums/3rd-party-software/1698024-pcp-9-and-hdmi-cec-using-tv-remote-to-control-jivelite?p=1702197#post1702197)

So: 

Ok I've fixed the squeezelite not starting on boot issue

Create /usr/local/share/pcp/cards/HDMIvc4.conf
Code:

```
[COMMON]
CARD="vc4hdmi"
SSET="HDMI"
OUTPUT="hdmi:CARD=vc4hdmi"
ALSA_PARAMS="80::32:0"
GENERIC_CARD="ONBOARD"
AUDIOBOOTSCRIPT=""
CONTROL_PAGE="soundcard_control.cgi"
LISTNAME="HDMI0 vc4 audio (Pi3)"
SHAIRPORT_OUT="hdmi:CARD=vc4hdmi"
SHAIRPORT_CONTROL=""
```

then
Code:

```
echo usr/local/share/pcp/cards/HDMIvc4.conf >> /opt/.filetool.lst
pcp bu
pcp rb
```

Now select the new Audio device and it will re-connect correctly on reboot.

Still can't get the remote control to work, but some progress.


Make sure you DON'T MISS the bit about updating /opt/.filetool.lst (see the echo command), or your backup won't save the file!!!! 

Remember, you still need to set the card post-reboot, so one more reboot after adding the card listing .

Cool, now once you'ce got the card setup (and maybe reboot again?) you should be able to run sudo cec-ctl and get something back. 

NOW THE REAL FUN BEGINS

you see, CEC is horribly documented, and cec-ctl is even worse. e.g., would you think that what you get from cec-ctl -h would also appear in cec-ctl --help-all? WOULD YOU? YOU SWEET SUMMER CHILD AHAHAHAHAHAHA

anyways, basically what I've found that works for MY pi and my Onkyo, is something like this: 

```
#this is a one-time init step ... I think? 
sudo cec-ctl -d/dev/cec0 --playback -S > /dev/null #this emits a BUNCH of data, maybe we want some of it? hard to say. 

#turn off -- this one is easy, it's well documented, and worked right away. 
# 5 in this case is the "address" of my device. I don't know why, but my Onkyo is ALWAYS on 5. 
# That said, if one desired they could scrape the output of the playback init to make sure they have the right address.
sudo cec-ctl -d/dev/cec0 -t5 --standby

#turn on  -- this took me HOURSSSSS. I am not sure if the --playback (which configures our Pi as a playback device) is "required" or optional. 
# I found it by seeing someone suggest the --test-power-cycle flag, which tests on/off (which ha ha, doesn't work for me).  
# The way to turn things on is NOT to send a power event or anything like that -- NO -- that might work for a tv or something -- it's to send a (presumably broadcast?) cec message that sets our player as the active source (although surprisingly/unsuprisingly for how often stuff like --image-view-on etc is used in describing cec-ctl, the --test-power-cycle appears to test the power cycle by setting the active source. HMMMMMMMMMM).  
sudo cec-ctl -d/dev/cec0 --active-source phys-addr=1.0.0.0

#NOTE! You see there's a physical address param there -- this is the address of MY cec device (the hdmi port on the pi) again, this is plausibly variable, but it's always been 1.0.0.0. 
# In my past usage of cec-client I found that this was ALWAYS the same, never appeared to change for months, so Imma just gonna hard code it for now and see what happens. 
```

OK, a major issue I had is about 60 seconds after putting the receiver (onkyo tr609 in my case) into Standby, the HDMI light would turn off and the --active-source would no longer serve to wake from standby. 

This is definitely some kind of receiver/HDMI behavior. Basically some kind of "deep sleep". Now, a problem with cec-ctl (vs cec-client) is that it does some kind of validation related to what it "knows" about the current HDMI topology, and once the receiver goes into "deep sleep" it's basically like "ok, your pi is not in any topology" and thus you cannot send any commands, which makes it real tough to turn back on a receiver. 

FWIW, this all conjecture based on what I've observed, mostly with cec-client, as I had to spin my deployment that was using cec-client back up to see if I was crazy in thinking that this worked fine with cec-client (it did!). here's an excerpt of cec-client logs turning back on from "deep sleep" that ultimately led me to the fix.

The following chatter is all related to a "simple": `echo 'on 5' | cec-client -s` (that is, cec-client does a TON of orchestration that doesn't happen with cec-ctl). 

```
opening a connection to the CEC adapter...
DEBUG:   [             443] Broadcast (F): osd name set to 'Broadcast'
DEBUG:   [             451] CLinuxCECAdapterCommunication::Open - m_path=/dev/cec0 m_fd=4 bStartListening=1
DEBUG:   [             454] CLinuxCECAdapterCommunication::Open - ioctl CEC_ADAP_G_PHYS_ADDR - addr=1000
DEBUG:   [             456] CLinuxCECAdapterCommunication::Open - ioctl CEC_ADAP_S_LOG_ADDRS - log_addr_mask=0000 num_log_addrs=0
DEBUG:   [             462] CLinuxCECAdapterCommunication::Open - ioctl CEC_ADAP_S_LOG_ADDRS - log_addr_mask=8000 num_log_addrs=1
DEBUG:   [             465] CLinuxCECAdapterCommunication::Process - CEC_DQEVENT - CEC_EVENT_STATE_CHANGE - log_addr_mask=8000 phys_addr=1000
NOTICE:  [             466] connection opened
DEBUG:   [             473] << Broadcast (F) -> TV (0): POLL
TRAFFIC: [             473] << f0
DEBUG:   [             477] processor thread started
DEBUG:   [             809] CLinuxCECAdapterCommunication::Write - ioctl CEC_TRANSMIT - tx_status=24 len=1 addr=f0 opcode=ffffffff
TRAFFIC: [             809] << f0
DEBUG:   [             880] CLinuxCECAdapterCommunication::Write - ioctl CEC_TRANSMIT - tx_status=24 len=1 addr=f0 opcode=ffffffff
DEBUG:   [             880] >> POLL not sent
DEBUG:   [             880] TV (0): device status changed into 'not present'
DEBUG:   [             881] registering new CEC client - v6.0.2
DEBUG:   [             881] SetClientVersion - using client version '6.0.2'
NOTICE:  [             881] setting HDMI port to 1 on device TV (0)
DEBUG:   [             881] << Broadcast (F) -> TV (0): POLL
TRAFFIC: [             881] << f0
DEBUG:   [             952] CLinuxCECAdapterCommunication::Write - ioctl CEC_TRANSMIT - tx_status=24 len=1 addr=f0 opcode=ffffffff
TRAFFIC: [             952] << f0
DEBUG:   [            1023] CLinuxCECAdapterCommunication::Write - ioctl CEC_TRANSMIT - tx_status=24 len=1 addr=f0 opcode=ffffffff
DEBUG:   [            1023] >> POLL not sent
DEBUG:   [            1023] SetConfiguration: double tap timeout = 200ms, repeat rate = 0ms, release delay = 500ms
DEBUG:   [            1023] detecting logical address for type 'recording device'
DEBUG:   [            1024] trying logical address 'Recorder 1'
DEBUG:   [            1024] << Recorder 1 (1) -> Recorder 1 (1): POLL
TRAFFIC: [            1024] << 11
DEBUG:   [            1094] CLinuxCECAdapterCommunication::Write - ioctl CEC_TRANSMIT - tx_status=24 len=1 addr=11 opcode=ffffffff
TRAFFIC: [            1095] << 11
DEBUG:   [            1166] CLinuxCECAdapterCommunication::Write - ioctl CEC_TRANSMIT - tx_status=24 len=1 addr=11 opcode=ffffffff
DEBUG:   [            1166] >> POLL not sent
DEBUG:   [            1166] using logical address 'Recorder 1'
DEBUG:   [            1166] Recorder 1 (1): device status changed into 'handled by libCEC'
DEBUG:   [            1166] Recorder 1 (1): power status changed from 'unknown' to 'on'
DEBUG:   [            1166] Recorder 1 (1): vendor = Pulse Eight (001582)
DEBUG:   [            1167] Recorder 1 (1): CEC version 1.4
DEBUG:   [            1167] AllocateLogicalAddresses - device '0', type 'recording device', LA '1'
DEBUG:   [            1167] CLinuxCECAdapterCommunication::Process - CEC_DQEVENT - CEC_EVENT_STATE_CHANGE - log_addr_mask=0000 phys_addr=1000
DEBUG:   [            1167] CLinuxCECAdapterCommunication::SetLogicalAddresses - ioctl CEC_ADAP_S_LOG_ADDRS - log_addr_mask=0000 num_log_addrs=0
DEBUG:   [            1313] CLinuxCECAdapterCommunication::Process - CEC_DQEVENT - CEC_EVENT_STATE_CHANGE - log_addr_mask=0002 phys_addr=1000
DEBUG:   [            1314] changing physical address to 1000
DEBUG:   [            1314] Recorder 1 (1): physical address changed from ffff to 1000
DEBUG:   [            1314] CLinuxCECAdapterCommunication::SetLogicalAddresses - ioctl CEC_ADAP_S_LOG_ADDRS - log_addr_mask=0002 num_log_addrs=1
DEBUG:   [            1314] Recorder 1 (1): osd name set to 'CECTester'
DEBUG:   [            1314] Recorder 1 (1): menu language set to 'eng'
DEBUG:   [            1314] using provided physical address 1000
NOTICE:  [            1315] CEC client registered: libCEC version = 6.0.2, client version = 6.0.2, firmware version = 0, logical address(es) = Recorder 1 (1) , physical address: 1.0.0.0, compiled on Linux-5.10.63-v8+ ... , features: P8_USB, DRM, P8_detect, randr, RPi, Exynos, Linux, AOCEC
DEBUG:   [            1315] << Recorder 1 (1) -> TV (0): OSD name 'CECTester'
DEBUG:   [            1315] << Recorder 1 (1) -> TV (0): POLL
TRAFFIC: [            1315] << 10
DEBUG:   [            1662] CLinuxCECAdapterCommunication::Write - ioctl CEC_TRANSMIT - tx_status=24 len=1 addr=10 opcode=ffffffff
TRAFFIC: [            1663] << 10
DEBUG:   [            1734] CLinuxCECAdapterCommunication::Write - ioctl CEC_TRANSMIT - tx_status=24 len=1 addr=10 opcode=ffffffff
DEBUG:   [            1734] >> POLL not sent
DEBUG:   [            1734] not sending command 'set osd name': destination device 'TV' marked as not present
DEBUG:   [            1734] << requesting power status of 'TV' (0)
DEBUG:   [            1734] << Recorder 1 (1) -> TV (0): POLL
TRAFFIC: [            1734] << 10
DEBUG:   [            1805] CLinuxCECAdapterCommunication::Write - ioctl CEC_TRANSMIT - tx_status=24 len=1 addr=10 opcode=ffffffff
TRAFFIC: [            1805] << 10
DEBUG:   [            1876] CLinuxCECAdapterCommunication::Write - ioctl CEC_TRANSMIT - tx_status=24 len=1 addr=10 opcode=ffffffff
DEBUG:   [            1877] >> POLL not sent
DEBUG:   [            1877] not sending command 'give device power status': destination device 'TV' marked as not present
DEBUG:   [            1878] << Recorder 1 (1) -> Audio (5): POLL
TRAFFIC: [            1878] << 15
DEBUG:   [            1915] CLinuxCECAdapterCommunication::Write - ioctl CEC_TRANSMIT - tx_status=01 len=1 addr=15 opcode=ffffffff
DEBUG:   [            1915] >> POLL sent
DEBUG:   [            1915] Audio (5): device status changed into 'present'
DEBUG:   [            1915] << requesting vendor ID of 'Audio' (5)
TRAFFIC: [            1915] << 15:8c
DEBUG:   [            1981] CLinuxCECAdapterCommunication::Write - ioctl CEC_TRANSMIT - tx_status=01 len=2 addr=15 opcode=8c
DEBUG:   [            2133] CLinuxCECAdapterCommunication::Process - ioctl CEC_RECEIVE - rx_status=01 len=5 addr=5f opcode=87
TRAFFIC: [            2134] >> 5f:87:00:09:b0
DEBUG:   [            2134] Audio (5): vendor = Onkyo (0009b0)
DEBUG:   [            2134] expected response received (87: device vendor id)
DEBUG:   [            2134] replacing the command handler for device 'Audio' (5)
DEBUG:   [            2134] << requesting power status of 'Audio' (5)
TRAFFIC: [            2134] << 15:8f
DEBUG:   [            2139] >> Audio (5) -> Broadcast (F): device vendor id (87)
DEBUG:   [            2229] CLinuxCECAdapterCommunication::Write - ioctl CEC_TRANSMIT - tx_status=01 len=2 addr=15 opcode=8f
DEBUG:   [            2326] CLinuxCECAdapterCommunication::Process - ioctl CEC_RECEIVE - rx_status=01 len=3 addr=51 opcode=90
TRAFFIC: [            2327] >> 51:90:01
DEBUG:   [            2327] Audio (5): power status changed from 'unknown' to 'standby'
DEBUG:   [            2327] expected response received (90: report power status)
NOTICE:  [            2327] << powering on 'Audio' (5)
TRAFFIC: [            2327] << 15:44:40
DEBUG:   [            2332] >> Audio (5) -> Recorder 1 (1): report power status (90)
DEBUG:   [            2413] CLinuxCECAdapterCommunication::Write - ioctl CEC_TRANSMIT - tx_status=01 len=3 addr=15 opcode=44
TRAFFIC: [            2413] << 15:45
DEBUG:   [            2513] CLinuxCECAdapterCommunication::Write - ioctl CEC_TRANSMIT - tx_status=01 len=2 addr=15 opcode=45
DEBUG:   [            2513] unregistering all CEC clients
NOTICE:  [            2514] unregistering client: libCEC version = 6.0.2, client version = 6.0.2, firmware version = 0, logical address(es) = Recorder 1 (1) , physical address: 1.0.0.0, compiled on Linux-5.10.63-v8+ ... , features: P8_USB, DRM, P8_detect, randr, RPi, Exynos, Linux, AOCEC
DEBUG:   [            2514] Recorder 1 (1): power status changed from 'on' to 'unknown'
DEBUG:   [            2514] Recorder 1 (1): vendor = Unknown (000000)
DEBUG:   [            2514] Recorder 1 (1): CEC version unknown
DEBUG:   [            2514] Recorder 1 (1): osd name set to 'Recorder 1'
DEBUG:   [            2514] Recorder 1 (1): device status changed into 'unknown'
DEBUG:   [            2515] CLinuxCECAdapterCommunication::Process - CEC_DQEVENT - CEC_EVENT_STATE_CHANGE - log_addr_mask=0000 phys_addr=1000
DEBUG:   [            2515] CLinuxCECAdapterCommunication::SetLogicalAddresses - ioctl CEC_ADAP_S_LOG_ADDRS - log_addr_mask=0000 num_log_addrs=0
DEBUG:   [            2515] CLinuxCECAdapterCommunication::SetLogicalAddresses - ioctl CEC_ADAP_S_LOG_ADDRS - log_addr_mask=0000 num_log_addrs=0
DEBUG:   [            2515] unregistering all CEC clients
DEBUG:   [            2515] CLinuxCECAdapterCommunication::SetLogicalAddresses - ioctl CEC_ADAP_S_LOG_ADDRS - log_addr_mask=0000 num_log_addrs=0
DEBUG:   [            3523] CLinuxCECAdapterCommunication::Process - stopped - m_path=/dev/cec0 m_fd=4
``` 

So for me, the real thing of note here is that I saw the cec-client basically saying "Imma set my OWN logical address, and not wait for anyone to give it to me". 

It turns out this was kind of a key realization -- I'm not sure that setting of the logical address is totally necessary, but what IS necessary is we need to send a power on event REGARDLESS of what cec-ctl thinks about the topology. 

This is possible, but I haven't seen anyone mention it yet. I don't know what kind of risk/edge cases are involved in doing this when you have a multi-device topology, but in my case it's just the reciever and the pi, so no big deal. 

Basically, one just needs to: 

```
  cec-ctl -t5 --from 1.0.0.0 --user-control-pressed ui-cmd=power --raw-msg
```

some key bits here: 

`-t5` this sends to logical address 5. Necessary? I dunno? Maybe we could broadcast? All I know is I see cec-client doing that (well because I'm telling it). 
Somehow "magically" my receiver has ALWAYS been at 5, even across these two systems, so .. not sure how/why it happens, but it seems reliable. In theory I could (if I "know" the reciever is on) pull this from a topology scan and store for later, but I'm not trying to write a general purpose tool here (yet?) 

`--from 1.0.0.0` this sets our pi to have a logical address of 1.0.0.0. Again, this is kind of voodoo/assumption -- I'm not 100% sure it's necessary, but this is the logical address I've always gotten for the pi when on a "live" topology (when running a scan where the receiver is connected + "on"). 

`--user-control-pressed ui-cmd=power` I was able to figure out that this was what cec-client was sending (you can see there is traffic of `15:44:40`. 15 is like .. my device address? when unregged? (It's like how the receiver is at 5). 44 is a "legit" HDMI command -- it's a button press! (this is clear if you send it as a custom command via cec-ctl using 0x44). 40 is another "legit" button press, (you can see this mapped in the help for the remote-control-passthrough of cec-ctl) -- it's the button ctl press for power. 

So NOT a custom command, a straight up button push of power. I tried this like a million times without success, because, the key bit was: 

`--raw-msg` -- without this, cec-ctl is like "I don't know about any 5 or any topology, so I ain't sending shit". It doesn't tell you this of course, you have to turn on iotctl debugging to even know it's just dropping this message on the floor (`-T`). Once you know this is happening, it's "obvious" that you want to send it anyways, which `--raw-msg` lets you do, and then WHAM, the receiver will come to life. 

Why isn't this documented/more clearly stated somewhere? I dunno! Obvs all the tools are here to make it behave like cec-client, and obvs cec-client was written to have this kind of behavior specifically in this scenario, but why didn't the authors of cec-ctl think to say "hey, in a lot of cases, you're gonna have stuff ignore these messages and you just need to force a broadcast or something" Who knows??!?! Maybe it's a real unusual case or something. 

Anyways, now you know too, hope this helps someone who is trying to figure out cec stuff and we can collectively build a better mental model together so things like this are less guesswork/trial and error.

A couple other notes: the script here (manage whatever blah) can be added to the file list so it gets backed up (I think I mention how to do this above?). You can just sit it in the tc home dir. You'll want to invoke it at some point, the easiest way I've found to do this is run it as a "user command" (avail via the squeeze lite settings). This works pretty good for me, if successful, you'll see it via "ps -aux". 

The script itself is very hokey, it does use bash-isms which appear supported by the /bin/sh running it. It is a little funky in that it "doesn't start working" until the first time you do a play/pause cycle. I didn't mess around with this too much (e.g. try to make a service) because on my past pi I thought I saw race conditions where it would "steal" the HDMI output from squeezelite (I actually think now that what happened was the receiver wasn't on and this caused downstream problems, but not sure and not gonna go back and troubleshoot it, see below)

Another thing to note is after all this, your receiver (at least for me) must be ON while rebooting/when the squeezelite process is started, otherwise squeezelite is unable to open the HDMI output. 

Now that I know how to bring back the receiver from deep sleep, it seems like one could invoke a wake right before trying to startup squeezelite (I think there is a provision for this), and then no worries about receiver state when rebooting (e.g. if it happens "automatically" after a power outage or something). That said, it's not hard to recover w/ picoreplayer if the receiver isn't on at boot, one can make sure the receiver is on, go to the squeezelite settings page and click save (on .. like, i dunno, one of the setup sections) and it will restart thes queezelite player and let you know if it works. 


Anyways, all of this is good enough for me: I have the on/off power management with my Onkyo TR609, and it survives reboots (as long as the receiver is on when squeezelite tries to start). The whole picoreplayer although somewhat non-standard (and weirdly anachronistic w.r.t. web app handling) is pretty cool as it is so lightweight and has lots of hooks ready-to-go out of the box for you. I'm excited to mess around with other stuff and also hopeful that this will fix some of the flac dropouts I've seen from my prior setup (stock raspbian bullseye + manual squeezelite install, which seemed to run sloooooooooow based on the ssh/shell response compared to picoreplayer). But, not gonna mess with it for awhile as I've poured a ton of effort in on this dumb bit (hopefully never again for awhile!!!).






## WiFi problems 
 BTW, I also had problems with my USB wifi dongle seemingly "falling asleep". When I checked with iwconfig, it said power management was off. I couldn't figure it out and wound up just adding a cron job that pings my router 10 times every five minutes.  (I noticed previously when the wifi "fell off" that if I ran a ping from the console it would "wake up"). 
e.g. 

```
# ping every 5 minutes, to "keepalive" the wifi (it kept falling off???)
*/5 * * * *  2>&1 ping -c 10 192.168.1.1 > /dev/null
```

Annoyingly, cron doesn't work out of the box -- it's not enabled. There's some interface for setting it up in the web ui, but it looks broken to me (maybe only allows file calls, no commands). It looks like whenever cron gets enabled, the web ui just adds "cron " to the start of the cmdline.txt (in the boot partition), so ... we need to do that too, then reboot (and maybe backup? who knows?)


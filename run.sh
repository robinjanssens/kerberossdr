#!/bin/bash

BUFF_SIZE=256 #Must be a power of 2. Normal values are 128, 256. 512 is possible on a fast PC.
IPADDR="0.0.0.0"
IPPORT="8081"

### Uncomment the following section to automatically get the IP address from interface wlan0 ###
### Don't forget to comment out "IPADDR="0.0.0.0" ###

# IPADDR=$(ip addr show wlan0 | grep "inet\b" | awk '{print $2}' | cut -d/ -f1)
# while [ "$IPADDR" == "" ] || [ "$IPADDR" == "169.254.*" ]
# do
# sleep 1
# echo "waiting for network"
# IPADDR=$(ip addr show wlan0 | grep "inet\b" | awk '{print $2}' | cut -d/ -f1)
# echo $IPADDR
# done

### End of Section ###

# Useful to set this on low power ARM devices
#sudo cpufreq-set -g performance

# Set for RPI3 with heatsink/fan
#sudo cpufreq-set -d 1.4GHz
# Set for Tinkerboard with heatsink/fan
#sudo cpufreq-set -d 1.8GHz

# Clear memory
sudo sh -c "echo 0 > /sys/module/usbcore/parameters/usbfs_memory_mb"
echo '3' | sudo dd of=/proc/sys/vm/drop_caches status=none

echo "Starting KerberosSDR"

# Kill old instances
sudo kill $(ps aux | grep 'rtl' | awk '{print $2}') 2>/dev/null || true
sudo pkill rtl_daq
sudo pkill sim
sudo pkill sync
sudo pkill gate
sudo pkill python3

# Enable on the Pi 3 to prevent the internet from hogging the USB bandwidth
#sudo wondershaper wlan0 3000 3000
#sudo wondershaper eth0 3000 3000

sleep 1

# Create RAMDISK for jpg files
sudo mount -osize=30m tmpfs /ram -t tmpfs

# Remake Controller FIFOs
rm -f _receiver/C/gate_control_fifo
mkfifo _receiver/C/gate_control_fifo

rm -f _receiver/C/sync_control_fifo
mkfifo _receiver/C/sync_control_fifo

rm -f _receiver/C/rec_control_fifo
mkfifo _receiver/C/rec_control_fifo

# Start programs at realtime priority levels
curr_user=$(whoami)
# sudo chrt -r 50 ionice -c 1 -n 0 ./_receiver/C/rtl_daq $BUFF_SIZE 2>/dev/null 1| sudo chrt -r 50 ./_receiver/C/sync $BUFF_SIZE 2>/dev/null 1| sudo chrt -r 50 ./_receiver/C/gate $BUFF_SIZE 2>/dev/null 1|sudo nice -n -20 sudo -u $curr_user python3 -O _GUI/hydra_main_window.py $BUFF_SIZE $IPADDR &>/dev/null&

# Comment the above and uncomment the below to show all errors to the log files
sudo chrt -r 50 ionice -c 1 -n 0 ./_receiver/C/rtl_daq $BUFF_SIZE 2>log_rtl_daq 1| sudo chrt -r 50 ./_receiver/C/sync $BUFF_SIZE 2>log_sync 1| sudo chrt -r 50 ./_receiver/C/gate $BUFF_SIZE 2>log_gate 1|sudo nice -n -20 sudo -u $curr_user python3 -O _GUI/hydra_main_window.py $BUFF_SIZE $IPADDR &>log_python&

# Start PHP webserver which serves the updating images
echo "Server running at $IPADDR:$IPPORT"
sudo php -S $IPADDR:$IPPORT -t _webDisplay >&- 2>&-

#!/bin/bash

#add swap fine, did add to /etc/fstab
#dd if=/dev/zero of=/tmp/swapfile count=4096 bs=1M
#chmod 600 /tmp/swapfile
#mkswap /tmp/swapfile
#swapon --show
#swapon /tmp/swapfile

# Start the docker containers in image
docker container restart oracle19c

# 
cd /home/ec2-user/
echo "Oracle DB 19c is running" > welcome.txt
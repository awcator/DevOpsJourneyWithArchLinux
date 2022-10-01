## Installation
```diff
pacman -S blackarch/wireshark-qt
!Allow non root user to capcture traffic
sudo setcap cap_net_raw,cap_net_admin+eip /usr/sbin/dumpcap
sudo chown root /usr/sbin/dumpcap
sudo chmod u+s /usr/bin/dumpcap

# Create group wireshark
sudo groupadd -s wireshark

#Add yourself to wireshark group
sudo gpasswd -a $USER wireshark

sudo chgrp wireshark /usr/sbin/dumpcap
sudo chmod o-rx /usr/sbin/dumpcap
```

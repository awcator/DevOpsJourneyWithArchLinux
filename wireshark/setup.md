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

### To send raw packets into the network (This can be used to test TCP behaviour)
```
sudo nemesis tcp -x 50000 -y 5444 -S 127.0.0.1 -D 127.0.0.1  -P pay 
sudo nemesis tcp -s 1633742858 -fFA -x 48294 -y 4444 -a 808317594 -S 127.0.0.1 -D 127.0.0.1 -P pay -c 1
sudo nemesis tcp -s 1633742858 -fPA -x 48294 -y 4444 -a 808317594 -S 127.0.0.1 -D 127.0.0.1 -P pay -c 1
```

## get Network adapter
```
ip link
# For more details
ip -d link 
```
## Bring Interface down
```
ip link set lo down
```
## set mtu for interface
```
ip link set lo mtu 80000
```
## Create a new dummy interface
```
 sudo ip link add test0 type dummy
```
## get details of IP/subnet/Gateway
```diff
ip ad
#ip address
# ip -d a show lo

!your network interface must be promescues (=1) if you want to capture frames/packets out of it. Fire up wireshark and start monitoring interface and recheck interface info
# your interface will be on promescues=1
ip -d -4 a show lo  # Return IPv4 address
ip -d -6 a show lo  # Returns Ipv6 Address
ip -s -6 a show lo  # Returns Statistics about packet drops/sizes etc
```
### Ip route
```diff
ip route
#gets the details about routing of the system

```

# Create bridge network
```diff

  +-------------------------------------------------------------+
  |                     Node IP: 192.168.42.210                 |
  |                                                             |
  |           +---------+                                       |
  |           |   ns1   | awcator_ns1, 172.16.0.2               |
  |           +---------+                                       |
  |               | veth ns12br                                 |
  |               |                                             |
  |               | veth br2ns1                                 |
  |           +---------+                                       |
  |           |   br0   | 172.16.0.0/24, 172.16.0.1 ------------|--->NAT (via eth0)--->Internet
  |           +---------+                                       |
  |               | veth br2ns2                                 |
  |               |                                             |
  |               | veth ns2br                                  |
  |           +---------+                                       |
  |           |   ns2   | awcator_ns2, 172.16.0.3               |
  |           +---------+                                       |
  |                                                             |
  +-------------------------------------------------------------+


NS1="awcator_ns1";
NS2="awcator_ns2";
BRIDGE_SUBNET="172.16.0.0/24";
BRIDGE_IP="172.16.0.1";
IP1="172.16.0.2";
IP2="172.16.0.3";
NODE_IP="192.168.42.210";
veth_bridge_to_ns1_endpoint_name="br2ns1"
veth_bridge_to_ns2_endpoint_name="br2ns2"
veth_ns1_to_bridge_endpoint_name="ns12br"
veth_ns2_to_bridge_endpoint_name="ns22br"
bridge_name="br0"
# the interface from which you have internet acess
hostmachine_iface="enp0s20u1"

#create networknamespces
sudo ip netns add $NS1
sudo ip netns add $NS2
ip netns show
# stored at /var/run/netns

#create veths
sudo ip link add $veth_bridge_to_ns1_endpoint_name type veth peer name $veth_ns1_to_bridge_endpoint_name
sudo ip link add $veth_bridge_to_ns2_endpoint_name type veth peer name $veth_ns2_to_bridge_endpoint_name
ip link show type veth
ip link show $veth_bridge_to_ns2_endpoint_name

# add veths to namespaces
sudo ip link set $veth_ns1_to_bridge_endpoint_name netns $NS1
sudo ip link set $veth_ns2_to_bridge_endpoint_name netns $NS2


# assign IPs for veths insides namespaces
sudo ip netns exec $NS1 ip addr add $IP1/24 dev $veth_ns1_to_bridge_endpoint_name  
sudo ip netns exec $NS2 ip addr add $IP2/24 dev $veth_ns2_to_bridge_endpoint_name
# for verify
sudo ip netns exec $NS2 ip addr 
# turn up the veth interfaces
sudo ip netns exec $NS1 ip link set dev $veth_ns1_to_bridge_endpoint_name up
sudo ip netns exec $NS2 ip link set dev $veth_ns2_to_bridge_endpoint_name up
# try pinging  self
sudo ip netns exec $NS2 ping $IP2 -c 2


# dsnt works, need to setup loopback
sudo ip netns exec $NS1 ip link set lo up
sudo ip netns exec $NS2 ip link set lo up
#verify
sudo ip netns exec $NS1 ip a
sudo ip netns exec $NS2 ip a

# try pinging  self, works
sudo ip netns exec $NS2 ping $IP2 -c 2 #works
sudo ip netns exec $NS2 ping $IP1 -c 2 #fails. need to bring them in one subnet or bridge

#bridge creation
sudo ip link add $bridge_name type bridge
ip link show type bridge
ip link show $bridge_name

#Adding the network namespaces interfaces to the bridge
sudo ip link set dev $veth_bridge_to_ns1_endpoint_name master $bridge_name
sudo ip link set dev $veth_bridge_to_ns2_endpoint_name master $bridge_name

#add ip to bridge
sudo ip addr add $BRIDGE_IP/24 dev $bridge_name

# Enabling the bridge, and veths connecting to bridge
sudo ip link set dev $bridge_name up
sudo ip link set dev $veth_bridge_to_ns2_endpoint_name up
sudo ip link set dev $veth_bridge_to_ns1_endpoint_name up

# try pinging ns1 from ns2 it should work
sudo ip netns exec $NS2 ping $IP1 -c 2
# there will be route
sudo ip netns exec $NS2 ip route
# 172.16.0.0/24 dev ns22br proto kernel scope link src 172.16.0.3 

#ping to nodeIP
sudo ip netns exec $NS2 ping $NODE_IP
# dnst works, need to have gateway via bridge,

#setup gateway for namespaces
sudo ip netns exec $NS1 ip route add default via $BRIDGE_IP dev $veth_ns1_to_bridge_endpoint_name
sudo ip netns exec $NS2 ip route add default via $BRIDGE_IP dev $veth_ns2_to_bridge_endpoint_name

# to test if it can reach HOST machine, run on hostmachine
nc -lvnp 4444
sudo ip netns exec $NS2 curl $BRIDGE_IP:4444
sudo ip netns exec $NS2 curl $NODE_IP:4444
# both should work, but trying to ping to servers on internet like 8.8.8.8 (google dns ) wont work
sudo ip netns exec $NS2 ping 8.8.8.8

# create NAT for all interfaces on the hostmachine
sudo sysctl net.ipv4.ip_forward=1


sudo iptables -t nat -A POSTROUTING -o $hostmachine_iface  -j MASQUERADE
sudo iptables -A FORWARD -i $hostmachine_iface -j ACCEPT
sudo iptables -A FORWARD -o $hostmachine_iface -j ACCEPT
sudo iptables -A FORWARD -m state --state RELATED,ESTABLISHED -j ACCEPT

# create NAT for specific interface bridge on the hostmachine
sudo iptables -t nat -A POSTROUTING -s $BRIDGE_SUBNET -o $hostmachine_iface -j MASQUERADE
# change/masquearde traffic going out of $BRIDGE_SUBNET subnet ip into hostmachine_iface's ip.   allowing the response traffic to be correctly routed back to the bridge.
sudo iptables -A FORWARD -i $bridge_name -o $hostmachine_iface -j ACCEPT
# It allows traffic to be forwarded (-j ACCEPT) from the $bridge_name (the bridge interface) to the $hostmachine_iface (the host machine's interface). It permits packets from the bridge to exit the host machine.
sudo iptables -A FORWARD -i $hostmachine_iface -o $bridge_name -m state --state RELATED,ESTABLISHED -j ACCEPT
# This command adds another rule to the FORWARD chain. It allows traffic to be forwarded from the $hostmachine_iface to the $bridge_name if the packets are related to an existing connection or belong to an established connection (-m state --state RELATED,ESTABLISHED). This rule permits response traffic to reach the correct destination in the bridge.
sudo iptables -A FORWARD -m state --state RELATED,ESTABLISHED -j ACCEPT
This command adds a rule to the FORWARD chain, allowing packets that are related to an existing connection or belong to an established connection to be forwarded. It ensures that response traffic can be correctly routed back to the originating network namespace or bridge.


+Setting the route on the node to reach the network namespaces on the other node
sudo ip route add $TO_BRIDGE_SUBNET via $TO_NODE_IP dev eth0
```

## cleanup
```diff
-cleanup
sudo ip link set $veth_bridge_to_ns1_endpoint_name down
sudo ip link set $veth_bridge_to_ns2_endpoint_name down
sudo ip link delete $veth_bridge_to_ns2_endpoint_name
sudo ip link delete $veth_bridge_to_ns1_endpoint_name
sudo ip netns delete $NS1
sudo ip netns delete $NS2
sudo ip link set $bridge_name down
sudo brctl delbr $bridge_name
```
delete the NAT rules from:
read: https://github.com/awcator/DevOpsJourneyWithArchLinux/blob/master/networking/iptables.md#see-all-the-rules-defined-from-all-the-tabels

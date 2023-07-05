Hostmachine: 8GB RAM, 4CPU 
# Hostmachine setup
```
export number_of_workers=3
export number_of_master=2
export hostmachine_iface="eth0"
export hostmachine_to_k8s_network_bridge="br0"
export bridge_netmask_bits=24
export bridge_subnet=10.1.0.0/$bridge_netmask_bits
export lxc_storage_name="awcator-k8s-storage"
export lxc_storage_type="dir"


pacman -S lxc lxd
sudo systemctl start lxc
sudo swapoff -a
```
# infra Setup (lXC/LXD)
```diff
#Storage Setup
lxc storage create $lxc_storage_name $lxc_storage_type
lxc storage list

# Networking setup
sudo ip link add $hostmachine_to_k8s_network_bridge type bridge
ip link show $hostmachine_to_k8s_network_bridge
IFS='.' read -ra octets <<< "$bridge_subnet"
octets[3]=$((octets[3]+1))
bridge_starting_ip="${octets[0]}.${octets[1]}.${octets[2]}.${octets[3]}" #10.1.0.1
sudo ip addr add $bridge_starting_ip/$bridge_netmask_bits dev $hostmachine_to_k8s_network_bridge
-#for wsl use legacy iptables 
sudo iptables-legacy -t nat -A POSTROUTING -s $bridge_subnet -o $hostmachine_to_k8s_network_bridge -j MASQUERADE
sudo iptables-legacy -A FORWARD -i $hostmachine_to_k8s_network_bridge -o $hostmachine_iface -j ACCEPT
sudo iptables-legacy -A FORWARD -i $hostmachine_iface -o $hostmachine_to_k8s_network_bridge -m state --state RELATED,ESTABLISHED -j ACCEPT
sudo iptables-legacy -A FORWARD -m state --state RELATED,ESTABLISHED -j ACCEPT
+#for linux hosts
sudo iptables -t nat -A POSTROUTING -s $bridge_subnet -o $hostmachine_to_k8s_network_bridge -j MASQUERADE
sudo iptables -A FORWARD -i $hostmachine_to_k8s_network_bridge -o $hostmachine_iface -j ACCEPT
sudo iptables -A FORWARD -i $hostmachine_iface -o $hostmachine_to_k8s_network_bridge -m state --state RELATED,ESTABLISHED -j ACCEPT
sudo iptables -A FORWARD -m state --state RELATED,ESTABLISHED -j ACCEPT



```

# Destroy
```
lxc storage delete $lxc_storage_name
echo "normal";
sudo iptables -F;
sudo iptables -X;
sudo iptables -Z;
sudo iptables-legacy -F;
sudo iptables-legacy -X;
sudo iptables-legacy -Z;
echo "filter";
sudo iptables -t filter -F;
sudo iptables -t filter -F;
sudo iptables -t filter -X;
sudo iptables -t filter -Z;
sudo iptables-legacy -t filter -F;
sudo iptables-legacy -t filter -F;
sudo iptables-legacy -t filter -X;
sudo iptables-legacy -t filter -Z;
echo "nat";
sudo iptables -t nat -F;
sudo iptables -t nat -X;
sudo iptables -t nat -Z;
sudo iptables-legacy -t nat -F;
sudo iptables-legacy -t nat -X;
sudo iptables-legacy -t nat -Z;
echo "mangle";
sudo iptables -t mangle -F;
sudo iptables -t mangle -X;
sudo iptables -t mangle -Z;
sudo iptables-legacy -t mangle -F;
sudo iptables-legacy -t mangle -X;
sudo iptables-legacy -t mangle -Z;
echo "raw";
sudo iptables -t raw -F;
sudo iptables -t raw -X;
sudo iptables -t raw -Z;
sudo iptables-legacy -t raw -F;
sudo iptables-legacy -t raw -X;
sudo iptables-legacy -t raw -Z;
echo "security";
sudo iptables -t security -F;
sudo iptables -t security -X;
sudo iptables -t security -Z;
sudo iptables-legacy -t security -F;
sudo iptables-legacy -t security -X;
sudo iptables-legacy -t security -Z;
sudo ip link set $hostmachine_to_k8s_network_bridge down
sudo brctl delbr $hostmachine_to_k8s_network_bridge
```

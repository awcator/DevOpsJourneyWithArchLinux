#!/bin/bash
echo "Restarting lxd service"
sudo systemctl start lxd
sudo modprobe nf_conntrack
export number_of_workers=2
export number_of_master=1
export hostmachine_iface="wlp0s20u2"
export hostmachine_to_k8s_network_bridge="br0"
export bridge_netmask_bits=24
export bridge_subnet=172.16.0.0/$bridge_netmask_bits
export lxc_storage_name="awcator-k8s-storage"
export lxc_storage_type="dir"
export lxc_k8s_profile="k8s-profile"
IFS='.' read -ra octets <<< "$bridge_subnet"
octets[3]=$((octets[3]+1))
bridge_starting_ip="${octets[0]}.${octets[1]}.${octets[2]}.${octets[3]}" #172.16.0.1
IFS='.' read -ra octets <<< "$bridge_starting_ip"
octets[3]=$((octets[3]+1))
haproxy_ip="${octets[0]}.${octets[1]}.${octets[2]}.${octets[3]}" #172.16.0.2


echo "Applying some sysctl parameters"
sudo swapoff -a
sudo sysctl -w net.netfilter.nf_conntrack_max=131072
sudo sysctl -w kernel/panic=10   #reset to 0
sudo sysctl -w kernel/panic_on_oops=1 #reset to 0
# sudo mkdir /sys/fs/cgroup/systemd
# sudo mount -t cgroup -o none,name=systemd cgroup /sys/fs/cgroup/systemd
mkdir ~/k8ssetup
cd ~/k8ssetup

echo "Createing interfaces"
sudo ip link add $hostmachine_to_k8s_network_bridge type bridge
sudo ip link set dev $hostmachine_to_k8s_network_bridge up
ip link show $hostmachine_to_k8s_network_bridge
sudo ip addr add $bridge_starting_ip/$bridge_netmask_bits dev $hostmachine_to_k8s_network_bridge
sudo sysctl net.ipv4.ip_forward=1

echo "Creating ip masquerade "
sudo iptables-legacy -t nat -A POSTROUTING -o $hostmachine_iface  -j MASQUERADE
sudo iptables-legacy -t nat -A POSTROUTING -s $bridge_subnet -o $hostmachine_to_k8s_network_bridge -j MASQUERADE
sudo iptables-legacy -A FORWARD -i $hostmachine_to_k8s_network_bridge -o $hostmachine_iface -j ACCEPT
sudo iptables-legacy -A FORWARD -i $hostmachine_iface -o $hostmachine_to_k8s_network_bridge -m state --state RELATED,ESTABLISHED -j ACCEPT
sudo iptables-legacy -A FORWARD -m state --state RELATED,ESTABLISHED -j ACCEPT
sudo iptables -t nat -A POSTROUTING -o $hostmachine_iface  -j MASQUERADE
sudo iptables -t nat -A POSTROUTING -s $bridge_subnet -o $hostmachine_to_k8s_network_bridge -j MASQUERADE
sudo iptables -A FORWARD -i $hostmachine_to_k8s_network_bridge -o $hostmachine_iface -j ACCEPT
sudo iptables -A FORWARD -i $hostmachine_iface -o $hostmachine_to_k8s_network_bridge -m state --state RELATED,ESTABLISHED -j ACCEPT
sudo iptables -A FORWARD -m state --state RELATED,ESTABLISHED -j ACCEPT

echo "restarting all machines"
lxc start --all

echo ---restaring--------
sleep 90
echo "adding pod cidr routes "
for instance in $(seq 1 "$number_of_workers"); do
POD_CIDR=10.1.${instance}.0/24
NODE_IP=$(lxc ls |\grep worker-${instance}|awk {'print $6'})
sudo ip route add $POD_CIDR via $NODE_IP dev $hostmachine_to_k8s_network_bridge
done

echo "adding cluster ip cidr route" 
WORKER_NODE_IP=$(lxc ls |\grep worker-1|awk {'print $6'})
sudo ip route add 10.32.0.0/24 via $WORKER_NODE_IP dev $hostmachine_to_k8s_network_bridge

sleep 10

echo "Adding systemd cgroup"
sudo mkdir /sys/fs/cgroup/systemd
sudo mount -t cgroup -o none,name=systemd cgroup /sys/fs/cgroup/systemd
# from LXC's worker nodes
for i in $(seq 1 "$number_of_workers"); do
  instance=worker-${i}
  lxc exec $instance -- mkdir /sys/fs/cgroup/systemd
  lxc exec $instance -- mount -t cgroup -o none,name=systemd cgroup /sys/fs/cgroup/systemd
done
sudo umount /sys/fs/cgroup/systemd # if i dont unwont, lxc wont restart unless i unmount. dont know why
# dont unmount inside lxc's. not sure why, it works


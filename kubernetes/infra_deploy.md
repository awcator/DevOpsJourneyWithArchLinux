Hostmachine: 8GB RAM, 4CPU 
# Hostmachine setup
```
pacman -S lxc lxd
sudo systemctl start lxd

export number_of_workers=3
export number_of_master=2
export hostmachine_iface="eth0"
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


sudo swapoff -a
mkdir ~/k8ssetup
cd ~/k8ssetup
```
# infra Setup (lXC/LXD)
```diff
#Storage Setup
lxc storage create $lxc_storage_name $lxc_storage_type
lxc storage list

# Networking setup
sudo ip link add $hostmachine_to_k8s_network_bridge type bridge
sudo ip link set dev $hostmachine_to_k8s_network_bridge up
ip link show $hostmachine_to_k8s_network_bridge
sudo ip addr add $bridge_starting_ip/$bridge_netmask_bits dev $hostmachine_to_k8s_network_bridge
sudo sysctl net.ipv4.ip_forward=1

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


#Lxc profile setup

cat <<EOF |tee $lxc_k8s_profile.yaml
config:
  limits.cpu: "2"
  limits.memory.swap: "false"
  boot.autostart: "false"
  linux.kernel_modules: ip_tables,ip6_tables,netlink_diag,nf_nat,overlay,br_netfilter
  raw.lxc: |
    lxc.apparmor.profile=unconfined
    lxc.mount.auto=proc:rw sys:rw cgroup:rw
    lxc.cgroup.devices.allow=a
    lxc.cap.drop=
  security.nesting: "true"
  security.privileged: "true"
description: "Awcator kubernetes nodes"
devices:
  eth0:
    name: eth0
    nictype: bridged
    parent: br0
    type: nic
  aadisable:
    path: /sys/module/nf_conntrack/parameters/hashsize
    source: /dev/null
    type: disk
  aadisable1:
    path: /sys/module/apparmor/parameters/enabled
    source: /dev/null
    type: disk
EOF

-# for WSL
cat <<EOF |tee $lxc_k8s_profile.yaml
config:
  limits.memory.swap: "false"
  boot.autostart: "false"
  raw.lxc: |
    lxc.apparmor.profile=unconfined
    lxc.mount.auto=proc:rw sys:rw cgroup:rw
    lxc.cgroup.devices.allow=a
    lxc.cap.drop=
  security.nesting: "true"
  security.privileged: "true"
description: "Awcator kubernetes nodes"
devices:
  eth0:
    name: eth0
    nictype: bridged
    parent: br0
    type: nic
EOF

lxc profile create $lxc_k8s_profile
cat $lxc_k8s_profile.yaml | lxc profile edit $lxc_k8s_profile
lxc profile show $lxc_k8s_profile

$ lxd init
# Would you like to use LXD clustering? (yes/no) [default=no]: no
# Do you want to configure a new storage pool? (yes/no) [default=yes]: no
# Would you like to connect to a MAAS server? (yes/no) [default=no]: no
# Would you like to create a new local network bridge? (yes/no) [default=yes]: no
# Would you like to configure LXD to use an existing bridge or host interface? (yes/no) [default=no]: yes
# Name of the existing bridge or host interface: br0
# Would you like the LXD server to be available over the network? (yes/no) [default=no]: no
# Would you like stale cached images to be updated automatically? (yes/no) [default=yes]: yes
# Would you like a YAML "lxd init" preseed to be printed? (yes/no) [default=no]: yes


#Launch Instances-masternodes
echo "createing master nodes"
for ((i=1; i<=number_of_master; i++))
do
  lxc launch images:ubuntu/18.04/amd64 controller-${i} -p $lxc_k8s_profile -s $lxc_storage_name
done
#Launch Instances-workernodes
for ((i=1; i<=number_of_workers; i++))
do
  lxc launch images:ubuntu/18.04/amd64 worker-${i} -p $lxc_k8s_profile -s $lxc_storage_name
done
#Launch loadbalancer
lxc launch images:ubuntu/18.04/amd64 haproxy -p $lxc_k8s_profile -s $lxc_storage_name
lxc list


# setup networking for launched instances (Haproxy )
cat <<EOF |tee 10-lxc.yaml
network:
  version: 2
  ethernets:
    eth0:
       dhcp4: no
       addresses: [$haproxy_ip/$bridge_netmask_bits]
       gateway4: $bridge_starting_ip
       nameservers:
         addresses: [$bridge_starting_ip,8.8.8.8,8.8.4.4]
EOF
sudo lxc file push 10-lxc.yaml haproxy/etc/netplan/
lxc exec haproxy -- sudo netplan apply
lxc exec haproxy -- ping 8.8.8.8 -c 2 #should work


# setup networking for launched instances (Master nodes)
for ((i=1; i<=number_of_master; i++))
do
IFS='.' read -ra octets <<< "$haproxy_ip"
octets[3]=$((octets[3]+i))
curent_master_ip="${octets[0]}.${octets[1]}.${octets[2]}.${octets[3]}" #172.16.0.3,#172.16.0.4
cat <<EOF |tee 10-lxc.yaml
network:
  version: 2
  ethernets:
    eth0:
       dhcp4: no
       addresses: [$curent_master_ip/$bridge_netmask_bits]
       gateway4: $bridge_starting_ip
       nameservers:
         addresses: [$bridge_starting_ip,8.8.8.8,8.8.4.4]
EOF
lxc file push 10-lxc.yaml controller-${i}/etc/netplan/
lxc exec controller-${i} -- sudo netplan apply
lxc exec controller-${i} -- ping 8.8.8.8 -c 2 #should work
done



# setup networking for launched instances (Worker nodes)
IFS='.' read -ra octets <<< "$haproxy_ip"
octets[3]=$((octets[3]+number_of_master))
end_of_masterip="${octets[0]}.${octets[1]}.${octets[2]}.${octets[3]}" #172.16.0.4
for ((i=1; i<=number_of_workers; i++))
do
IFS='.' read -ra octets <<< "$end_of_masterip"
octets[3]=$((octets[3]+i))
curent_worker_ip="${octets[0]}.${octets[1]}.${octets[2]}.${octets[3]}" #172.16.0.5,#172.16.0.6,172.16.0.7
cat <<EOF |tee 10-lxc.yaml
network:
  version: 2
  ethernets:
    eth0:
       dhcp4: no
       addresses: [$curent_worker_ip/$bridge_netmask_bits]
       gateway4: $bridge_starting_ip
       nameservers:
         addresses: [$bridge_starting_ip,8.8.8.8,8.8.4.4]
EOF
lxc file push 10-lxc.yaml worker-${i}/etc/netplan/
lxc exec worker-${i} -- sudo netplan apply
lxc exec worker-${i} -- ping 8.8.8.8 -c 2 #should work
done

 lxc ls
+--------------+---------+-------------------+------+-----------+-----------+
|     NAME     |  STATE  |       IPV4        | IPV6 |   TYPE    | SNAPSHOTS |
+--------------+---------+-------------------+------+-----------+-----------+
| controller-1 | RUNNING | 172.16.0.3 (eth0) |      | CONTAINER | 0         |
+--------------+---------+-------------------+------+-----------+-----------+
| controller-2 | RUNNING | 172.16.0.4 (eth0) |      | CONTAINER | 0         |
+--------------+---------+-------------------+------+-----------+-----------+
| haproxy      | RUNNING | 172.16.0.2 (eth0) |      | CONTAINER | 0         |
+--------------+---------+-------------------+------+-----------+-----------+
| worker-1     | RUNNING | 172.16.0.5 (eth0) |      | CONTAINER | 0         |
+--------------+---------+-------------------+------+-----------+-----------+
| worker-2     | RUNNING | 172.16.0.6 (eth0) |      | CONTAINER | 0         |
+--------------+---------+-------------------+------+-----------+-----------+
| worker-3     | RUNNING | 172.16.0.7 (eth0) |      | CONTAINER | 0         |
+--------------+---------+-------------------+------+-----------+-----------+

```

# Destroy
```
for i in $(seq 1 "$number_of_workers"); do
  echo "worker-$i"
done | xargs -I {} lxc delete {} --force

for i in $(seq 1 "$number_of_master"); do
  echo "controller-$i"
done | xargs -I {} lxc delete {} --force

lxc delete haproxy --force
\rm -rf ~/k8ssetup
lxc storage delete $lxc_storage_name
lxc profile delete $lxc_k8s_profile
sudo systemctl stop lxc lxd
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

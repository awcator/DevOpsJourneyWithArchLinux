Hostmachine: 8GB RAM, 4CPU 
# Hostmachine setup
```
pacman -S lxc lxd
sudo systemctl start lxd

export number_of_workers=2
export number_of_master=2
export hostmachine_iface="enp0s20u2"
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
sudo sysctl -w net.netfilter.nf_conntrack_max=131072
sudo sysctl -w kernel/panic=10   #reset to 0
sudo sysctl -w kernel/panic_on_oops=1 #reset to 0
# sudo mkdir /sys/fs/cgroup/systemd
# sudo mount -t cgroup -o none,name=systemd cgroup /sys/fs/cgroup/systemd
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
sudo iptables-legacy -t nat -A POSTROUTING -o $hostmachine_iface  -j MASQUERADE
sudo iptables-legacy -t nat -A POSTROUTING -s $bridge_subnet -o $hostmachine_to_k8s_network_bridge -j MASQUERADE
sudo iptables-legacy -A FORWARD -i $hostmachine_to_k8s_network_bridge -o $hostmachine_iface -j ACCEPT
sudo iptables-legacy -A FORWARD -i $hostmachine_iface -o $hostmachine_to_k8s_network_bridge -m state --state RELATED,ESTABLISHED -j ACCEPT
sudo iptables-legacy -A FORWARD -m state --state RELATED,ESTABLISHED -j ACCEPT
+#for linux hosts
sudo iptables -t nat -A POSTROUTING -o $hostmachine_iface  -j MASQUERADE
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
    lxc.cgroup.devices.allow=a
    lxc.cgroup.devices.deny=c 5:1 rwm
    lxc.cgroup.devices.deny=c 5:0 rwm
    lxc.cgroup.devices.deny=c 1:9 rwm
    lxc.cgroup.devices.deny=c 1:8 rwm
  security.nesting: "true"
  security.privileged: "true"
description: "Awcator kubernetes nodes"
devices:
  eth0:
    name: eth0
    nictype: bridged
    parent: ${hostmachine_to_k8s_network_bridge}
    type: nic
  aadisable:
    path: /sys/module/nf_conntrack/parameters/hashsize
    source: /dev/null
    type: disk
  aadisable1:
    path: /sys/module/apparmor/parameters/enabled
    source: /dev/null
    type: disk
  kmsg:
    path: /dev/kmsg
    type: unix-char
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
sudo sh -c 'echo 3 >/proc/sys/vm/drop_caches'

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
lxc exec haproxy -- hostnamectl set-hostname haproxy
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
        routes:
          - to: 10.200.${i}.0/24
            via: $curent_master_ip
        nameservers:
          addresses: [$bridge_starting_ip,8.8.8.8,8.8.4.4]
EOF
lxc file push 10-lxc.yaml controller-${i}/etc/netplan/
lxc exec controller-${i} -- sudo netplan apply
lxc exec controller-${i} -- hostnamectl set-hostname  controller-${i}
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
        routes:
          - to: 10.200.${i}.0/24
            via: $curent_worker_ip
        gateway4: $bridge_starting_ip
        nameservers:
          addresses: [$bridge_starting_ip,8.8.8.8,8.8.4.4]
EOF
lxc file push 10-lxc.yaml worker-${i}/etc/netplan/
lxc exec worker-${i} -- sudo netplan apply
lxc exec worker-${i} -- hostnamectl set-hostname  worker-${i}
lxc exec worker-${i} -- ping 8.8.8.8 -c 2 #should work
done
sudo sh -c 'echo 3 >/proc/sys/vm/drop_caches'
lxc restart --all
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
#upadte hosts file or running custom dnsserver (coredns/dnsmasq on hostmachine) add it in resolv.conf
lxc_output=$(lxc ls|\grep RUNNING)
hosts=""
while IFS= read -r line; do
    # Extract the hostname and IP address using awk
    hostname=$(echo "$line" | awk '{print $2}')
    ip=$(echo "$line" | awk '{print $6}')
    # Append the hostname and IP address to the hosts variable
    hosts+="\n$ip $hostname"
done <<< "$lxc_output"
hosts=$(echo "$hosts" | sed '/^$/d')
echo -e "$hosts"
hosts=$(echo "$hosts" | sed '/^$/d')
hosts_file="/etc/hosts"
echo "writings hosts to haproxy"
lxc exec haproxy -- /bin/bash -c "echo -e '$hosts' | sudo tee -a '$hosts_file' "
lxc exec haproxy -- /bin/bash -c "echo -e \"$hosts\" | awk '{print \$2}' | xargs -I{} ping -c 2 {}"
echo "writings hosts to workers"
for ((i=1; i<=number_of_workers; i++)) do
  lxc exec worker-${i} -- /bin/bash -c "echo -e '$hosts' | sudo tee -a '$hosts_file' "
  lxc exec worker-${i} -- /bin/bash -c "echo -e \"$hosts\" | awk '{print \$2}' | xargs -I{} ping -c 2 {}"
done
echo "writings hosts to master"
for ((i=1; i<=number_of_master; i++)) do
  lxc exec controller-${i} -- /bin/bash -c "echo -e '$hosts' | sudo tee -a '$hosts_file' "
  lxc exec controller-${i} -- /bin/bash -c "echo -e \"$hosts\" | awk '{print \$2}' | xargs -I{} ping -c 2 {}"
done
```
# PKI
```
# CA
cat > ca-config.json <<EOF
{
  "signing": {
    "default": {
      "expiry": "8760h"
    },
    "profiles": {
      "kubernetes": {
        "usages": ["signing", "key encipherment", "server auth", "client auth"],
        "expiry": "8760h"
      }
    }
  }
}
EOF

cat > ca-csr.json <<EOF
{
  "CN": "Kubernetes",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Portland",
      "O": "Kubernetes",
      "OU": "CA",
      "ST": "Oregon"
    }
  ]
}
EOF

cfssl gencert -initca ca-csr.json | cfssljson -bare ca


# Admin client certificate
cat > admin-csr.json <<EOF
{
  "CN": "admin",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Plano",
      "O": "system:masters",
      "OU": "Kubernetes The Hard Way on LXD",
      "ST": "Texas"
    }
  ]
}
EOF

cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -profile=kubernetes admin-csr.json | cfssljson -bare admin

#  Kubelet Client Certificates
for i in $(seq 1 "$number_of_workers"); do
cat > worker-${i}-csr.json <<EOF
{
  "CN": "system:node:worker-${i}",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Plano",
      "O": "system:nodes",
      "OU": "Kubernetes The Hard Way on LXD",
      "ST": "Texas"
    }
  ]
}
EOF
EXTERNAL_IP=$haproxy_ip
NODE_IP=$(lxc ls |\grep worker-${i}|awk {'print $6'})

cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -hostname=worker-${i},${EXTERNAL_IP},${NODE_IP},${bridge_starting_ip} -profile=kubernetes worker-${i}-csr.json | cfssljson -bare worker-${i}
done


# kube-controller-manager
cat > kube-controller-manager-csr.json <<EOF
{
  "CN": "system:kube-controller-manager",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Plano",
      "O": "system:kube-controller-manager",
      "OU": "Kubernetes The Hard Way on LXD",
      "ST": "Texas"
    }
  ]
}
EOF

cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -profile=kubernetes kube-controller-manager-csr.json | cfssljson -bare kube-controller-manager


#The Kube Proxy Client Certificate
cat > kube-proxy-csr.json <<EOF
{
  "CN": "system:kube-proxy",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Plano",
      "O": "system:node-proxier",
      "OU": "Kubernetes The Hard Way on LXD",
      "ST": "Texas"
    }
  ]
}
EOF

cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -profile=kubernetes kube-proxy-csr.json | cfssljson -bare kube-proxy


# The Scheduler Client Certificate
cat > kube-scheduler-csr.json <<EOF
{
  "CN": "system:kube-scheduler",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Plano",
      "O": "system:kube-scheduler",
      "OU": "Kubernetes The Hard Way on LXD",
      "ST": "Texas"
    }
  ]
}
EOF

cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -profile=kubernetes kube-scheduler-csr.json | cfssljson -bare kube-scheduler

#The Kubernetes API Server Certificate
KUBERNETES_PUBLIC_ADDRESS=$haproxy_ip
cat > kubernetes-csr.json <<EOF
{
  "CN": "kubernetes",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Plano",
      "O": "Kubernetes",
      "OU": "Kubernetes The Hard Way on LXD",
      "ST": "Texas"
    }
  ]
}
EOF
list_of_masterips=`lxc ls|\grep controller|awk {'print $6'}|tr '\n' ','|paste -sd ','`
cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -hostname=10.32.0.1,$list_of_masterips${KUBERNETES_PUBLIC_ADDRESS},${bridge_starting_ip},127.0.0.1,kubernetes.default -profile=kubernetes kubernetes-csr.json | cfssljson -bare kubernetes


#service account
cat > service-account-csr.json <<EOF
{
  "CN": "service-accounts",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Plano",
      "O": "Kubernetes",
      "OU": "Kubernetes The Hard Way with LXD",
      "ST": "Texas"
    }
  ]
}
EOF

cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -profile=kubernetes service-account-csr.json | cfssljson -bare service-account

#upload certs to nodes
for i in $(seq 1 "$number_of_workers"); do
  lxc file push ca.pem worker-${i}/home/ubuntu/
  lxc file push worker-${i}-key.pem worker-${i}/home/ubuntu/
  lxc file push worker-${i}.pem worker-${i}/home/ubuntu/
  lxc exec worker-${i} ls /home/ubuntu/
done

for i in $(seq 1 "$number_of_master"); do
  lxc file push ca.pem controller-${i}/home/ubuntu/
  lxc file push ca-key.pem controller-${i}/home/ubuntu/
  lxc file push kubernetes-key.pem controller-${i}/home/ubuntu/
  lxc file push kubernetes.pem controller-${i}/home/ubuntu/
  lxc file push service-account-key.pem controller-${i}/home/ubuntu/
  lxc file push service-account.pem  controller-${i}/home/ubuntu/
  lxc exec controller-${i} ls /home/ubuntu/
done
```
# kube-configs
```
# The kubelet Kubernetes Configuration File
KUBERNETES_PUBLIC_ADDRESS=$haproxy_ip
for i in $(seq 1 "$number_of_workers"); do
  instance=worker-${i}
  kubectl config set-cluster kubernetes-the-hard-way --certificate-authority=ca.pem --embed-certs=true --server=https://${KUBERNETES_PUBLIC_ADDRESS}:6443 --kubeconfig=${instance}.kubeconfig
  kubectl config set-credentials system:node:${instance} --client-certificate=${instance}.pem --client-key=${instance}-key.pem --embed-certs=true --kubeconfig=${instance}.kubeconfig
  kubectl config set-context default --cluster=kubernetes-the-hard-way --user=system:node:${instance} --kubeconfig=${instance}.kubeconfig
  kubectl config use-context default --kubeconfig=${instance}.kubeconfig
done

#The kube-proxy Kubernetes Configuration File
kubectl config set-cluster kubernetes-the-hard-way --certificate-authority=ca.pem --embed-certs=true --server=https://${KUBERNETES_PUBLIC_ADDRESS}:6443 --kubeconfig=kube-proxy.kubeconfig
kubectl config set-credentials system:kube-proxy --client-certificate=kube-proxy.pem --client-key=kube-proxy-key.pem --embed-certs=true --kubeconfig=kube-proxy.kubeconfig
kubectl config set-context default --cluster=kubernetes-the-hard-way --user=system:kube-proxy --kubeconfig=kube-proxy.kubeconfig
kubectl config use-context default --kubeconfig=kube-proxy.kubeconfig

#The kube-controller-manager Kubernetes Configuration File
kubectl config set-cluster kubernetes-the-hard-way --certificate-authority=ca.pem --embed-certs=true --server=https://127.0.0.1:6443 --kubeconfig=kube-controller-manager.kubeconfig
kubectl config set-credentials system:kube-controller-manager --client-certificate=kube-controller-manager.pem --client-key=kube-controller-manager-key.pem --embed-certs=true --kubeconfig=kube-controller-manager.kubeconfig
kubectl config set-context default --cluster=kubernetes-the-hard-way --user=system:kube-controller-manager --kubeconfig=kube-controller-manager.kubeconfig
kubectl config use-context default --kubeconfig=kube-controller-manager.kubeconfig

# The kube-scheduler Kubernetes Configuration File
kubectl config set-cluster kubernetes-the-hard-way --certificate-authority=ca.pem --embed-certs=true --server=https://127.0.0.1:6443 --kubeconfig=kube-scheduler.kubeconfig
kubectl config set-credentials system:kube-scheduler --client-certificate=kube-scheduler.pem --client-key=kube-scheduler-key.pem --embed-certs=true --kubeconfig=kube-scheduler.kubeconfig
kubectl config set-context default --cluster=kubernetes-the-hard-way --user=system:kube-scheduler --kubeconfig=kube-scheduler.kubeconfig
kubectl config use-context default --kubeconfig=kube-scheduler.kubeconfig

# The admin Kubernetes Configuration File
kubectl config set-cluster kubernetes-the-hard-way --certificate-authority=ca.pem --embed-certs=true --server=https://127.0.0.1:6443 --kubeconfig=admin.kubeconfig
kubectl config set-credentials admin --client-certificate=admin.pem --client-key=admin-key.pem --embed-certs=true --kubeconfig=admin.kubeconfig
kubectl config set-context default --cluster=kubernetes-the-hard-way --user=admin --kubeconfig=admin.kubeconfig
kubectl config use-context default --kubeconfig=admin.kubeconfig


#upload
for i in $(seq 1 "$number_of_workers"); do
  instance=worker-${i}
  lxc file push ${instance}.kubeconfig ${instance}/home/ubuntu/
  lxc file push kube-proxy.kubeconfig ${instance}/home/ubuntu/
  lxc exec  ${instance} -- ls /home/ubuntu/
done

for i in $(seq 1 "$number_of_master"); do
  instance=controller-${i}
  lxc file push admin.kubeconfig ${instance}/home/ubuntu/
  lxc file push kube-controller-manager.kubeconfig ${instance}/home/ubuntu/
  lxc file push kube-scheduler.kubeconfig ${instance}/home/ubuntu/
  lxc exec  ${instance} -- ls /home/ubuntu/
done
sudo sh -c 'echo 3 >/proc/sys/vm/drop_caches'
```
# Bootstrap nodes
```

# etcd
ENCRYPTION_KEY=$(head -c 32 /dev/urandom | base64)
cat > encryption-config.yaml <<EOF
kind: EncryptionConfig
apiVersion: v1
resources:
  - resources:
      - secrets
    providers:
      - aescbc:
          keys:
            - name: key1
              secret: ${ENCRYPTION_KEY}
      - identity: {}
EOF

for i in $(seq 1 "$number_of_master"); do
  instance=controller-${i}
  lxc file push encryption-config.yaml ${instance}/home/ubuntu/
  lxc exec  ${instance} -- ls /home/ubuntu/
done

wget -q --show-progress --https-only --timestamping "https://github.com/etcd-io/etcd/releases/download/v3.4.15/etcd-v3.4.15-linux-amd64.tar.gz"
for i in $(seq 1 "$number_of_master"); do
  instance=controller-${i}
  lxc file push etcd-v3.4.15-linux-amd64.tar.gz ${instance}/home/ubuntu/
  lxc exec ${instance} -- tar -xvf /home/ubuntu/etcd-v3.4.15-linux-amd64.tar.gz -C /home/ubuntu/
  lxc exec ${instance} -- mv /home/ubuntu/etcd-v3.4.15-linux-amd64/etcd /usr/local/bin/
  lxc exec ${instance} -- mv /home/ubuntu/etcd-v3.4.15-linux-amd64/etcdctl /usr/local/bin/

  lxc exec ${instance} -- mkdir -p /etc/etcd /var/lib/etcd
  lxc exec ${instance} -- cp /home/ubuntu/ca.pem /etc/etcd/
  lxc exec ${instance} -- cp /home/ubuntu/kubernetes-key.pem /etc/etcd/
  lxc exec ${instance} -- cp /home/ubuntu/kubernetes.pem /etc/etcd/
  lxc exec $instance -- ls  /etc/etcd/
done


etcd_servers_list="" 
count=0
for x in `lxc ls|\grep controller|awk {'print $6'}`; 
do 
	(( count++ )); 
	etcd_servers_list="${etcd_servers_list}controller-$count=https://$x:2380," ; 
done
etcd_servers_list=`echo $etcd_servers_list|sed 's/.$//'`
echo $etcd_servers_list

for i in $(seq 1 "$number_of_master"); do
NODE_IP=$(lxc ls |\grep controller-${i}|awk {'print $6'})
ETCD_NAME=controller-${i}
cat <<EOF | tee etcd.service
[Unit]
Description=etcd
Documentation=https://github.com/coreos
[Service]
ExecStart=/usr/local/bin/etcd \\
  --name ${ETCD_NAME} \\
  --cert-file=/etc/etcd/kubernetes.pem \\
  --key-file=/etc/etcd/kubernetes-key.pem \\
  --peer-cert-file=/etc/etcd/kubernetes.pem \\
  --peer-key-file=/etc/etcd/kubernetes-key.pem \\
  --trusted-ca-file=/etc/etcd/ca.pem \\
  --peer-trusted-ca-file=/etc/etcd/ca.pem \\
  --peer-client-cert-auth \\
  --client-cert-auth \\
  --initial-advertise-peer-urls https://${NODE_IP}:2380 \\
  --listen-peer-urls https://${NODE_IP}:2380 \\
  --listen-client-urls https://${NODE_IP}:2379,https://127.0.0.1:2379 \\
  --advertise-client-urls https://${NODE_IP}:2379 \\
  --initial-cluster-token etcd-cluster-0 \\
  --initial-cluster ${etcd_servers_list} \\
  --initial-cluster-state new \\
  --data-dir=/var/lib/etcd
Restart=on-failure
RestartSec=5
[Install]
WantedBy=multi-user.target
EOF

lxc file push etcd.service ${ETCD_NAME}/etc/systemd/system/
lxc exec ${ETCD_NAME} -- systemctl daemon-reload
lxc exec ${ETCD_NAME} -- systemctl enable etcd
lxc exec ${ETCD_NAME} -- systemctl start etcd
lxc exec ${ETCD_NAME} -- systemctl --no-pager status etcd 
done
sleep 10
# Etcd verification
for i in $(seq 1 "$number_of_master"); do
lxc exec controller-${i} -- bash -c "ETCDCTL_API=3 /usr/local/bin/etcdctl member list --endpoints=https://127.0.0.1:2379 --cacert=/etc/etcd/ca.pem --cert=/etc/etcd/kubernetes.pem --key=/etc/etcd/kubernetes-key.pem"
done
sudo sh -c 'echo 3 >/proc/sys/vm/drop_caches'

# haproxy node
lxc exec haproxy -- apt-get update
lxc exec haproxy -- apt-get install -y haproxy

lxc exec haproxy -- sudo tee -a /etc/haproxy/haproxy.cfg << END
frontend haproxynode
    bind *:6443
    mode tcp
    option tcplog
    default_backend backendnodes
backend backendnodes
    mode tcp    
    option tcp-check
    balance roundrobin
    default-server inter 10s downinter 5s rise 2 fall 2 slowstart 60s maxconn 250 maxqueue 256 weight 100
END
for ((i=1; i<=number_of_master; i++))
do
EXTERNAL_IP=$(lxc ls |\grep controller-${i}|awk {'print $6'})
lxc exec haproxy -- sudo tee -a /etc/haproxy/haproxy.cfg << END
    server node${i} ${EXTERNAL_IP}:6443 check
END
done
lxc exec haproxy -- cat /etc/haproxy/haproxy.cfg
lxc exec haproxy -- sudo service haproxy restart
lxc exec haproxy -- sudo service haproxy status


# masternodes
wget -q --show-progress --https-only --timestamping "https://storage.googleapis.com/kubernetes-release/release/v1.22.3/bin/linux/amd64/kube-apiserver" \
"https://storage.googleapis.com/kubernetes-release/release/v1.22.3/bin/linux/amd64/kube-controller-manager" \
"https://storage.googleapis.com/kubernetes-release/release/v1.22.3/bin/linux/amd64/kube-scheduler" \
"https://storage.googleapis.com/kubernetes-release/release/v1.22.3/bin/linux/amd64/kubectl" 
chmod +x kube-apiserver kube-controller-manager kube-scheduler kubectl

for i in $(seq 1 "$number_of_master"); do
    instance=controller-${i}
# Create the Kubernetes configuration directory:
    lxc exec ${instance} -- mkdir -p /etc/kubernetes/config
# Install the Kubernetes binaries:
    lxc file push kube-apiserver ${instance}/usr/local/bin/
    lxc file push kube-controller-manager ${instance}/usr/local/bin/
    lxc file push kube-scheduler ${instance}/usr/local/bin/
    lxc file push kubectl ${instance}/usr/local/bin/
# Configure the Kubernetes API Server
  lxc exec ${instance} -- mkdir -p /var/lib/kubernetes/
  lxc file push ca.pem ${instance}/var/lib/kubernetes/
  lxc file push ca-key.pem ${instance}/var/lib/kubernetes/
  lxc file push kubernetes-key.pem ${instance}/var/lib/kubernetes/
  lxc file push kubernetes.pem ${instance}/var/lib/kubernetes/
  lxc file push service-account-key.pem ${instance}/var/lib/kubernetes/
  lxc file push service-account.pem ${instance}/var/lib/kubernetes/
  lxc file push encryption-config.yaml ${instance}/var/lib/kubernetes/
done

KUBERNETES_PUBLIC_ADDRESS=$haproxy_ip
etcd_servers_list=""   #https://172.16.0.3:2379,https://172.16.0.4:2379
for x in `lxc ls|\grep controller|awk {'print $6'}`; 
do 
	etcd_servers_list="${etcd_servers_list}https://$x:2379," ; 
done
etcd_servers_list=`echo $etcd_servers_list|sed 's/.$//'`
echo $etcd_servers_list
for i in $(seq 1 "$number_of_master"); do
INTERNAL_IP=$(lxc ls |\grep controller-${i}|awk {'print $6'})
cat <<EOF | tee kube-apiserver.service
[Unit]
Description=Kubernetes API Server
Documentation=https://github.com/kubernetes/kubernetes
[Service]
ExecStart=/usr/local/bin/kube-apiserver \\
  --advertise-address=${INTERNAL_IP} \\
  --allow-privileged=true \\
  --apiserver-count=${number_of_master} \\
  --audit-log-maxage=30 \\
  --audit-log-maxbackup=3 \\
  --audit-log-maxsize=100 \\
  --audit-log-path=/var/log/audit.log \\
  --authorization-mode=Node,RBAC \\
  --bind-address=0.0.0.0 \\
  --client-ca-file=/var/lib/kubernetes/ca.pem \\
  --enable-admission-plugins=NamespaceLifecycle,NodeRestriction,LimitRanger,ServiceAccount,DefaultStorageClass,ResourceQuota \\
  --enable-swagger-ui=true \\
  --etcd-cafile=/var/lib/kubernetes/ca.pem \\
  --etcd-certfile=/var/lib/kubernetes/kubernetes.pem \\
  --etcd-keyfile=/var/lib/kubernetes/kubernetes-key.pem \\
  --etcd-servers=${etcd_servers_list} \\
  --event-ttl=1h \\
  --experimental-encryption-provider-config=/var/lib/kubernetes/encryption-config.yaml \\
  --kubelet-certificate-authority=/var/lib/kubernetes/ca.pem \\
  --kubelet-client-certificate=/var/lib/kubernetes/kubernetes.pem \\
  --kubelet-client-key=/var/lib/kubernetes/kubernetes-key.pem \\
  --runtime-config api/all=true \\
  --service-account-key-file=/var/lib/kubernetes/service-account.pem \\
  --service-cluster-ip-range=10.32.0.0/24 \\
  --service-node-port-range=30000-32767 \\
  --tls-cert-file=/var/lib/kubernetes/kubernetes.pem \\
  --tls-private-key-file=/var/lib/kubernetes/kubernetes-key.pem \\
  --service-account-key-file=/var/lib/kubernetes/service-account.pem \\
  --service-account-signing-key-file=/var/lib/kubernetes/service-account-key.pem \\
  --service-account-issuer=https://${KUBERNETES_PUBLIC_ADDRESS}:6443 \\
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# --kubelet-preferred-address-types=InternalIP,ExternalIP,Hostname 
# if you prefer IP over DNS
lxc file push kube-apiserver.service controller-${i}/etc/systemd/system/
done;

# Configure the Kubernetes Controller Manager
cat <<EOF | tee kube-controller-manager.service
[Unit]
Description=Kubernetes Controller Manager
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-controller-manager \\
  --address=0.0.0.0 \\
  --cluster-cidr=10.200.0.0/16 \\
  --cluster-name=kubernetes \\
  --cluster-signing-cert-file=/var/lib/kubernetes/ca.pem \\
  --cluster-signing-key-file=/var/lib/kubernetes/ca-key.pem \\
  --kubeconfig=/var/lib/kubernetes/kube-controller-manager.kubeconfig \\
  --leader-elect=true \\
  --root-ca-file=/var/lib/kubernetes/ca.pem \\
  --service-account-private-key-file=/var/lib/kubernetes/service-account-key.pem \\
  --service-cluster-ip-range=10.32.0.0/24 \\
  --use-service-account-credentials=true \\
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
for i in $(seq 1 "$number_of_master"); do
  instance=controller-${i}
  lxc file push kube-controller-manager.kubeconfig ${instance}/var/lib/kubernetes/
  lxc file push kube-controller-manager.service ${instance}/etc/systemd/system/
done

#Configure the Kubernetes Scheduler
cat <<EOF | tee kube-scheduler.yaml
apiVersion: kubescheduler.config.k8s.io/v1beta1
kind: KubeSchedulerConfiguration
clientConnection:
  kubeconfig: "/var/lib/kubernetes/kube-scheduler.kubeconfig"
leaderElection:
  leaderElect: true
EOF

cat <<EOF | tee kube-scheduler.service
[Unit]
Description=Kubernetes Scheduler
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-scheduler \\
  --config=/etc/kubernetes/config/kube-scheduler.yaml \\
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

for i in $(seq 1 "$number_of_master"); do
  instance=controller-${i}
  lxc file push kube-scheduler.kubeconfig ${instance}/var/lib/kubernetes/
  lxc file push kube-scheduler.service ${instance}/etc/systemd/system/
  lxc file push kube-scheduler.yaml ${instance}/etc/kubernetes/config/
done

# start control plane
for i in $(seq 1 "$number_of_master"); do
  instance=controller-${i}
  lxc exec ${instance} -- systemctl daemon-reload
  lxc exec ${instance} -- systemctl enable kube-apiserver kube-controller-manager kube-scheduler
  lxc exec ${instance} -- systemctl start kube-apiserver kube-controller-manager kube-scheduler
done
sleep 10
for i in $(seq 1 "$number_of_master"); do
  instance=controller-${i}
  lxc exec ${instance} -- systemctl --no-pager status kube-apiserver kube-controller-manager kube-scheduler
done
sudo sh -c 'echo 3 >/proc/sys/vm/drop_caches'

-#modify adminkubeconfig server address to haproxyip isned of 127.0.0.1 (172.16.0.2)
kubectl get componentstatuses --kubeconfig admin.kubeconfig
cp admin.kubeconfig ~/.kube/config
kubectl get ns --kubeconfig admin.kubeconfig

# RBAC for kublets
cat <<EOF | kubectl apply --kubeconfig admin.kubeconfig -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  annotations:
    rbac.authorization.kubernetes.io/autoupdate: "true"
  labels:
    kubernetes.io/bootstrapping: rbac-defaults
  name: system:kube-apiserver-to-kubelet
rules:
  - apiGroups:
      - ""
    resources:
      - nodes/proxy
      - nodes/stats
      - nodes/log
      - nodes/spec
      - nodes/metrics
    verbs:
      - "*"
EOF

#bind to kubernets user
cat <<EOF | kubectl apply --kubeconfig admin.kubeconfig -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: system:kube-apiserver
  namespace: ""
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: system:kube-apiserver-to-kubelet
subjects:
  - apiGroup: rbac.authorization.k8s.io
    kind: User
    name: kubernetes
EOF


# verify
curl --cacert ca.pem https://$haproxy_ip:6443/version


#worker node boorstrap
for i in $(seq 1 "$number_of_workers"); do
  instance=worker-${i}
  lxc exec ${instance} -- apt-get update
  lxc exec ${instance} -- apt-get -y install socat conntrack ipset
  lxc exec ${instance} -- mkdir -p /etc/cni/net.d
  lxc exec ${instance} -- mkdir -p /opt/cni/bin
  lxc exec ${instance} -- mkdir -p /var/lib/kubelet
  lxc exec ${instance} -- mkdir -p /var/lib/kube-proxy
  lxc exec ${instance} -- mkdir -p /var/lib/kubernetes
  lxc exec ${instance} -- mkdir -p /var/run/kubernetes
  lxc exec ${instance} -- mkdir -p /etc/containerd/
done
wget -q --show-progress --https-only --timestamping \
  https://github.com/kubernetes-sigs/cri-tools/releases/download/v1.21.0/crictl-v1.21.0-linux-amd64.tar.gz \
  https://github.com/opencontainers/runc/releases/download/v1.0.0-rc93/runc.amd64 \
  https://github.com/containernetworking/plugins/releases/download/v0.9.1/cni-plugins-linux-amd64-v0.9.1.tgz \
  https://github.com/containerd/containerd/releases/download/v1.4.4/containerd-1.4.4-linux-amd64.tar.gz \
  https://storage.googleapis.com/kubernetes-release/release/v1.22.3/bin/linux/amd64/kubectl \
  https://storage.googleapis.com/kubernetes-release/release/v1.22.3/bin/linux/amd64/kube-proxy \
  https://storage.googleapis.com/kubernetes-release/release/v1.22.3/bin/linux/amd64/kubelet

  sudo mv runc.amd64 runc
  chmod +x kubectl kube-proxy kubelet runc 
  for i in $(seq 1 "$number_of_workers"); do
    instance=worker-${i}
    lxc file push kubectl ${instance}/usr/local/bin/
    lxc file push kube-proxy ${instance}/usr/local/bin/
    lxc file push kubelet ${instance}/usr/local/bin/
    lxc file push runc ${instance}/usr/local/bin/

    lxc file push crictl-v1.21.0-linux-amd64.tar.gz ${instance}/home/ubuntu/
    lxc file push cni-plugins-linux-amd64-v0.9.1.tgz ${instance}/home/ubuntu/
    lxc file push containerd-1.4.4-linux-amd64.tar.gz ${instance}/home/ubuntu/

    lxc exec ${instance} -- tar -xvf /home/ubuntu/crictl-v1.21.0-linux-amd64.tar.gz -C /usr/local/bin/
    lxc exec ${instance} -- tar -xvf /home/ubuntu/cni-plugins-linux-amd64-v0.9.1.tgz -C /opt/cni/bin/
    lxc exec ${instance} -- tar -xvf /home/ubuntu/containerd-1.4.4-linux-amd64.tar.gz -C /
  done

# CNI setup
for instance in $(seq 1 "$number_of_workers"); do
POD_CIDR=10.1.${instance}.0/24
NODE_IP=$(lxc ls |\grep worker-${i}|awk {'print $6'})
sudo ip route add $POD_CIDR via $NODE_IP dev $hostmachine_to_k8s_network_bridge 
#  sudo ip route add 10.1.3.0/24 via 172.16.0.5 dev br0
# sudo route add -net 10.1.2.0 netmask 255.255.255.0 gw 172.16.0.6
cat <<EOF | tee 10-bridge.conf
{
    "cniVersion": "0.4.0",
    "name": "bridge",
    "type": "bridge",
    "bridge": "cnio0",
    "isGateway": true,
    "ipMasq": true,
    "ipam": {
        "type": "host-local",
        "ranges": [
          [{"subnet": "${POD_CIDR}"}]
        ],
        "routes": [{"dst": "0.0.0.0/0"}]
    }
}
EOF

lxc file push 10-bridge.conf worker-${instance}/etc/cni/net.d/
done
ip route

#  $ ip route
#default via 192.168.42.129 dev enp0s20u2 proto dhcp src 192.168.42.210 metric 100 
#10.1.1.0/24 via 172.16.0.5 dev br0 
#10.1.2.0/24 via 172.16.0.6 dev br0 
#10.1.3.0/24 via 172.16.0.5 dev br0 
#172.16.0.0/24 dev br0 proto kernel scope link src 172.16.0.1 
#192.168.42.0/24 dev enp0s20u2 proto kernel scope link src 192.168.42.210 metric 100 

cat <<EOF | tee 99-loopback.conf
{
    "cniVersion": "0.4.0",
    "type": "loopback"
}
EOF

#containered config
cat << EOF | tee config.toml
[plugins]
  [plugins.cri.containerd]
    snapshotter = "overlayfs"
    [plugins.cri.containerd.default_runtime]
      runtime_type = "io.containerd.runtime.v1.linux"
      runtime_engine = "/usr/local/bin/runc"
      runtime_root = ""
EOF

cat <<EOF | tee containerd.service
[Unit]
Description=containerd container runtime
Documentation=https://containerd.io
After=network.target

[Service]
ExecStartPre=
ExecStart=/bin/containerd
Restart=always
RestartSec=5
Delegate=yes
KillMode=process
OOMScoreAdjust=-999
LimitNOFILE=1048576
LimitNPROC=infinity
LimitCORE=infinity

[Install]
WantedBy=multi-user.target
EOF


#kubelet
for instance in $(seq 1 "$number_of_workers"); do
POD_CIDR=10.1.${instance}.0/24
cat <<EOF | tee kubelet-config.yaml
kind: KubeletConfiguration
apiVersion: kubelet.config.k8s.io/v1beta1
authentication:
  anonymous:
    enabled: false
  webhook:
    enabled: true
  x509:
    clientCAFile: "/var/lib/kubernetes/ca.pem"
authorization:
  mode: Webhook
clusterDomain: "cluster.local"
clusterDNS:
  - "10.32.0.10"
podCIDR: "${POD_CIDR}"
resolvConf: "/run/systemd/resolve/resolv.conf"
runtimeRequestTimeout: "15m"
tlsCertFile: "/var/lib/kubelet/worker-${instance}.pem"
tlsPrivateKeyFile: "/var/lib/kubelet/worker-${instance}-key.pem"
EOF

lxc file push kubelet-config.yaml worker-${instance}/var/lib/kubelet/
lxc file push worker-${instance}-key.pem  worker-${instance}/var/lib/kubelet/
lxc file push worker-${instance}.pem worker-${instance}/var/lib/kubelet/
lxc file push worker-${instance}.kubeconfig worker-${instance}/var/lib/kubelet/kubeconfig
lxc file push ca.pem worker-${instance}/var/lib/kubernetes/
done

cat <<EOF | tee kubelet.service
[Unit]
Description=Kubernetes Kubelet
Documentation=https://github.com/kubernetes/kubernetes
After=containerd.service
Requires=containerd.service

[Service]
ExecStart=/usr/local/bin/kubelet \\
  --config=/var/lib/kubelet/kubelet-config.yaml \\
  --container-runtime=remote \\
  --container-runtime-endpoint=unix:///var/run/containerd/containerd.sock \\
  --image-pull-progress-deadline=2m \\
  --kubeconfig=/var/lib/kubelet/kubeconfig \\
  --network-plugin=cni \\
  --register-node=true \\
  --fail-swap-on=false \\
  --eviction-hard='imagefs.available<1%,memory.available<1Mi,nodefs.available<1%,nodefs.inodesFree<1%' \\
  --experimental-allocatable-ignore-eviction=true \\
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF


#kubeproxy
for i in $(seq 1 "$number_of_workers"); do
  instance=worker-${i}
  lxc file push kube-proxy.kubeconfig ${instance}/var/lib/kube-proxy/kubeconfig
done

cat <<EOF | tee kube-proxy-config.yaml
kind: KubeProxyConfiguration
apiVersion: kubeproxy.config.k8s.io/v1alpha1
clientConnection:
  kubeconfig: "/var/lib/kube-proxy/kubeconfig"
mode: "iptables"
clusterCIDR: "10.200.0.0/16"
conntrack:
  max: 0
  maxPerCore: 0
EOF

cat <<EOF | tee kube-proxy.service
[Unit]
Description=Kubernetes Kube Proxy
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-proxy \\
  --config=/var/lib/kube-proxy/kube-proxy-config.yaml
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF


for i in $(seq 1 "$number_of_workers"); do
    instance=worker-${i}
    lxc file push 99-loopback.conf ${instance}/etc/cni/net.d/
    lxc file push config.toml ${instance}/etc/containerd/
    lxc file push containerd.service ${instance}/etc/systemd/system/
    lxc file push kubelet.service ${instance}/etc/systemd/system/
    lxc file push kube-proxy-config.yaml ${instance}/var/lib/kube-proxy/
    lxc file push kube-proxy.service ${instance}/etc/systemd/system/
done

#start wokers
for i in $(seq 1 "$number_of_workers"); do
  instance=worker-${i}
  lxc exec ${instance} -- systemctl daemon-reload
  lxc exec ${instance} -- systemctl enable containerd kubelet kube-proxy
  lxc exec ${instance} -- systemctl start containerd kubelet kube-proxy
done
sleep 10
for i in $(seq 1 "$number_of_workers"); do
  instance=worker-${i}
  lxc exec ${instance} -- systemctl --no-pager status containerd kubelet kube-proxy
done
sudo sh -c 'echo 3 >/proc/sys/vm/drop_caches'
kubectl get nodes
# if node is taineted
kubectl taint nodes <node-name> node.kubernetes.io/disk-pressure-

```
#ADD ons
```
-# archlinux wierd groupc probblem in worker nodes
# from hostmachine (Arch):
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

cat <<EOF | tee coredns.yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: coredns
  namespace: kube-system
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  labels:
    kubernetes.io/bootstrapping: rbac-defaults
  name: system:coredns
rules:
- apiGroups:
  - ""
  resources:
  - endpoints
  - services
  - pods
  - namespaces
  verbs:
  - list
  - watch
- apiGroups:
  - ""
  resources:
  - nodes
  verbs:
  - get
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  annotations:
    rbac.authorization.kubernetes.io/autoupdate: "true"
  labels:
    kubernetes.io/bootstrapping: rbac-defaults
  name: system:coredns
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: system:coredns
subjects:
- kind: ServiceAccount
  name: coredns
  namespace: kube-system
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: coredns
  namespace: kube-system
data:
  Corefile: |
    .:53 {
        errors
        health
        ready
        kubernetes cluster.local in-addr.arpa ip6.arpa {
          pods insecure
          fallthrough in-addr.arpa ip6.arpa
        }
        prometheus :9153
        cache 30
        loop
        reload
        loadbalance
    }
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: coredns
  namespace: kube-system
  labels:
    k8s-app: kube-dns
    kubernetes.io/name: "CoreDNS"
spec:
  replicas: 2
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 1
  selector:
    matchLabels:
      k8s-app: kube-dns
  template:
    metadata:
      labels:
        k8s-app: kube-dns
    spec:
      priorityClassName: system-cluster-critical
      serviceAccountName: coredns
      tolerations:
        - key: "CriticalAddonsOnly"
          operator: "Exists"
      nodeSelector:
        beta.kubernetes.io/os: linux
      containers:
      - name: coredns
        image: coredns/coredns:1.8.0
        imagePullPolicy: IfNotPresent
        resources:
          limits:
            memory: 170Mi
          requests:
            cpu: 100m
            memory: 70Mi
        args: [ "-conf", "/etc/coredns/Corefile" ]
        volumeMounts:
        - name: config-volume
          mountPath: /etc/coredns
          readOnly: true
        ports:
        - containerPort: 53
          name: dns
          protocol: UDP
        - containerPort: 53
          name: dns-tcp
          protocol: TCP
        - containerPort: 9153
          name: metrics
          protocol: TCP
        securityContext:
          allowPrivilegeEscalation: false
          capabilities:
            add:
            - NET_BIND_SERVICE
            drop:
            - all
          readOnlyRootFilesystem: true
        livenessProbe:
          httpGet:
            path: /health
            port: 8080
            scheme: HTTP
          initialDelaySeconds: 60
          timeoutSeconds: 5
          successThreshold: 1
          failureThreshold: 5
        readinessProbe:
          httpGet:
            path: /ready
            port: 8181
            scheme: HTTP
      dnsPolicy: Default
      volumes:
        - name: config-volume
          configMap:
            name: coredns
            items:
            - key: Corefile
              path: Corefile
---
apiVersion: v1
kind: Service
metadata:
  name: kube-dns
  namespace: kube-system
  annotations:
    prometheus.io/port: "9153"
    prometheus.io/scrape: "true"
  labels:
    k8s-app: kube-dns
    kubernetes.io/cluster-service: "true"
    kubernetes.io/name: "CoreDNS"
spec:
  selector:
    k8s-app: kube-dns
  clusterIP: 10.32.0.10
  ports:
  - name: dns
    port: 53
    protocol: UDP
  - name: dns-tcp
    port: 53
    protocol: TCP
  - name: metrics
    port: 9153
    protocol: TCP
EOF
kubectl apply -f coredns-1.7.0.yaml
sleep 20
kubectl get pods -n kube-system
```
# verifications & smoke tests
```
kubectl run busybox --image=busybox:1.28 --command -- sleep 3600
kubectl get pods -l run=busybox
POD_NAME=$(kubectl get pods -l run=busybox -o jsonpath="{.items[0].metadata.name}")
kubectl exec -ti $POD_NAME -- nslookup kubernetes

#Data Encryption
kubectl create secret generic kubernetes-the-hard-way   --from-literal="mykey=mydata"
lxc exec controller-0 -- sudo ETCDCTL_API=3 etcdctl get \
   --endpoints=https://127.0.0.1:2379 \
   --cacert=/etc/etcd/ca.pem \
   --cert=/etc/etcd/kubernetes.pem \
   --key=/etc/etcd/kubernetes-key.pem\
   /registry/secrets/default/kubernetes-the-hard-way | hexdump -C

#Deployments
kubectl run nginx --image=nginx
kubectl get pods -l run=nginx
POD_NAME=$(kubectl get pods -l run=nginx -o jsonpath="{.items[0].metadata.name}")
#portforward
kubectl port-forward $POD_NAME 8080:80
curl --head http://127.0.0.1:8080
#logs
kubectl logs $POD_NAME
#exec
kubectl exec -ti $POD_NAME -- nginx -v
#services
kubectl expose pod nginx --port 80 --type NodePort
NODE_PORT=$(kubectl get svc nginx    --output=jsonpath='{range .spec.ports[0]}{.nodePort}')
EXTERNAL_IP=NODE'sIP where pod running
curl -I http://${EXTERNAL_IP}:${NODE_PORT}


#storage
check here
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
sudo systemctl stop lxc lxd lxcfs
pacman -Rnc lxc lxd lxcfs
sudo umount /var/lib/lxd/shmounts
sudo umount /var/lib/lxd/devlxd
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
sudo \rm -rf /var/lib/lxc /var/lib/lxd /var/lib/lxcfs/
```
inspired from 
https://github.com/rgmorales/kubernetes-the-hard-way-on-lxd
and
https://github.com/kelseyhightower/kubernetes-the-hard-way

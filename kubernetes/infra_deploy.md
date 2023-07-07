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

cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -hostname=worker-${i},${EXTERNAL_IP},${NODE_IP} -profile=kubernetes worker-${i}-csr.json | cfssljson -bare worker-${i}
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
list_of_masterips=`lxc ls|grep controller|awk {'print $6'}|tr '\n' ','|paste -sd ','`
cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -hostname=$list_of_masterips${KUBERNETES_PUBLIC_ADDRESS},127.0.0.1,kubernetes.default -profile=kubernetes kubernetes-csr.json | cfssljson -bare kubernetes


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
lxc exec ${ETCD_NAME} -- systemctl status etcd
done

# Etcd verification
for i in $(seq 1 "$number_of_master"); do
lxc exec controller-${i} -- bash -c "ETCDCTL_API=3 /usr/local/bin/etcdctl member list --endpoints=https://127.0.0.1:2379 --cacert=/etc/etcd/ca.pem --cert=/etc/etcd/kubernetes.pem --key=/etc/etcd/kubernetes-key.pem"
done

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
apiVersion: kubescheduler.config.k8s.io/v1alpha1
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
  lxc exec ${instance} -- systemctl status kube-apiserver kube-controller-manager kube-scheduler
done

kubectl get componentstatuses --kubeconfig admin.kubeconfig

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

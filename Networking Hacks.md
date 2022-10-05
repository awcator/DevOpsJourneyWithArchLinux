### Expose local file system over the internet
you can expose your local file system over the internet using the commands as follows:
```diff 
yay -S ngrok
ngrok config add-authtoken <TOKEN_HERE>
or
ngrok add-authtoken <TOKEN_HER>
cd /path/to/expose
python2 -m SimpleHTTPServer 8000
ngrok http 8000
#now ngrok returns url that can be accessed over the internet, access it using curl or browser
eg.
curl http://6777-49-37-189-74.ngrok.io/myfile.txt
```
### Use SSH as tcp proxyserver to connect Machine2 from localhost via machine1(deemed to be Proxyserver)
```diff
ssh -i ~/.ssh/id_rsa ubuntu@bastion.awcator.hsop.io -L localhost:1234:172.20.59.133:3389
ssh -i ~/.ssh/id_rsa ubuntu@Machine1 -L localhost:1234:Machine2:PORT

curl localhost:1234   #imples === curl machine2:3389

localMachibe ========Machine1 =========Machine 2
```

### Establish SSL connnectivity between two non SSL servers
[Check this](https://github.com/awcator/DevOpsJourneyWithArchLinux/blob/master/prometheus.md#mutal-sslconnectivity-between-non-ssl-premethus-and-non-ssl-nodeexportyer)

### Client Cert Auth
[Check this](https://github.com/awcator/DevOpsJourneyWithArchLinux/blob/master/ngnix.md#client-certificate-autherization)

### Send raw TCP/IP Packets into the network
[Check this ](https://github.com/awcator/DevOpsJourneyWithArchLinux/blob/master/wireshark/setup.md#to-send-raw-packets-into-the-network-this-can-be-used-to-test-tcp-behaviour)

### Remove all privilaged PORTS (Allow non root user to listen on 80 etc )
```
#save configuration permanently
echo 'net.ipv4.ip_unprivileged_port_start=0' > /etc/sysctl.d/50-unprivileged-ports.conf
#apply conf
sysctl --system
```
### Route all incomming requests on port 80 (internet facing) to service running on port 3000
```diff
# basically service running port 3000 consumes whatever is fed on port 80
iptables -t nat -I PREROUTING -p tcp --dport 80 -j REDIRECT --to-ports 3000
```

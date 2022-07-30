**HaProxy Installation**
```
pacman -Syu
pacman -S haproxy
```

**Runtime DNS resolving**
THis method can be used insted of hardcoded IP in the haproxys-backend servers.
By using custom resolvers and health checks we can make it Runtime resolving.
<br>
Read :
<br>
[Haproxy health checks:]([url](https://www.haproxy.com/documentation/hapee/latest/load-balancing/health-checking/active-health-checks/)) https://www.haproxy.com/documentation/hapee/latest/load-balancing/health-checking/active-health-checks/
[Haproxy Resolvers:]([url](https://www.haproxy.com/documentation/hapee/latest/configuration/config-sections/resolvers/#)) https://www.haproxy.com/documentation/hapee/latest/configuration/config-sections/resolvers/#

Create the resovlers as follows (in /etc/haproxy/haproxy.cfg):
```
resolvers myresolvers
    nameserver dns1 192.168.50.30:53 #any custom dns resolver
    nameserver dns2 192.168.50.30:53 #any custom dns resovler
    accepted_payload_size 8192 # allow larger DNS payloads
```
Create the backend as follows:
```
backend webservers
    balance roundrobin
    server-template myservers 3 subdomain.awcator:443 check resolvers myresolvers init-addr none
    # THis will templatize 3 servers as folllows
    # server myservers0 192.168.1.2:443 check resolvers myresolvers init-addr none
    # server myservers1 192.168.1.1:443 check resolvers myresolvers init-addr none
    # server myservers2 192.168.1.3:443 check resolvers myresolvers init-addr none
```

vertify the resolved backend
first varify the dns resolving locally,
```
nslookup subdomain.awcator
dig subdomain.awcator  #default uses /etc/resolver file
dig @192.168.50.30 -p 53 A subdomain.awcator  #if you want to use custom resolver
```
Varify how haproxy constructs backend from templatized backend:
create admin acces socket. It will used to view and query/modify the haproxy's variables in memory
```
global
  daemon
  chroot /var/lib/haproxy
  user haproxy
  group haproxy
  stats socket ipv4@127.0.0.1:9999 level admin
  stats socket /run/haproxy/admin.sock mode 660 level admin expose-fd listeners
  stats timeout 30s
```

Now query the port using socat or nc
```
echo "show servers state webservers" | socat stdio tcp4-connect:127.0.0.1:9999
#where webservers is your backend name
echo "help" | socat stdio tcp4-connect:127.0.0.1:9999     #for more usage
```
This will list the acuall internal backend that will be loadblanced   

<br><br>
**Self Signed Certificates and SSL termination at Haproxy**

```
# Generate a unique private key (KEY)
sudo openssl genrsa -out mydomain.key 2048

# Generating a Certificate Signing Request (CSR)
sudo openssl req -new -key mydomain.key -out mydomain.csr

# Creating a Self-Signed Certificate (CRT)
openssl x509 -req -days 365 -in mydomain.csr -signkey mydomain.key -out mydomain.crt

# Append KEY and CRT to mydomain.pem
sudo bash -c 'cat mydomain.key mydomain.crt >> /etc/ssl/private/mydomain.pem'

# Specify PEM in haproxy config
sudo vim /etc/haproxy/haproxy.cfg
listen haproxy
  bind 0.0.0.0:443 ssl crt /etc/ssl/private/mydomain.pem
```

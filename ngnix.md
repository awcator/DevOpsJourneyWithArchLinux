# Ngnix Reverse Proxy
## !Contents
* Protect Backend server with HTTPAuth
* SSL Termination/Protect unprotected server with SSL 
## Protect Backend server with HTTPAuth
```diff
add Auth config as follows in /etc/ngnix/ngnix.conf
inside http.server.location (where listening on 80) put
auth_basic "MyServerCreds";
auth_basic_user_file /etc/nginx/.htpasswd;

Add the user into hapasswd as follows
sudo htpasswd -c /etc/nginx/.htpasswd awcatorUser1
Now login to the site using creds
-or
curl -u httpUSERNAME:httpUserPassword http://awcator
```
## SSL Termination/Protect unprotected server with SSL 
Client ---connects--- > UnProtectedServer <br>
TLS Client <------connects---> TLS NgnixReverseProxyServer <----connects----->UnProtectedServer
```diff
!install
pacman -S nginx openssl

!generate self signed certs for the domain awcator. Replace awcator with yourdomain.com
sudo mkdir -p /etc/ssl/certs/
openssl req -x509 -newkey rsa:4096 -keyout key.pem -out cert.pem -days 365 -subj '/CN=awcator' -nodes
mv key.pem /etc/ssl/private/nginx.pem
chmod 600 /etc/ssl/private/nginx.pem
mv cert.pem /etc/ssl/certs/nginx.pem

!Protect Promethetus server with SSL using Ngnix as ProxyServer
Add the folowing contetns in http.server.location (where listenging on 443)as follows
server {
  listen 443;
  ssl    on;
  ssl_certificate /etc/ssl/certs/nginx.pem;
  ssl_certificate_key /etc/ssl/private/nginx.pem;
  location / {
    proxy_pass http://mydestinationServer:mydestinationPort/;
    #auth_basic "Prometheus";
    #auth_basic_user_file /etc/nginx/.htpasswd;
  }
}

//Or check /configs/etc/ngnix/ngnix.conf for more info

```

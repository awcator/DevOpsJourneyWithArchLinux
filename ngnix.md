# Ngnix Reverse Proxy
## !Contents
* Protect Backend server with HTTPAuth
* SSL Termination/Protect unprotected server with SSL 
* Client Certificate Autherization 
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

//Or check repo/configs/etc/ngnix/ngnix.conf for more info

```
## Client Certificate Autherization 
```
Create CA certs (Self Signed)
#awcator is ca doamin
openssl genrsa -out ca.key 4096
chmod 400 ca.key
openssl req -new -x509 -sha256 -days 3650 -key ca.key -out ca.crt -subj "/CN=awcator"
chmod 644 ca.crt

Client Certficate (this will be handed to clients)
#bwcator is client ID or domain
openssl genrsa -out client.key 2048
openssl req -new -key client.key -out client.csr -subj "/CN=bwcator"
openssl x509 -req -days 365 -sha256 -in client.csr -CAcreateserial  -CA ca.crt -CAkey ca.key
openssl x509 -req -days 365 -sha256 -in client.csr -CA ca.crt -CAkey ca.key -set_serial 2 -out client.crt

#cwcator is server ID or domain
Server Certificate (this will be kept in ngnix config to auth clint certs)
openssl genrsa -out target.key 2048
chmod 400 target.key
openssl req -new -key target.key -sha256 -out target.csr -subj "/CN=cwcator"
openssl x509 -req -days 365 -sha256 -in target.csr -CA ca.crt -CAkey ca.key -set_serial 1 -out target.crt -extensions v3_req 
chmod 444 target.crt

Configure ngnix config as follows:
    server {                                   
        listen       8000 ssl;    
        server_name  awcator  alias  another.alias;                               
        ssl_certificate /tmp/target.crt;                              
        ssl_certificate_key /tmp/target.key;                            
        ssl_client_certificate /tmp/ca.crt;    
        ssl_verify_client on;              
        location / {    
            #root   html;    
            #index  index.html index.htm;    
            root   /usr/share/nginx/html;    
            index  index.html index.htm;    
                              
        }    
    }  
curl https://awcator:8000/ -k --key client.key --cert client.crt 
```

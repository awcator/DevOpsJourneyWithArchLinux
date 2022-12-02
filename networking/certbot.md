# certbot usage:
Get signed certificates
```diff
sudo certbot certonly --standalone --preferred-challenges http -d awcator.in
sudo ufw allow 80
# The --preferred-challenges option instructs Certbot to use port 80 or port 443.
# If you’re using port 80, you want --preferred-challenges http. For port 443 it would be --preferred-challenges tls-sni

#Certs are locaed at /etc/letsencrypt/live/
```
Renew
```
sudo certbot renew --dry-run
```
Configure Apache with SSL certs from certbot
```
apt-get update
apt-get install apache2 openssl

a2enmod ssl
a2enmod rewrite

systemctl restart apache2
#add these lines in /etc/apache2/sites-enabled

<VirtualHost *:443>
    ServerName www.awcator.in
    SSLEngine on
    SSLCertificateFile "/etc/letsencrypt/live/awcator.in/cert.pem"
    SSLCertificateKeyFile "/etc/letsencrypt/live/awcator.in/privkey.pem"
</VirtualHost>
systemctl restart apache2
```

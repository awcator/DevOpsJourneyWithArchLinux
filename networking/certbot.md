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

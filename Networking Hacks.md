**Expose local file system over the internet**
<br>
you can expose your local file system over the internet using the commands as follows:
```
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
**Use SSH as tcp proxyserver to connect Machine2 from localhost via machine1(deemed to be Proxyserver)**
```
ssh -i ~/.ssh/id_rsa ubuntu@bastion.awcator.hsop.io -L localhost:1234:172.20.59.133:3389
ssh -i ~/.ssh/id_rsa ubuntu@Machine1 -L localhost:1234:Machine2:PORT

curl localhost:1234   #imples === curl machine2:3389

localMachibe ========Machine1 =========Machine 2
```

**Establish SSL connnectivity between two non SSL servers**
[Check this](https://github.com/awcator/DevOpsJourneyWithArchLinux/blob/master/prometheus.md#mutal-sslconnectivity-between-non-ssl-premethus-and-non-ssl-nodeexportyer)

**Client Cert Auth**
[Check this](https://github.com/awcator/DevOpsJourneyWithArchLinux/blob/master/ngnix.md#client-certificate-autherization)

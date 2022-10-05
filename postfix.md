https://www.mailgun.com/blog/email/which-smtp-port-understanding-ports-25-465-587/#subchapter-2 <br>
https://support.google.com/mail/answer/81126#ip <br>
https://dnschecker.org/
<br>
I have used AWS Route53 to create MX and A records. PTR record was created inside the another VPS provider (NOn AWS) 
<br>
# PART 1 (Configuring SMTP server) (Here I have used Postfix as MTA)
##  openssl to query https
```
openssl s_client -starttls smtp -crlf -connect smtp.mailgun.org:587
openssl s_client -connect api.mailgun.net:443
```

## Create A record:
	mail.awcator.in
```	
$ nslookup mail.awcator.in
Server:         8.8.8.8
Address:        8.8.8.8#53

Non-authoritative answer:
Name:   mail.awcator.in
Address: 103.13.112.119
```

# Create MX record
```
{ 07:43:45 } [ Awcator ] - [ /home/Awcator ]
  $ dig MX mail.awcator.in

; <<>> DiG 9.18.6 <<>> MX mail.awcator.in
;; global options: +cmd
;; Got answer:
;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 37069
;; flags: qr rd ra; QUERY: 1, ANSWER: 1, AUTHORITY: 0, ADDITIONAL: 1

;; OPT PSEUDOSECTION:
; EDNS: version: 0, flags:; udp: 512
;; QUESTION SECTION:
;mail.awcator.in.               IN      MX

;; ANSWER SECTION:
mail.awcator.in.        300     IN      MX      10 mail.awcator.in.

;; Query time: 46 msec
;; SERVER: 8.8.8.8#53(8.8.8.8) (UDP)
;; WHEN: Tue Oct 04 19:43:47 IST 2022
;; MSG SIZE  rcvd: 60
```

# TEST SETUP 1
```
nc -lnvp 25
#send mail to awcator@mail.awcator.in
# If all the DNS records are working  fine then you will hit connection on your nc (TCP server on port 25)
```
## Install postfix
```
sudo apt-get install postfix postfix-mysql mariadb-server
# Choose: Internet wide instllation
# enter your FQDN for the mail the domian name

sudo apt-get install mailutils
```

## Dummy user setup
```
sudo useradd -m -s /bin/bash awcator
# where awcator is the username at domain mail.awcator.in
# Which means awcator@mail.awcator.in
sudo passwd awcator

#go to some mail client (Eg.Gmail) and send mail to him 
```

# Configure Postfix to receive email from the internet (Config)
```
sudo postconf -e "mydestination =  $myhostname, mail.awcator.in, localhost.awcator.in, , localhost"
#assume 192.168.1.0/24 is your local LAN
sudo postconf -e "mynetworks = 127.0.0.0/8, 192.168.1.0/24"
#Configure Postfix to receive mail on all interfaces, which includes the internet:
sudo postconf -e "inet_interfaces = all"
sudo service postfix restart
```

## Self mail
```
#beging with > means you have to enter the line insde telnet (wihtout >)
# example 
>hello

# type hello inside telnet

telnet mail.awcator.in 25
>ehlo mail.awcator.in
>mail from: root@mail.awcator.in
>rcpt to: awcator@mail.awcator.in
>data
>Subject: Re: Your First mail from root
>
>Hey there, I'm using mail.awcator.in
>.
>quit
```

## Verify Incomming mails
```
#login as awcator (Dummy User)
su - awcator

# reset the terminal 
reset
# tput rmcup
mail

"/home/awcator/mbox": 2 messages 1 unread
     1 Dev                Tue Oct  4 17:30  62/2937  Mukalri
>U   2 Dev                Tue Oct  4 17:29  60/2900  Test

#q to quit the mail

# mail -f* (to list all mails)
# or cat ~/mbox
```

# Configure Postfix to use Maildir-style mailboxes:
if mails are not in home dir then, to move to home dir you can do 
```
sudo postconf -e "home_mailbox = Maildir/"
sudo /etc/init.d/postfix restart
su - awcator
MAIL=/home/awcator/Maildir
mail

```


##  Send mail to GMAIL

~~Sending to 10minutesmail works gmail does strict checking and failing currently~~
<br>
~~mail~~
<br>
~~> mail~~
<br>
~~type your mail and ControlD it~~
<br>
~~cat /var/log/mail.log  shows failure because:~~
<br>
~~The IP address sending this message does not have a 550-5.7.25 PTR record setup, or the corresponding forward DNS entry does not 550-5.7.25 point to the sending IP. As a policy, Gmail does not accept messages 550-5.7.25 from IPs with missing PTR records. Please visit 550-5.7.25 https://support.google.com/mail/answer/81126#ip-practices for more 550 5.7.25 information. pg14-20020a17090b1e0e00b0020297249987si1158190pjb.124 - gsmtp (in reply to end of DATA command))~~
<br>
~~Not sure what exactly the issue (I'll update if I get to know about it in future)~~
<br>

It was solved by createing Reverse DNS record (rDNS) and pointing to your host name
```
  $ dig -x 103.13.112.119

; <<>> DiG 9.18.6 <<>> -x 103.13.112.119
;; global options: +cmd
;; Got answer:
;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 52664
;; flags: qr rd ra ad; QUERY: 1, ANSWER: 1, AUTHORITY: 0, ADDITIONAL: 0

;; QUESTION SECTION:
;119.112.13.103.in-addr.arpa.   IN      PTR

;; ANSWER SECTION:
119.112.13.103.in-addr.arpa. 13722 IN   PTR     mail.awcator.in.

;; Query time: 0 msec
;; SERVER: 192.168.42.129#53(192.168.42.129) (UDP)
;; WHEN: Wed Oct 05 18:48:26 IST 2022
;; MSG SIZE  rcvd: 74

#For Ipv4 support only. Since we have added rDns record for ipv4
postconf inet_protocols
sudo postconf -e "inet_protocols = ipv4"
#replace all to only ipv4
sudo systemctl restart postfix

# request cloudproiver for PTR record
# use https://dnschecker.org/ to track DNS record changes

#and the send mail to gmail it should be sent
```

# Part 2: Configuring IMAP/POP3 server

https://www.mailgun.com/blog/email/which-smtp-port-understanding-ports-25-465-587/#subchapter-2 <br>
https://support.google.com/mail/answer/81126#ip <br>
https://dnschecker.org/
<br>
I have used AWS Route53 to create MX and A records. PTR record was created inside the another VPS provider (NOn AWS) 
<br>
# Part 0: Practise Telnet and other mail clients on working SMTP server like GMAIL before crateing your own
[Telnet Way of sending mails ](https://github.com/awcator/DevOpsJourneyWithArchLinux/blob/master/telnet/smtpDemo.md#telnet-way-to-send-mails) <br>
[SSMTP client way of sending mails](https://github.com/awcator/DevOpsJourneyWithArchLinux/blob/master/superhandy.md#send-mail-from-your-smtp-server) <br>
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
# Part 2: Admin Interface (postfixadmin)

##  LMAP setup

### php config
```
apt install php libapache2-mod-php7.4 php-common php7.4 php7.4-cli php7.4-common php7.4-json php7.4-opcache php7.4-readline 
#restart apache to support php
systemctl restart apache2
```

### mariadb config
```dif
apt-get -y install php7.4-mariadb
apt install  mycli/focal mariadb-client/focal-updates mariadb-server/focal-updates postfix-mysql mariadb-server
mysql_secure_installation
Enter current password for root (enter for none): <== Your Root Password
Set root password? [Y/n] <== y (yes)
New password: <== Here you have to enter your new password
Re-enter new password: <== Confirm Password
Remove anonymous users? [Y/n] <== Yes, delete
Disallow root login remotely? [Y/n] <==Yes, prohibit
Remove test database and access to it? [Y/n] <== Yes, we do not need the test table
Reload privilege tables now? [Y/n] <== Yes, reload

mysql -uroot -ps3cr3t
CREATE DATABASE postfix;
CREATE USER 'postfix'@'localhost' IDENTIFIED BY 'postfixapppassowrd';
GRANT ALL PRIVILEGES ON `postfix` . * TO 'postfix'@'localhost';
FLUSH PRIVILEGES;
```

### back to installation

```diff
# https://github.com/postfixadmin/postfixadmin/blob/master/INSTALL.TXT
$ cd /srv/
$ wget -O postfixadmin.tgz https://github.com/postfixadmin/postfixadmin/archive/postfixadmin-3.3.10.tar.gz
$ tar -zxvf postfixadmin.tgz
$ mv postfixadmin-postfixadmin-3.3 postfixadmin
ln -s /srv/postfixadmin/public /var/www/html/postfixadmin
mkdir -p /srv/postfixadmin/templates_c
chown -R www-data /srv/postfixadmin/templates_c
php -r 'echo password_hash("password", PASSWORD_DEFAULT);'
#$2y$10$W3AOkOj16uxBGCSMOwg2OOq2jJbq2SEvF9l/PExpHSF.EPOdDKAwq
  
#create a file as follows
root@mail:/srv/postfixadmin# cat config.local.php 
<?php
$CONF['database_type'] = 'mysqli';
$CONF['database_host'] = 'mail.awcator.in';
$CONF['database_user'] = 'postfix';
$CONF['database_password'] ='postfixapppassowrd';
$CONF['database_name'] = 'postfix';
$CONF['encrypt'] = 'md5crypt';
$CONF['configured'] = true;
$CONF['setup_password'] = '$2y$10$W3AOkOj16uxBGCSMOwg2OOq2jJbq2SEvF9l/PExpHSF.EPOdDKAwq';
?>

# Add the following lines php.ini in /etc/php/7.4/

display_startup_errors
    On

error_reporting
    E_ALL

``` 

Below is a sample excerpt from php.ini file which contains the configuration of mbstring variables.
```diff
[mbstring]
mbstring.language = all
mbstring.internal_encoding = UTF-8
mbstring.http_input = auto
mbstring.http_output = UTF-8
mbstring.encoding_translation = On
mbstring.detect_order = UTF-8
mbstring.substitute_character = none;
mbstring.func_overload = 0
mbstring.strict_encoding = Off

sudo apt-get install php-mbstring

visit
http://mail.awcator.in/postfixadmin/setup.php
```
if  you followed as previous steps:
<br>
your setup_password is "password"
<br>
use that password and create a super admin user <br>
Create a admin user as follows:<br>
>setUp_password: password<br>
>Admin: admin@mail.awcator.in<br>
>Password: hStybCBgW36tJc7<br>
<br>
A mysql entry should be added as follows if everything worked

```
mysql -p -u root
use postfix
select * from admin;

| username              | password                           | created             | modified            | active | superadmin | phone | email_other | token | token_validity      |
+-----------------------+------------------------------------+---------------------+---------------------+--------+------------+-------+-------------+-------+---------------------+
| admin@mail.awcator.in | $1$c9809462$B7qJzNa3EBpWVxqAwERh7. | 2022-10-05 17:47:33 | 2022-10-05 17:47:33 |      1 |          1 |       |             |       | 2022-10-05 17:47:32 |
+-----------------------+------------------------------------+---------------------+---------------------+--------+------------+-------+-------------+-------+---------------------+
1 row in set (0.001 sec)


```
Now login to the postfix admin page using admin@mail.awcator.in<br>
http://mail.awcator.in/postfixadmin/login.php<br>

## Verification and end of part2
#test the admin user by sending a mail  to your gmail account. Check SPAM sections too to see the mails<br>
http://mail.awcator.in/postfixadmin/sendmail.php<br>



# PART 3 : Configure PostFix to link users from mysql database
https://github.com/awcator/DevOpsJourneyWithArchLinux/blob/master/postfix.md <br>
https://wiki.gentoo.org/wiki/Complete_Virtual_Mail_Server/Postfix_to_Database <br>
https://gist.github.com/aryklein/51cc0d94b2693120abd4 <br>
https://github.com/postfixadmin/postfixadmin/blob/master/DOCUMENTS/POSTFIX_CONF.txt <br>
https://github.com/postfixadmin/postfixadmin/blob/master/DOCUMENTS/Postfix-Dovecot-Postgresql-Example.md <br>

Create Domain List
Create MailBox list for the domain
Create MailBox list for the domain x2
Create alias for the domain using postfixadmin

mkdir /etc/postfix/mysql

create a file as follows:

```
==> virtual_mailbox_domains.cf <==
user            = postfix
password        = postfixapppassowrd
dbname          = postfix
hosts          = unix:/var/run/mysqld/mysqld.sock
query           = SELECT domain FROM domain WHERE domain = '%s' AND backupmx = '0' AND active = '1';

==> virtual_mailbox_maps.cf <==
user            = postfix
password        = postfixapppassowrd
dbname          = postfix
#hosts          = localhost
hosts           = unix:/var/run/mysqld/mysqld.sock
query           = SELECT maildir FROM mailbox WHERE username='%s' AND active = '1';

==> virtual_mailbox_transport.cf <==
user            = postfix
password        = postfixapppassowrd
dbname          = postfix
hosts          = unix:/var/run/mysqld/mysqld.sock
query = SELECT REPLACE(transport, 'virtual', ':') AS transport FROM domain WHERE domain='%s' AND active = '1'


```
Remove all from "mydestination" in /etc/postfix/main.cf and make it like
```
mydestination = localhost
# This is because to diffrentaiate local table and virtual table.
# since mail.awcator.in stays in virtual transportor
```

Add following lines to /etc/postfix/main.cf
```
virtual_mailbox_domains = mysql:/etc/postfix/mysql/virtual_mailbox_domains.cf
virtual_transport = virtual
virtual_mailbox_base = /var/mail/vmail
virtual_mailbox_maps = mysql:/etc/postfix/mysql/virtual_mailbox_maps.cf
virtual_uid_maps = static:8
virtual_gid_maps = static:8
virtual_minimum_uid = 8

mailbox_size_limit = 10
mydestination = localhost
```
Setup appropritate permissions
```
chown postfix:postfix -R /etc/postfix/mysql/
find /etc/postfix/ -name "*.cf" -exec chmod -c 640 '{}' \+
```
Setup Approppriate perssmison for our mysqluser (I used as root clone)
```
GRANT ALL ON *.* to postfix@'%' IDENTIFIED BY 'postfixapppassowrd';
GRANT ALL ON *.* to postfix@localhost IDENTIFIED BY 'postfixapppassowrd';
```
Mount mysql socket to chroot jailed mail server
```
$ pid = `ps -ef | grep postfix | grep pickup | awk '{print $2}'`
$ sudo ls -l /proc/$pid/root
It will give you something like this:

$ sudo ls -l /proc/3233/root
lrwxrwxrwx 1 root root 0 Jun  1 15:37 /proc/3233/root -> /var/spool/postfix
To solve this issue, you have to mount the database socket path inside the Postfix jail


mount -o bind /var/run/mysqld /var/spool/postfix/var/run/mysqld
```



enable logging with MYSQL, edit /etc/mysql/my.cnf with <br>
it helped in  debugging postfix's quering mysql
```
[mysqld]
general_log = on
general_log_file=/var/log/mysql/mysql.log
```

## vertification
send mail to mysql user created from postfix admin page and confrim mails at location /var/mail/vmail/mail.awcator.in/user .

# PART 4: DoveCot as IMAP
https://doc.dovecot.org/configuration_manual/config_file/config_variables/
https://github.com/postfixadmin/postfixadmin/blob/master/DOCUMENTS/Postfix-Dovecot-Postgresql-Example.md
https://wiki.archlinux.org/title/Virtual_user_mail_system_with_Postfix,_Dovecot_and_Roundcube#Dovecot

~~create a same groups so dovecot can read postfixs mail~~ <br>
~~rm -rf vmail/ <br>
sudo groupadd mailers <br>
sudo usermod -a -G mailers postfix <br>
sudo usermod -a -G mailers dovecot<br>
sudo chgrp -R mailers /var/mail/vmail/<br> 
sudo chmod -R 770 /var/mail/vmail/~~<br>


~~chgrp -R mailers vmail/<br>
chmod -R 2777 vmail/<br>
Notedown the group id of mailers == for me 1003~~

For memory settings put this in  /etc/postfix/main.cf

```
mailbox_size_limit = 0
message_size_limit = 0
virtual_mailbox_limit = 0
# 0 signifies unlimited
``` 
Previosuly we setuped virtual users. to test local users mail at localhost domain
```
echo "bwcatopr " |mail bwcator@localhost
where bwcator is posix account
```

Install Dovecot as IMAP server
~~apt-get install dovecot-mysql dovecot-lmtpd  dovecot-imapd dovecot-managesieved dovecot-sqlite~~
```
apt-get install dovecot-mysql   dovecot-imapd

systemctl status dovecot
systemctl start dovecot

#port 993=IMAPS
#port 143=IMAP

check /usr/share/dovecot/protocols.d/ to see modules it is loaded or 
protocols = imap   in  /etc/dovecot/dovecot.conf
```
Configure Dovecot for IMAP
```
# put this in /etc/dovecot/dovecot.conf

protocols = imap
auth_mechanisms = plain
passdb {
    driver = sql
    args = /etc/dovecot/dovecot-sql.conf
}
userdb {
    driver = sql
    args = /etc/dovecot/dovecot-sql.conf
}
 
service auth {
    unix_listener auth-client {
        group = postfix
        mode = 0660
        user = postfix
    }
    user = root
}

mail_home = /var/mail/vmail/%d/%n
auth_verbose=yes
auth_debug=yes 
auth_debug_passwords=yes
mail_debug=yes 
log_path = /var/log/dovecot.log
disable_plaintext_auth = no
mail_location = maildir:~


# create a dovecto-sql conf in same directory as :

root@mail:/etc/dovecot# cat /etc/dovecot/dovecot-sql.conf
driver = mysql
connect = host=localhost dbname=postfix user=postfix password=postfixapppassowrd
# It is highly recommended to not use deprecated MD5-CRYPT. Read more at http://wiki2.dovecot.org/Authentication/PasswordSchemes
default_pass_scheme = MD5-CRYPT
# Get the mailbox
user_query = SELECT '/var/mail/vmail/%d/%n' as home, 'maildir:/var/mail/vmail/%d/%n' as mail, 1003 AS uid, 1003 AS gid, concat('dirsize:storage=',  quota) AS quota FROM mailbox WHERE username = '%u' AND active = '1'
# Get the password
password_query = SELECT username as user, password, '/home/vmail/%d/%n' as userdb_home, 'maildir:/home/vmail/%d/%n' as userdb_mail, 5000 as  userdb_uid, 5000 as userdb_gid FROM mailbox WHERE username = '%u' AND active = '1'
# If using client certificates for authentication, comment the above and uncomment the following
#password_query = SELECT null AS password, ‘%u’ AS user

```
### verification
```diff
dovecot auth login testuser
# we configured to pull maisl from /var/mail/vmail/mail.awcator.in/cwcator/cur
!# the problem is here postfix write mails to this directory but without neccasry permission dovecot cant read up the mails
!# to fix this problem as temp solution make
chmod -R a+rwx /var/mail/vmail/

you can test from across internet using IMAP clients like BlueMail/Thunderbird etc

root@mail:/home/awcator# dovecot auth login cwcator@mail.awcator.in
Password: 
passdb: cwcator@mail.awcator.in auth succeeded
extra fields:
  user=cwcator@mail.awcator.in
  
userdb extra fields:
  cwcator@mail.awcator.in
  home=/var/mail/vmail/mail.awcator.in/cwcator
  mail=maildir:/var/mail/vmail/mail.awcator.in/cwcator
  uid=1003
  gid=1003
  quota=dirsize:storage=10240000

# without LMTP
#added in /etc/dovecot/dovecot.conf
first_valid_uid=0

# I changed dovcot-sql.conf userpermissions to read their mails as follows
user_query = SELECT '/var/mail/vmail/%d/%n' as home, 'maildir:/var/mail/vmail/%d/%n' as mail, 8 AS uid, 1003 AS gid, concat('dirsize:storage=',  quota) AS quota FROM mailbox WHERE username = '%u' AND active = '1'
# where 8 is mail euid
# where 1003 is mailers guid
```

# PART 5: Configure Postfix Submissions port with Dovecot (port 557)

https://serverfault.com/questions/698854/postfix-fatal-specify-a-password-table-via-the-smtp-sasl-password-maps-config <br>
add these in /etc/postfix/main.cf <br>
```
smtpd_sasl_auth_enable = yes

smtpd_sasl_type = dovecot
smtpd_sasl_path = private/auth
smtpd_sasl_authenticated_header = yes
smtpd_sasl_auth_enable = yes
smtpd_sasl_security_options = noanonymous
broken_sasl_auth_clients = yes
```
enable SMTP submission in  master.cf
```
submission inet n       -       y       -       -       smtpd
  -o syslog_name=postfix/submission
  #-o smtpd_tls_security_level=encrypt
  -o smtpd_sasl_auth_enable=yes
  #-o smtpd_tls_auth_only=yes
  -o smtpd_reject_unlisted_recipient=no
  #-o smtpd_client_restrictions=$mua_client_restrictions
  #-o smtpd_helo_restrictions=$mua_helo_restrictions
  #-o smtpd_sender_restrictions=$mua_sender_restrictions
  #-o smtpd_recipient_restrictions=
  -o smtpd_relay_restrictions=permit_sasl_authenticated,reject
  -o milter_macro_daemon_name=ORIGINATING

```
Add these in dovecot.conf
```diff
#If you want, you can have dovecot automatically add a Trash and Sent folder to mailboxes:
protocol imap {
  mail_plugins = " autocreate"
}
plugin {
  autocreate = Trash
  autocreate2 = Sent
  autosubscribe = Trash
  autosubscribe2 = Sent
}
first_valid_uid=0
auth_mechanisms = plain

service auth {
#remove ! below line, just to show i have changed this line
!    unix_listener /var/spool/postfix/private/auth { 
        group = postfix
        mode = 0660
        user = postfix
    }
    user = root
}

```
restart all the services
```
systemctl restart postfix dovecot
```

### verification
start sending mails from mail client by congiuring it to connect on SMTP Submission PORT 587

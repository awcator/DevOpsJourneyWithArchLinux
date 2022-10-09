## Mirror a entire webpage locally with all depended resource
```
wget  --no-clobber --page-requisites --html-extension --convert-links --restrict-file-names=windows --timestamping -e robots=off https://mywebsite.com
```
## copy to clipboard
```
echo hello|xclip -selection c -o


alias copy='xclip -selection c -o'
echo hello|copy
```
## paste from clipboard
```
xclip -selection c -o

alias paste="xclip -selection c -o"
paste|wc -l
```
## cat all files with file name
```
tail -n +1 file1.txt file2.txt file3.txt
```
### send mail from your SMTP server
configure your SMTP detaisl in /etc/ssmtp/ssmtp.conf and aliases 
[check this example for smtp config](https://github.com/awcator/DevOpsJourneyWithArchLinux/blob/master/configs/etc/ssmtp/ssmtp.conf) <br>
[check this example for alias config  ](https://github.com/awcator/DevOpsJourneyWithArchLinux/blob/master/configs/etc/ssmtp/revaliases)

```
Create mail body like this in a file
root@busybox3:/etc/ssmtp# cat a.txt
Subject: This is Subject Line

Email content line 1
Email content line 2
#send the mail
DEBIAN_FRONTEND=noninteractive
apt-get install -y libreadline-dev ssmtp mailutils vim
root@busybox3:/etc/ssmtp# ssmtp -d9 oivnmblydqzlkfxras@tmmwj.com <a.txt
```

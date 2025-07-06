# basics
pacman -S openldap
/etc/openldap/slapd.conf
```
include         /etc/openldap/schema/core.schema
pidfile         /run/openldap/slapd.pid
argsfile        /run/openldap/slapd.args
modulepath      /usr/lib/openldap
moduleload      back_mdb.la
database config
database        mdb
maxsize         1073741824
suffix          "dc=awcator,dc=com"
rootdn          "cn=awcator-root,dc=awcator,dc=com"
rootpw          secret
directory       /var/lib/openldap/openldap-data
index   objectClass     eq
database monitor
```
give appropriate permissions:
```
sudo mkdir -p /var/lib/openldap/openldap-data
sudo chown ldap:ldap -R /var/lib/openldap/openldap-data
```
and run
```bash
sudo systemctl start slapd.service
sudo systemctl status slapd.service
```
Let's create first DN: 1.ldif
```
dn: dc=com
objectclass: dcObject
objectclass: organization
o: Internet
dc: com

dn: dc=awcator,dc=com
objectclass: dcObject
objectclass: Organization
o: Awcator
dc: awcator
```
search operations
```
ldapsearch -D "cn=awcator-root,dc=awcator,dc=com" -w secret -b dc=awcator,dc=com objectclass='*'
ldapsearch -D "cn=awcator-root,dc=awcator,dc=com" -w secret -b dc=awcator,dc=com objectclass='*' -H ldap://localhost:389
ldapsearch -H ldap://localhost:389 -b dc=awcator,dc=com -  # unautheticated/ananoymous user access
```
add our first dn 1.ldif 
```
ldapadd -D "cn=awcator-root,dc=awcator,dc=com" -w secret -f first.ldif
```
more complex ldif: users.ldif. and add using add command
```
#create testteam
dn: ou=testteam,dc=awcator,dc=com
objectclass: organizationalUnit
ou: testteam

#creaet enginnering team
dn: ou=eng-team,dc=awcator,dc=com
objectclass: organizationalUnit
ou: eng-team

#add users to it
dn: cn=twcator beta,ou=testteam,dc=awcator,dc=com
objectclass: person
sn: beta
cn: twcator

dn: cn=ewcator one,ou=testteam,dc=awcator,dc=com
objectclass: person
sn: one
cn: ewcator

dn: cn=ewcator2 two,ou=testteam,dc=awcator,dc=com
objectclass: person
sn: two
cn: ewcator2
```

#modify users
```
#modif.ldif
dn: cn=ewcator2 two,ou=testteam,dc=awcator,dc=com
changetype: modify
add: telephoneNumber
telephoneNumber: +91 454545 45545 

ldapmodify -D "cn=awcator-root,dc=awcator,dc=com" -w secret -H ldap://localhost:389 -f modif.ldif
```

#modify2
```
dn: cn=ewcator2 two,ou=testteam,dc=awcator,dc=com
changetype: modify
replace: telephoneNumber
telephoneNumber: +91 21323 45545 

ldapmodify -D "cn=awcator-root,dc=awcator,dc=com" -w secret -H ldap://localhost:389 -f add-phone.ldif
```

add password for users:
```
dn: cn=ewcator2 two,ou=testteam,dc=awcator,dc=com
changetype: modify
add: userPassword
userPassword: dummy 

ldapmodify -D "cn=awcator-root,dc=awcator,dc=com" -w secret -H ldap://localhost:389 -f add-phone.ldif


#also another way
slappasswd 
New password: 
Re-enter new password: 
{SSHA}SpOoyzs73D1FHbP9r9bS6by85ey2KvYb

dn: cn=ewcator one,ou=testteam,dc=awcator,dc=com
changetype: modify
add: userPassword
userPassword: {SSHA}SpOoyzs73D1FHbP9r9bS6by85ey2KvYb 

ldapmodify -D "cn=awcator-root,dc=awcator,dc=com" -w secret -H ldap://localhost:389 -f updatepass.ldif
```
Move user to engineering:
```
dn: cn=ewcator2 two,ou=testteam,dc=awcator,dc=com
changetype: modrdn
newrdn: cn=ewcator2 two
deleteoldrdn: 1
newsuperior: ou=eng-team,dc=awcator,dc=com
```
extra
```
extra/phpldapadmin
sudo systemctl start phpldapadmin.service
sudo systemctl status phpldapadmin.service
```

# Overlays
add overlay liens in slapd.conf
```
include         /etc/openldap/schema/core.schema
pidfile         /run/openldap/slapd.pid
argsfile        /run/openldap/slapd.args
modulepath      /usr/lib/openldap
moduleload      back_mdb.la
moduleload	auditlog
database config
database        mdb
maxsize         1073741824
overlay		auditlog   #<-------------------------------------------------- notice
auditlog        /var/tmp/awcator_ldap_logs.ldif #<-------------------------------------------------- notice
suffix          "dc=awcator,dc=com"
rootdn          "cn=awcator-root,dc=awcator,dc=com"
rootpw          secret
directory       /var/lib/openldap/openldap-data
index   objectClass     eq
database monitor

```
```
man slapo-auditlog
touch /var/tmp/awcator_ldap_logs.ldif
sudo chown ldap:ldap /var/tmp/awcator_ldap_logs.ldif
```
modify some data and view the file here. overlay demonstrated.

# OLC: Online configuration 
```
include         /etc/openldap/schema/core.schema
pidfile         /run/openldap/slapd.pid
argsfile        /run/openldap/slapd.args
modulepath      /usr/lib/openldap
moduleload      back_mdb.la
moduleload	auditlog

database config
rootdn		"cn=awcator-config,cn=config"
rootpw		secret

database        mdb
maxsize         1073741824

suffix          "dc=awcator,dc=com"
rootdn          "cn=awcator-root,dc=awcator,dc=com"
rootpw          secret
directory       /var/lib/openldap/openldap-data
index   objectClass     eq
database monitor
```
test
```
ldapsearch -D "cn=awcator-config,cn=config" -w secret -b cn=config objectclass='*' -H ldap://localhost:389
```
add logs support to test
```
man slapo-accesslog
sudo mkdir -p /var/ldaplogs
sudo chown ldap:ldap /var/ldaplogs
```
add new databse for logs
```
dn: olcDatabase={3}mdb,cn=config
changetype: add
objectclass: olcDatabaseConfig
objectclass: olcMdbConfig
olcDatabase: {3}mdb
olcSuffix: cn=log
olcDbDirectory: /var/ldaplogs

```
add and search
```
ldapmodify -D "cn=awcator-config,cn=config" -w secret -f  a.ldif
ldapsearch -D "cn=awcator-config,cn=config" -w secret -b cn=config objectclass='*' -H ldap://localhost:389
```
setup logs for mdb main database
```
dn: cn=module{0},cn=config
changetype: modify
add: olcModuleLoad
olcModuleLoad: accesslog



dn: olcOverlay=accesslog,olcDatabase={1}mdb,cn=config
changetype: add
objectClass: olcOverlayConfig
objectClass: olcAccessLogConfig
olcOverlay: accesslog
olcAccessLogDB: cn=log
olcAccessLogOps: all
```

```
ldapmodify -D "cn=awcator-config,cn=config" -w secret -f  a.ldif
ldapsearch -D "cn=awcator-config,cn=config" -w secret -b cn=log objectclass='*' -H ldap://localhost:389
ldapsearch -D "cn=awcator-root,dc=awcator,dc=com" -w secret -b dc=awcator,dc=com objectclass='*' -H ldap://localhost:389
ldapsearch -D "cn=awcator-config,cn=config" -w secret -b cn=log objectclass='*' -H ldap://localhost:389
```
upon restarting server u will loose all configs so make permant
# permanent method
```
sudo mkdir /etc/openldap/slapd.d
sudo slaptest -f slapd.conf  -F slapd.d/
sudo chown ldap:ldap -R slapd.d/

#run
sudo /usr/lib/slapd  -u ldap -g ldap -h "ldap:/// ldapi:///" -d -1 -F /etc/openldap/slapd.d/
#then rerun above commands to setup logs and overlay
```
# OLC setup
```
ldapsearch -D "cn=ewcator2 two,ou=eng-team,dc=awcator,dc=com" -w dummy -b dc=awcator,dc=com objectclass='*' -H ldap://localhost:389
# this works , we should not give access all passwords access to others for this user

dn: olcDatabase={1}mdb,cn=config
changetype: modify
add: olcAccess
olcAccess: {0}to attrs=userPassword by self write by anonymous auth by * none

dn: olcDatabase={1}mdb,cn=config
changetype: modify
add: olcAccess
olcAccess: {1}to * by self write by users read by * none

ldapmodify -D "cn=awcator-config,cn=config" -w secret -f  b.ldif
ldapsearch -D "cn=ewcator2 two,ou=eng-team,dc=awcator,dc=com" -w dummy -b dc=awcator,dc=com objectclass='*' -H ldap://localhost:389
ldapsearch -D "cn=awcator-config,cn=config" -w secret -b "olcDatabase={1}mdb,cn=config" objectclass='*' -H ldap://localhost:389
# now only he can view his own password and mofiy passwords


dn: cn=ewcator2 two,ou=eng-team,dc=awcator,dc=com
changetype: modify
replace: userPassword
userPassword: changeit

ldapmodify -D "cn=ewcator2 two,ou=eng-team,dc=awcator,dc=com" -w dummy -H ldap://localhost:389 -f a.ldif
ldapsearch -D "cn=ewcator2 two,ou=eng-team,dc=awcator,dc=com" -w dummy -b dc=awcator,dc=com objectclass='*' -H ldap://localhost:389 #fails
ldapsearch -D "cn=ewcator2 two,ou=eng-team,dc=awcator,dc=com" -w chnageit -b dc=awcator,dc=com objectclass='*' -H ldap://localhost:389
```

# password policy
```
dn: cn=module{0},cn=config
changetype: modify
add: olcModuleLoad
olcModuleLoad: ppolicy

dn: olcOverlay=ppolicy, olcDatabase={1}mdb,cn=config
changetype: add
objectclass: olcPPolicyConfig
olcOverlay: ppolicy
olcPPolicyDefault: cn=Normal Policy,dc=awcator,dc=com
olcPPolicyHashClearText: TRUE


ldapmodify -D "cn=awcator-config,cn=config" -w secret -f  a.ldif


dn: cn=Normal Policy,dc=awcator,dc=com
changetype: add
objectclass: device
objectclass: pwdPolicy
cn: Normal Policy
pwdAttribute: userPassword
pwdInHistory: 2

ldapmodify -D "cn=awcator-root,dc=awcator,dc=com" -w secret -H ldap://localhost:389

#now lets try chaning password

dn: cn=ewcator2 two,ou=eng-team,dc=awcator,dc=com
changetype: modify
replace: userPassword
userPassword: changeit

ldapmodify -D "cn=ewcator2 two,ou=eng-team,dc=awcator,dc=com" -w changeit -H ldap://localhost:389 -f a.ldif
# will fail because the new value  is same as old value and hence password policy is enforced 
# change the password to something else and try again it should work, but with hashed contntests
ldapsearch -D "cn=ewcator2 two,ou=eng-team,dc=awcator,dc=com" -w changei1t -b dc=awcator,dc=com objectclass='*' -H ldap://localhost:389
```

# loading extranal schema
```
# get current loaded shchema
 ldapsearch -D "cn=awcator-config,cn=config" -w secret -b "cn=config" objectclass='*' -H ldap://localhost:389 dn
sudo ls /etc/openldap/schema/

tmp.conf:
include /etc/openldap/schema/somenew.schema
slaptest -f tmp.conf -F /workarea
then load the generated ldifs, modify the index if required:
change dn to "dn: cn=somenewschma,cn=schema,cn=config"
ldapadd -D "cn=awcator-config,cn=config" -w secret  -f mygenerated.ldif

#verify if added
ldapsearch -D "cn=awcator-config,cn=config" -w secret -b "cn=config" objectclass='*' -H ldap://localhost:389 dn

```

# Basics
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
touch /var/tmp/awcator_ldap_logs.ldif
sudo chown ldap:ldap /var/tmp/awcator_ldap_logs.ldif
```
modify some data and view the file here. overlay demonstrated.

# OLC: Online configuration 
```

```

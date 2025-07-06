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
sudo chown ldap:ldap -R slapd.d/
sudo slaptest -f slapd.conf  -F slapd.d/

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


# Prod like setup
```
sudo \rm -vrf /var/lib/openldap/openldap-data /etc/openldap/slapd.d

/etc/openldap/schema/inetuser.schema:
#
# inetuser.schema – Custom schema for inetUser
#

attributetype ( 2.16.840.1.113730.3.1.692
  NAME 'inetUserStatus'
  DESC '"active", "inactive", or "deleted" status of a user'
  EQUALITY caseIgnoreMatch
  SYNTAX 1.3.6.1.4.1.1466.115.121.1.15
  SINGLE-VALUE )

attributetype ( 2.16.840.1.113730.3.1.693
  NAME 'inetUserHttpURL'
  DESC 'A user Web addresses'
  EQUALITY caseIgnoreIA5Match
  SYNTAX 1.3.6.1.4.1.1466.115.121.1.26 )

objectclass ( 2.16.840.1.113730.3.2.130
  NAME 'inetUser'
  DESC 'Auxiliary class for delivery of subscriber services'
  SUP top
  AUXILIARY
  MAY ( uid $ inetUserStatus $ inetUserHttpURL $ userPassword ) )



/etc/openldap/slapd.conf
include /etc/openldap/schema/core.schema
include /etc/openldap/schema/cosine.schema
include /etc/openldap/schema/inetorgperson.schema
include /etc/openldap/schema/nis.schema
include         /etc/openldap/schema/inetuser.schema
pidfile         /run/openldap/slapd.pid
argsfile        /run/openldap/slapd.args
modulepath      /usr/lib/openldap
moduleload      back_mdb.la
moduleload	     auditlog
moduleload      accesslog
moduleload      ppolicy

database config
rootdn		"cn=awcator-config,cn=config"
rootpw		secret

database        mdb
maxsize         1073741824
suffix          "dc=identity,dc=awcator,dc=com"
rootdn          "cn=awcator-root,dc=identity,dc=awcator,dc=com"
rootpw          secret
directory       /var/lib/openldap/openldap-data
index   objectClass     eq
database monitor


init.ldif:
dn: dc=identity,dc=awcator,dc=com
objectclass: dcObject
objectclass: organization
o: Awcator Identity
dc: identity

dn: ou=People,dc=identity,dc=awcator,dc=com
objectClass: organizationalUnit
ou: People

dn: ou=Group,dc=identity,dc=awcator,dc=com
objectClass: organizationalUnit
ou: Group

dn: ou=Policies,dc=identity,dc=awcator,dc=com
objectClass: organizationalUnit
ou: Policies
description: Directory policies.

dn: cn=default,ou=Policies,dc=identity,dc=awcator,dc=com
cn: default
description: Default password policy.
objectclass: device
objectclass: pwdPolicy
pwdAttribute: userPassword
pwdInHistory: 2


sudo mkdir -p /var/lib/openldap/openldap-data
sudo chown ldap:ldap /var/lib/openldap/openldap-data
sudo mkdir /etc/openldap/slapd.d
sudo chown ldap:ldap -R slapd.d/

sudo slapadd -f /etc/openldap/slapd.conf -l /tmp/init.ldif
sudo slaptest -f slapd.conf  -F slapd.d/
sudo chown ldap:ldap -R /var/lib/openldap/openldap-data
sudo chown ldap:ldap -R slapd.d/
sudo /usr/lib/slapd -u ldap -g ldap -h "ldap:/// ldapi:///" -d 1
ldapsearch -D "cn=awcator-config,cn=config" -w secret -b "cn=config" objectclass='*' -H ldap://localhost:389 dn

postinit.ldif
dn: cn=opsTeam,ou=Group,dc=identity,dc=awcator,dc=com
changetype: add
objectClass: top
objectClass: posixGroup
cn: opsTeam
gidNumber: 1005
memberUid: placeholder

dn: cn=engOpsTeam,ou=Group,dc=identity,dc=awcator,dc=com
changetype: add
objectClass: top
objectClass: posixGroup
cn: engOpsTeam
gidNumber: 1001
memberUid: placeholder

dn: cn=engTestTeam,ou=Group,dc=identity,dc=awcator,dc=com
changetype: add
objectClass: top
objectClass: posixGroup
cn: engTestTeam
gidNumber: 1002
memberUid: placeholder

dn: cn=engRnDTeam,ou=Group,dc=identity,dc=awcator,dc=com
changetype: add
objectClass: top
objectClass: posixGroup
cn: engRnDTeam
gidNumber: 1003
memberUid: placeholder

dn: cn=engManagers,ou=Group,dc=identity,dc=awcator,dc=com
changetype: add
objectClass: top
objectClass: posixGroup
cn: engManagers
gidNumber: 1004
memberUid: placeholder

ldapmodify -D "cn=awcator-root,dc=identity,dc=awcator,dc=com" -w secret -H ldap://localhost:389 -f /tmp/post.ldif

#user1.ldif
dn: uid=devuser,ou=People,dc=identity,dc=awcator,dc=com
objectClass: inetOrgPerson
objectClass: posixAccount
objectClass: inetUser
objectClass: top
cn: Dev User
sn: User
uid: devuser
uidNumber: 2001
gidNumber: 1001
homeDirectory: /home/devuser
loginShell: /bin/bash
inetUserStatus: Active
userPassword: test

ldapadd -x -D "cn=awcator-root,dc=identity,dc=awcator,dc=com" -w secret -H ldap://localhost:389 -f /tmp/1.ldif
ldapsearch -D "uid=devuser,ou=People,dc=identity,dc=awcator,dc=com" -w test -b dc=identity,dc=awcator,dc=com objectclass='*' -H ldap://localhost:389-
```
```diff
# todo write access.ldif
ldapmodify -D "cn=awcator-config,cn=config" -w secret -f  /tmp/access.ldif
ldapsearch -D "cn=awcator-config,cn=config" -w secret -b "cn=config" objectclass='*' -H ldap://localhost:389 -b "olcDatabase={1}mdb,cn=config"
```
```
dn: uid=opsuser,ou=People,dc=identity,dc=awcator,dc=com
objectClass: top
objectClass: inetOrgPerson
objectClass: posixAccount
uid: opsuser
sn: Ops
cn: opsuser
uidNumber: 2001
gidNumber: 1005
homeDirectory: /home/opsuser
loginShell: /bin/bash
userPassword: ops123

dn: uid=engtest1,ou=People,dc=identity,dc=awcator,dc=com
objectClass: top
objectClass: inetOrgPerson
objectClass: posixAccount
uid: engtest1
sn: Test
cn: engtest1
uidNumber: 2002
gidNumber: 1002
homeDirectory: /home/engtest1
loginShell: /bin/bash
userPassword: test123

dn: uid=engrnd1,ou=People,dc=identity,dc=awcator,dc=com
objectClass: top
objectClass: inetOrgPerson
objectClass: posixAccount
uid: engrnd1
sn: RnD
cn: engrnd1
uidNumber: 2003
gidNumber: 1003
homeDirectory: /home/engrnd1
loginShell: /bin/bash
userPassword: rnd123

dn: uid=engmanager1,ou=People,dc=identity,dc=awcator,dc=com
objectClass: top
objectClass: inetOrgPerson
objectClass: posixAccount
uid: engmanager1
sn: Manager
cn: engmanager1
uidNumber: 2004
gidNumber: 1004
homeDirectory: /home/engmanager1
loginShell: /bin/bash
userPassword: manager123

dn: uid=engops1,ou=People,dc=identity,dc=awcator,dc=com
objectClass: top
objectClass: inetOrgPerson
objectClass: posixAccount
uid: engops1
sn: Ops
cn: engops1
uidNumber: 2005
gidNumber: 1001
homeDirectory: /home/engops1
loginShell: /bin/bash
userPassword: engops123

ldapadd -x \
  -D "cn=awcator-root,dc=identity,dc=awcator,dc=com" \
  -w secret \
  -H ldap://localhost:389 \
  -f /tmp/test-users.ldif
```
testScript
```
#!/bin/bash

echo "=== LDAP Access Control Test Script ==="
echo "Testing the refined access control requirements:"
echo "- opsTeam/engOpsTeam: read-only to own data"
echo "- engTestTeam/engRnDTeam: modify own + ops teams, but no eng password access"
echo "- engManagers: read-only access to all"
echo ""

# Test 1: engmanager1 should be able to read all entries
echo "Test 1: engmanager1 reading all entries (should work)"
ldapsearch -x -D "uid=engmanager1,ou=People,dc=identity,dc=awcator,dc=com" -w manager123 -b "ou=People,dc=identity,dc=awcator,dc=com" "(objectClass=*)" dn
echo ""

# Test 2: engtest1 should be able to read ops users
echo "Test 2: engtest1 reading ops users (should work)"
ldapsearch -x -D "uid=engtest1,ou=People,dc=identity,dc=awcator,dc=com" -w test123 -b "ou=People,dc=identity,dc=awcator,dc=com" "(|(uid=opsuser)(uid=engops1))" dn
echo ""

# Test 3: engtest1 should NOT be able to read other eng users' passwords
echo "Test 3: engtest1 trying to read engrnd1's password (should fail)"
ldapsearch -x -D "uid=engtest1,ou=People,dc=identity,dc=awcator,dc=com" -w test123 -b "ou=People,dc=identity,dc=awcator,dc=com" "(uid=engrnd1)" userPassword
echo ""

# Test 4: engtest1 should be able to modify ops user password
echo "Test 4: engtest1 modifying opsuser password (should work)"
cat > /tmp/modify_ops_password.ldif << EOF
dn: uid=opsuser,ou=People,dc=identity,dc=awcator,dc=com
changetype: modify
replace: userPassword
userPassword: newops123
EOF
ldapmodify -x -D "uid=engtest1,ou=People,dc=identity,dc=awcator,dc=com" -w test123 -f /tmp/modify_ops_password.ldif
echo ""

# Test 5: engtest1 should NOT be able to modify other eng user password
echo "Test 5: engtest1 trying to modify engrnd1 password (should fail)"
cat > /tmp/modify_eng_password.ldif << EOF
dn: uid=engrnd1,ou=People,dc=identity,dc=awcator,dc=com
changetype: modify
replace: userPassword
userPassword: newrnd123
EOF
ldapmodify -x -D "uid=engtest1,ou=People,dc=identity,dc=awcator,dc=com" -w test123 -f /tmp/modify_eng_password.ldif
echo ""

# Test 6: opsuser should only be able to read own data
echo "Test 6: opsuser trying to read other users (should fail)"
ldapsearch -x -D "uid=opsuser,ou=People,dc=identity,dc=awcator,dc=com" -w ops123 -b "ou=People,dc=identity,dc=awcator,dc=com" "(uid=engtest1)" dn
echo ""

# Test 7: engmanager1 should be able to read passwords but not modify
echo "Test 7: engmanager1 reading passwords (should work)"
ldapsearch -x -D "uid=engmanager1,ou=People,dc=identity,dc=awcator,dc=com" -w manager123 -b "ou=People,dc=identity,dc=awcator,dc=com" "(uid=opsuser)" userPassword
echo ""

echo "Test 8: engmanager1 trying to modify password (should fail)"
cat > /tmp/manager_modify_password.ldif << EOF
dn: uid=opsuser,ou=People,dc=identity,dc=awcator,dc=com
changetype: modify
replace: userPassword
userPassword: managerchange123
EOF
ldapmodify -x -D "uid=engmanager1,ou=People,dc=identity,dc=awcator,dc=com" -w manager123 -f /tmp/manager_modify_password.ldif
echo ""

echo "=== Test Complete ==="
```

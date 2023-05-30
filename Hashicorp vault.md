# Using Vault for Secrets Management
  ## Introduction

Vault is a powerful tool for secrets management that allows you to store and retrieve sensitive data securely. 
## Install
```
wget https://releases.hashicorp.com/vault/1.13.1/vault_1.13.1_linux_amd64.zip
unzip vault_1.13.1_linux_amd64.zip
cd vault_1.13.1_linux_amd64
./vault server -dev
```
## Login
Login can be done varius types. In the end it always depnds on the token
### Root Token login
```
COpy the root token from after running

```
## Transit-KV

### Enable Transit-KV

To use the Transit-KV secrets engine, you first need to enable it in your Vault instance:

```
vault secrets enable transit
```
#### Create a Key
To create a new encryption key, use the following command:
```
vault write -f transit/keys/my-key
```
#### Decrypt Data Using a Key
To decrypt data using a specific key, use the transit/decrypt endpoint with the ciphertext parameter:
```
vault write transit/decrypt/my-key ciphertext="<ciphertext>"
```
#### Encrypt Data Using a Key
To encrypt data using a specific key, use the transit/encrypt endpoint with the plaintext parameter:
```
vault write transit/encrypt/my-key plaintext="<plaintext>"
```
## PKI

### Get PKI Engine Mount Paths
To get the mount paths for the PKI secrets engine, use the following command:

```sh
vault secrets list -detailed | grep -i pki
```

#### List Roles
To list the roles in the PKI engine mounted path, use the following command:

```
vault list path/to/pkiEngine/roles
```

## PKI the hard way
```diff
#Main intention is to sign public key of server to be signed by privatekey of the cA
  
mkdir awcatorPKI
cd awcatorPKI
export PKI_DIR=`pwd`
mkdir ca intermediate-ca server
openssl rand -hex 16  # this outputs 16digit hexa number we ca use this as serail number for ourcertificates insted of sequetila numbers like 1,2,3


cd ca/
# generate PrivateKey and selfSigned RootCA certificate
openssl req -new --newkey rsa:2048 -days 365 -nodes -x509 -subj '/CN=root.awcator.com' -keyout ca_private.key -out signed_ca_certificate.crt
# view the certificate
openssl x509 -text -in signed_ca_certificate.crt

# Notice SubjectKeyIdetifier and AurhorityKeyIdentifer both are same, which implies it is a self signed certificate. 
# ROOT certificates must be self signed. they wont be signed by others. Thats the point of being root 
# and Notice CA: true, hence it is certificateAutority  (THose are keyIdentifer not the serailNumbers)
```
![image](https://user-images.githubusercontent.com/54628909/236603372-5e9bc3ac-3de0-4ef6-8248-426a0d845999.png)
```
# Notice the subject name and issuer, both are same, which implies the certificate was issued for himself 
```
![image](https://user-images.githubusercontent.com/54628909/236603524-63f22bc9-57f3-4d6c-9900-45780f45587c.png)

### setup private keys
```diff 
rm *
------------------------PrivateKeys-----------------------
# Now with manual process
cd $PKI_DIR
openssl genrsa -aes256 -out ca/ca_private.key 4096
#since we are enrpytinh with aes256 put a pass phrase,  this pass phrase wil be used later on to sign new certificates
openssl genrsa  -out intermediate-ca/intermediateCa.key 4096
# we can encrypt intermidate-aurotiy too. i skipped here
openssl genrsa  -out server/server.key 2048
# here size is 2048 which is less than ca and intermidate, bcz server certificates will be used a lot, a lots of handshake will hapeen (https,tls with this, storing big key reduces the compution) offcourse this will reduce security but  trying to balance security and performce. 
# no aes encryption here, otherwise endusers has to enter password everytime when they try to do https connections.
```
### Setup Root's Policy's, paste the following contnetns inside ca/config
```diff 
[ca]
# /home/awcator/PKI_DIR/ca/config
# see man ca
default_ca    = CA_default

[CA_default]
dir     = /home/awcator/awcatorPKI/ca
certs     =  $dir/certs
crl_dir    = $dir/crl
new_certs_dir   = $dir/newcerts
database   = $dir/index
serial    = $dir/serial
RANDFILE   = $dir/.rand

private_key   = $dir/ca_private.key
certificate   = $dir/certs/ca.crt

crlnumber   = $dir/crlnumber
crl    =  $dir/crl/ca.crl
crl_extensions   = crl_ext
default_crl_days    = 30

default_md   = sha256

name_opt   = ca_default
cert_opt   = ca_default
default_days   = 365
preserve   = no
policy    = policy_strict

[ policy_strict ]
countryName   = match
stateOrProvinceName  =  supplied
organizationName  = match
organizationalUnitName  =  optional
commonName   =  supplied
emailAddress   =  optional

[ policy_loose ]
countryName   = optional
stateOrProvinceName  = optional
localityName   = optional
organizationName  = optional
organizationalUnitName   = optional
commonName   = supplied
emailAddress   = optional

[ req ]
# Options for the req tool, man req.
default_bits   = 2048
distinguished_name  = req_distinguished_name
string_mask   = utf8only
default_md   =  sha256
# Extension to add when the -x509 option is used.
x509_extensions   = v3_ca

[ req_distinguished_name ]
countryName                     = Country Name (2 letter code)
stateOrProvinceName             = State or Province Name
localityName                    = Locality Name
0.organizationName              = Organization Name
organizationalUnitName          = Organizational Unit Name
commonName                      = Common Name
emailAddress                    = Email Address
countryName_default  = IN
stateOrProvinceName_default = India
0.organizationName_default = Awcator Ltd

[ v3_ca ]
# Extensions to apply when createing root ca
# Extensions for a typical CA, man x509v3_config
subjectKeyIdentifier  = hash
authorityKeyIdentifier  = keyid:always,issuer
basicConstraints  = critical, CA:true
keyUsage   =  critical, digitalSignature, cRLSign, keyCertSign

[ v3_intermediate_ca ]
# Extensions to apply when creating intermediate or sub-ca
# Extensions for a typical intermediate CA, same man as above
subjectKeyIdentifier  = hash
authorityKeyIdentifier  = keyid:always,issuer
#pathlen:0 ensures no more sub-ca can be created below an intermediate
basicConstraints  = critical, CA:true, pathlen:0
keyUsage   = critical, digitalSignature, cRLSign, keyCertSign

[ server_cert ]
# Extensions for server certificates
basicConstraints  = CA:FALSE
nsCertType   = server
nsComment   =  "OpenSSL Generated Server Certificate"
subjectKeyIdentifier  = hash
authorityKeyIdentifier  = keyid,issuer:always
keyUsage   =  critical, digitalSignature, keyEncipherment
extendedKeyUsage  = serverAuth

```
#### generate Root certificates
```diff 
# before generateing root certificate, keep some standard folder strucure as per we defined in the config file
cd ca/
mkdir certs crl newcerts 
touch index .rand
echo 69696 > serial # insted of echoing 6969 make use of this  'openssl rand -hex 16'
cd ../

# generate RootCA certificaite
openssl req -config ca/config -key ca/ca_private.key -new -x509 -days 7500 -sha256 -extensions v3_ca -out ca/certs/ca.crt
-# GIVE COMMON  NAME AS ROOTCA
openssl x509 -text -in ca/certs/ca.crt
openssl x509 -text -in ca/certs/ca.crt -noout #without prinitng the certificate Contents

-# Now with that config CA wont sign for diffrent ORg and country, to verify
openssl req -new --newkey rsa:2048 -out mycsr.csr -subj '/C=US/ST=CA/L=San Francisco/O=MyOrg/OU=WrongOU/CN=mydomain.com' 
openssl ca -config ca/config -in mycsr.csr -out mycert.crt
# this should fail, if it succeeds, something is wrong with config file
# cleanup
# rm *.csr *.pem
```

#### Intermediate_ca config file
```
[ca]
# /home/awcator/PKI_DIR/intermediate-ca/config
# see man ca
default_ca    = CA_default

[CA_default]
dir     = /home/awcator/awcatorPKI/intermediate-ca 
# change from root
certs     =  $dir/certs
crl_dir    = $dir/crl
new_certs_dir   = $dir/newcerts
database   = $dir/index
serial    = $dir/serial
RANDFILE   = $dir/.rand

private_key   = $dir/intermediateCa.key  
# change from root
certificate   = $dir/certs/intermediateCa.crt 
# change from root

crlnumber   = $dir/crlnumber
crl    =  $dir/crl/ca.crl
crl_extensions   = crl_ext
default_crl_days    = 30

default_md   = sha256

name_opt   = ca_default
cert_opt   = ca_default
default_days   = 365
preserve   = no
policy    = policy_loose   
# change from ROOT, allow signing form diffrent orgs

[ policy_strict ]
countryName   = supplied
stateOrProvinceName  =  supplied
organizationName  = match
organizationalUnitName  =  optional
commonName   =  supplied
emailAddress   =  optional

[ policy_loose ]
countryName   = optional
stateOrProvinceName  = optional
localityName   = optional
organizationName  = optional
organizationalUnitName   = optional
commonName   = supplied
emailAddress   = optional

[ req ]
# Options for the req tool, man req.
default_bits   = 2048
distinguished_name  = req_distinguished_name
string_mask   = utf8only
default_md   =  sha256
# Extension to add when the -x509 option is used.
x509_extensions   = v3_ca

[ req_distinguished_name ]
countryName                     = Country Name (2 letter code)
stateOrProvinceName             = State or Province Name
localityName                    = Locality Name
0.organizationName              = Organization Name
organizationalUnitName          = Organizational Unit Name
commonName                      = Common Name
emailAddress                    = Email Address
countryName_default  = IN
stateOrProvinceName_default = India
0.organizationName_default = Awcator Ltd

[ v3_ca ]
# Extensions to apply when createing root ca
# Extensions for a typical CA, man x509v3_config
subjectKeyIdentifier  = hash
authorityKeyIdentifier  = keyid:always,issuer
basicConstraints  = critical, CA:true
keyUsage   =  critical, digitalSignature, cRLSign, keyCertSign

[ v3_intermediate_ca ]
# Extensions to apply when creating intermediate or sub-ca
# Extensions for a typical intermediate CA, same man as above
subjectKeyIdentifier  = hash
authorityKeyIdentifier  = keyid:always,issuer
#pathlen:0 ensures no more sub-ca can be created below an intermediate
basicConstraints  = critical, CA:true, pathlen:0
keyUsage   = critical, digitalSignature, cRLSign, keyCertSign

[ server_cert ]
# Extensions for server certificates
basicConstraints  = CA:FALSE
nsCertType   = server
nsComment   =  "OpenSSL Generated Server Certificate"
subjectKeyIdentifier  = hash
authorityKeyIdentifier  = keyid,issuer:always
keyUsage   =  critical, digitalSignature, keyEncipherment
extendedKeyUsage  = serverAuth


```

#### Generate IntermediateCA Certificate
```
cd ca/
mkdir certs crl newcerts csr
touch index .rand
echo 69696 > serial # insted of echoing 6969 make use of this  'openssl rand -hex 16'
cd ../

openssl req -config intermediate-ca/config -new -key intermediate-ca/intermediateCa.key -sha256 -out intermediate-ca/csr/intermediate_Ca.csr
-# keep IntermiadateCA as commonName
# keep csr hadny, we can resign the certficate with same configuration once the cert is expired or  hv to need to rerquest new key

#sign the csr using rootPrivateKey
openssl ca -config ~/awcatorPKI/ca/config -extensions v3_intermediate_ca -days 3650 -notext -in intermediate-ca/csr/intermediate_Ca.csr -out intermediate-ca/certs/intermediateCa.crt

# if success, you should see some new index files and contents and serailFiles, newcerts contin the backup certificate which was issued now
# view the certifiate
openssl x509 -text -in intermediate-ca/certs/intermediateCa.crt -noout
```
![image](https://user-images.githubusercontent.com/54628909/236612333-87da8746-4365-47a5-a007-744019c2c5a3.png)
```
# Notice issuer and subject
```
#### Server Certificate generation
```
openssl req -key server/server.key -new  -sha256 -out server/my_Server.csr
-# give commonName as ur domain name, here used: accd.google.com
openssl ca -config ~/awcatorPKI/intermediate-ca/config -extensions server_cert -days 365 -notext -in server/my_Server.csr -out server/server.crt
# updates index, seraial, serai.old, newcerts
cat server/server.crt  intermediate-ca/certs/intermediateCa.crt > server/chain_server.crt
# for chain
cat server/server.crt  intermediate-ca/certs/intermediateCa.crt  ca/certs/ca.crt> server/full_chain_server.crt
# for chain
```

#### verifiy CustomPKI
```
# Add entry in DNS records or locally enter it in /etc/hosts
127.0.0.1 abcd.google.com
# run simple https server or do it via nginx (read nginx.md)
sudo openssl s_server -accept 443 -www -key server/server.key -cert server/server.crt -CAfile intermediate-ca/certs/intermediateCa.crt
curl https://abcd.google.com -k
workes beacuse curl ignore the trust, without -k it dsnt work because operating system dsnt trust the CA

to fix: Trust the ca system level
# cp ca/certs/ca.crt /etc/pki/trust/anchors/
# sudo cp ca/certs/ca.crt /usr/share/lib/ca-certificates/
sudo cp ca/certs/ca.crt /etc/ca-certificates/trust-source/anchors/
#sudo update-ca-certificates -v
sudo update-ca-trust -v
Now only your system trust the CA
curl https://abcd.google.com works
```
![image](https://user-images.githubusercontent.com/54628909/236613514-5053e9b8-d7bd-4d7f-961e-b5ce4937ee6f.png)
#### after trusting CA
![image](https://user-images.githubusercontent.com/54628909/236613900-c54fde5e-d2a5-4259-928f-18a8b938f895.png)

verify certificate status:
```diff
 openssl verify -CAfile ca/certs/ca.crt -untrusted intermediate-ca/certs/intermediateCa.crt server/server.crt
 # or
 ```
![image](https://github.com/awcator/DevOpsJourneyWithArchLinux/assets/54628909/a5b0c93f-f286-451e-9409-808c3adfc8fa)
![image](https://github.com/awcator/DevOpsJourneyWithArchLinux/assets/54628909/31b157fd-2d53-42df-b7ba-550c3203e598)
#### csr and CRL
simple CertificateSigning Request config file
```
[req]
req_extensions = san_extensions

[san_extensions]
subjectAltName = @alt_names

[alt_names]
DNS.1 = example.com
DNS.2 = www.example.com
otherName.0 = 1.2.3.4;UTF8:customvalue
otherName.1 = 1.2.3.5;UTF8:customvalue2
```
TO create csr: 
```
openssl req -new -sha256 -nodes -out out.csr -newkey rsa:2048 -keyout server.key -subj "/CN=awcator.com" -reqexts san_extensions -config ./csrConfig

openssl ca -extensions v3_intermediate_ca -config ca/config  -days 3650 -notext -in intermediate-ca/intermediate_Ca.csr -out intermediate-ca/intermediateCa.crt
 penssl ca -config intermediate-ca/config -extensions server_cert -days 365 -notext -in server2/my.csr -out server2/server.crt -verbose

```
to generate CRL:
```diff
# revoke cert
openssl ca -config ca/config -revoke ca/certs/intermediate-server-1.crt
or manully add entry in ca/index and generate CRL 

after anyone of both, rebuild the CRL
```
```
cat ca/index
R       220904031732Z   210904032109Z   01      unknown /C=IN/ST=India/O=Awcator Ltd/CN=Intermediate
V       220904031929Z           02      unknown /C=IN/ST=India/O=Awcator Ltd/CN=Intermediate1

faketime "last year" openssl ca -config ca/config -gencrl -crl_reason unspecified
openssl crl -in /root/tls/crl/rootca.crl -text -noout
https://www.golinuxcloud.com/revoke-certificate-generate-crl-openssl/
````

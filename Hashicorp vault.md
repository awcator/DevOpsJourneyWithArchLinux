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

#### 

# basics
setup postgres, read [postgresInstallation](url)
```
CREATE ROLE keycloak_user WITH LOGIN PASSWORD 'StrongKeycloakPass123';
CREATE DATABASE keycloak
  OWNER keycloak_user
  ENCODING 'UTF8'
  LC_COLLATE='en_US.UTF-8'
  LC_CTYPE='en_US.UTF-8'
  TEMPLATE template0;
ALTER ROLE keycloak_user CREATEDB;
# GRANT CONNECT ON DATABASE keycloak TO readonly_user;
```
```
pacman -S keycloak  #keycloak-26.3.0-1

/etc/keycloak/keycloak.conf
db=postgres
db-username=keycloak_user
db-password=StrongKeycloakPass123
db-url=jdbc:postgresql://localhost/keycloak
health-enabled=true
metrics-enabled=true
hostname=awcator
http-enabled=true

sudo systemctl start keycloak
#or
sudo /usr/bin/kc.sh -cf /etc/keycloak/keycloak.conf start --optimized

# go to masterrealm crate a permanent admin user by adding new user, with full roles
# Under Client Roles → choose realm-management
# Assign roles like: realm-admin, manage-users, view-users, etc.
```
# create a new relm link with ldap prod setup
```

```

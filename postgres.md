isntall:
```
sudo pacman -Syu
sudo pacman -S postgresql
postgres --version
su - postgres -c "initdb --locale en_US.UTF-8 -D '/var/lib/postgres/data'"
sudo systemctl start postgresql

Manual Start postgres: 
pg_ctl -D /var/lib/postgres/data -l logfile start
```
login
```
sudo -u postgres psql
CREATE USER <username> WITH ENCRYPTED PASSWORD ‘<password>’;
CREATE DATABASE <dbname>;
GRANT ALL PRIVILEGES ON DATABASE <dbname> TO username;
```
Enhancments:
```
yay -S pgcli
```
Uninstall
```
pacman -Rcns postgresql
```

# Getting started
```script
pacman -S postgresql
sudo -u postgres initdb --locale en_US.UTF-8 -D /var/lib/postgres/data
systemctl start postgresql
systemctl status postgresql
su - postgres
psql -c "alter user postgres with password 'admin'"
psql
CREATE DATABASE mydb;
\l
CREATE USER awcator WITH ENCRYPTED PASSWORD 'awcator_password';
\du;
ALTER USER awcator WITH SUPERUSER;
ALTER USER awcator WITH CREATEROLE CREATEDB REPLICATION
#or
GRANT ALL PRIVILEGES ON DATABASE mydb to awcator;
exit
# https://wiki.archlinux.org/title/PostgreSQL
# read https://www.atlantic.net/dedicated-server-hosting/how-to-install-and-use-postgresql-on-arch-linux/
# read https://stackoverflow.com/questions/66769407/how-to-grant-all-privileges-to-all-databases-in-postgres

#Configure PostgreSQL for Remote Access
vi /var/lib/postgres/data/postgresql.conf
listen_addresses = '0.0.0.0
vi /var/lib/postgres/data/pg_hba.conf' # and add at firstLine
host    all             all             all            password
sudo systemctl restart postgresql
sudo systemctl status postgresql
psql -U awcator -h localhost -p 5432 mydb


# enable logging
vi /var/lib/postgres/data/postgresql.conf
log_statement = 'all'
logging_collector = on
log_directory = '/tmp/pglogs/'

# /usr/bin/postgres -D /var/lib/postgres/data
# pg_ctl -D '‘/var/lib/postgres/data/’' -l logfile start
```
# Plv8 Extension Building and Installation
### Dockerfile
```
ARG PG_CONTAINER_VERSION=16
FROM docker.io/library/postgres:${PG_CONTAINER_VERSION}-alpine as builder

RUN set -ex \
  && apk --no-cache add git python3 build-base linux-headers clang15 llvm15 llvm16 cmake make pkgconfig postgresql-dev
ARG PLV8_BRANCH=r3.2
ENV PLV8_BRANCH=${PLV8_BRANCH}
ARG PLV8_VERSION=3.2.2
ENV PLV8_VERSION=${PLV8_VERSION}
RUN set -ex \
  && git clone --branch ${PLV8_BRANCH} --single-branch --depth 1 https://github.com/plv8/plv8 \
  && cd plv8 \
  && make \
  && strip plv8-${PLV8_VERSION}.so \
  && make install


FROM docker.io/library/postgres:${PG_CONTAINER_VERSION}-alpine

ARG PLV8_VERSION=3.2.2
ENV PLV8_VERSION=${PLV8_VERSION}
COPY --from=builder /usr/local/lib/postgresql/plv8* /usr/local/lib/postgresql/
COPY --from=builder /usr/local/lib/postgresql/bitcode/plv8-${PLV8_VERSION}/* /usr/local/lib/postgresql/bitcode/plv8-${PLV8_VERSION}/
COPY --from=builder /usr/local/share/postgresql/extension/plv8* /usr/local/share/postgresql/extension/


RUN mkdir -p /var/log/postgres \
  && touch /var/log/postgres/log /var/log/postgres/log.csv \
  && chown -R postgres /var/log/postgres

USER postgres

RUN ln -fs /dev/stderr /var/log/postgres/log
```
```
docker build -t plv8:latest . #takes up almost 2 hrs to build
docker run -it -u 0 --network=host plv8:latest bash

docker cp d9:/usr/local/lib/postgresql/plv8-3.2.2.so  . #d9 is containerID
docker cp d9:/usr/local/lib/postgresql/bitcode/plv8-3.2.2 . #d9 is containerID
docker exec d9 bash -c "mkdir -p /extension; cp -f /usr/local/share/postgresql/extension/plv* /extension"
docker cp d9:/extension . #d9 is containerID
```

```
create or replace function hello_world(name text)
returns text as $$

    let output = `Hello, ${name}!`;
    return output;

$$ language plv8;
```

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
log_filename = 'postgresql-%Y-%m-%d_%I:%M:%S %p.log'
log_file_mode = 0600 
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

sudo mv extension/*  /usr/share/postgresql/extension/
sudo mv plv8-3.2.2.so /usr/share/postgresql/
sudo mv plv8-3.2.2 /usr/share/postgresql/
sudo vim /usr/share/postgresql/extension/plv8.control
module_pathname = '/usr/share/postgresql/plv8-3.2.2'
pacman -S musl
sudo ln -sf /usr/lib/musl/lib/libc.so /usr/lib/libc.musl-x86_64.so.1
psql -U awcator -h localhost -p 5432 mydb
CREATE EXTENSION plv8;
#DROP EXTENSION plv8;
```
### some testing
```
DO $$ plv8.elog(NOTICE, 'this', 'is', 'inline', 'code'); $$ LANGUAGE plv8;

create or replace function hello_world(name text)
returns text as $$

    let output = `Hello, ${name}!`;
    return output;

$$ language plv8;
select * from hello_world('awcator');
```

###Mass entry
```
CREATE TABLE nodes
(
    id          BIGSERIAL UNIQUE                      NOT NULL,
    created_at  TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at  TIMESTAMPTZ                           NULL,
    deleted_at  TIMESTAMPTZ                           NULL,
    site_name   TEXT                                  NOT NULL,
    asset_name  TEXT                                  NOT NULL,
    last_backup TIMESTAMPTZ                           NULL,
    last_ping   TIMESTAMPTZ                           NULL,
    CONSTRAINT node_registration_primary_pkey PRIMARY KEY (id),
    UNIQUE (site_name, asset_name)
);
CREATE INDEX idx_node_registrations_deleted_at ON nodes USING btree (deleted_at);
CREATE INDEX  nodes_site_name_idx ON  nodes USING  btree (site_name);
CREATE INDEX  nodes_asset_name_idx ON  nodes USING  btree (asset_name);


CREATE TABLE migrations
(
    id            BIGSERIAL                             NOT NULL,
    created_at    TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at    TIMESTAMPTZ                           NULL,
    deleted_at    TIMESTAMPTZ                           NULL,
    type          TEXT                                  NOT NULL,
    site_name     TEXT                                  not null,
    asset_name    TEXT                                  not null,
    fir_name      TEXT                                  NULL,
    file_name     TEXT                                  NULL,
    patient_db_id INT8,
    study_db_id   INT8,
    series_db_id  INT8,
    file_num    INT8,
    status        INT                                   NOT NULL,
    size_bytes    INT8,
    digest        TEXT                                  NULL,
    s3_location   TEXT                                  NULL,
    s3_remapping_status INT  DEFAULT 0,
    PRIMARY KEY (id,file_name),
    UNIQUE (file_name)
) PARTITION BY HASH (file_name);

CREATE INDEX migrations_deleted_at_idx ON migrations USING btree (deleted_at);
CREATE INDEX migrations_created_date_idx ON migrations USING btree (created_at);
CREATE INDEX migrations_fir_name_idx ON migrations USING btree (fir_name);
CREATE INDEX migrations_file_name_idx ON migrations USING btree (file_name);
CREATE INDEX migrations_status_idx ON migrations USING btree (status);
CREATE INDEX  migrations_site_name_idx ON  migrations USING  btree (site_name);
CREATE INDEX  migrations_asset_name_idx ON  migrations USING  btree (asset_name);
CREATE INDEX  migrations_s3_remapping_status_idx ON  migrations USING  btree (s3_remapping_status);

-- Create 64 partitions
DO $$
BEGIN
FOR i IN 0..7 LOOP
        EXECUTE format('
            CREATE TABLE migrations_p%1$s
            PARTITION OF migrations
            FOR VALUES WITH (MODULUS 8, REMAINDER %1$s);
        ', i);
END LOOP;
END $$;```

DO $$
    DECLARE
        j INTEGER := 1;
    BEGIN
        WHILE j <= 10000 LOOP  -- Outer loop to create 100 batches
        DECLARE
            i INTEGER := 1;
            values_str TEXT := '';
        BEGIN
            WHILE i <= 1000 LOOP  -- Inner loop to create 1000 rows per batch
            -- Build the values string
                    values_str := values_str || '(' ||
                                  'DEFAULT,' ||  -- id (BIGSERIAL)
                                  'CURRENT_TIMESTAMP,' ||  -- created_at
                                  'NULL,' ||  -- updated_at
                                  'NULL,' ||  -- deleted_at
                                  '''migration_type'',' ||  -- type
                                  '''site_' || ((j - 1) * 1000 + i) % 100 || ''',' ||  -- site_name
                                  '''asset_' || ((j - 1) * 1000 + i) % 100 || ''',' ||  -- asset_name
                                  '''fir_' || i || ''',' ||  -- fir_name
                                  '''file_' || md5(random()::text || clock_timestamp()::text) || '.dcm'',' ||  -- file_name
                                  trunc(random() * 10000)::BIGINT || ',' ||  -- patient_db_id
                                  trunc(random() * 10000)::BIGINT || ',' ||  -- study_db_id
                                  trunc(random() * 10000)::BIGINT || ',' ||  -- series_db_id
                                  trunc(random() * 100)::BIGINT || ',' ||  -- file_num
                                  (ARRAY[0,1,2,3])[floor(random()*4+1)] || ',' ||  -- status
                                  trunc(random() * 100000000)::BIGINT || ',' ||  -- size_bytes
                                  '''digest_' || md5(random()::text) || ''',' ||  -- digest
                                  '''s3://bucket/' || md5(random()::text || clock_timestamp()::text) || ''',' ||  -- s3_location
                                  '0' ||  -- s3_remapping_status
                                  ')';

                    IF i < 1000 THEN
                        values_str := values_str || ',';
                    END IF;

                    i := i + 1;
                END LOOP;

            -- Insert into migrations table
            EXECUTE 'INSERT INTO migrations (id, created_at, updated_at, deleted_at, type, site_name, asset_name, fir_name, file_name, patient_db_id, study_db_id, series_db_id, file_num, status, size_bytes, digest, s3_location, s3_remapping_status) VALUES ' || values_str;

        END;
        j := j + 1;
            END LOOP;
    END $$;
```

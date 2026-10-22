<h1><span style="color:#7c3aed">Valkey Setup and Usage</span></h1>

## <span style="color:#2563eb">Install</span>

```bash
pacman -S valkey
```

## <span style="color:#2563eb">Configuration</span>

Edit <code>/etc/valkey/valkey.conf</code>:

```conf
bind 127.0.0.1 -::1
protected-mode yes
port 6379
tcp-backlog 511
timeout 0
tcp-keepalive 300
daemonize no
loglevel notice
logfile ""
databases 16
always-show-logo no
hide-user-data-from-log yes
set-proc-title yes
proc-title-template "{title} {listen-addr} {server-mode}"
locale-collate ""
stop-writes-on-bgsave-error yes
rdbcompression yes
rdbchecksum yes
rdb-version-check strict
dbfilename dump.rdb
rdb-del-sync-files no
dir /var/lib/valkey/
replica-serve-stale-data yes
replica-read-only yes
repl-diskless-sync yes
repl-diskless-sync-delay 5
repl-diskless-sync-max-replicas 0
repl-diskless-load disabled
dual-channel-replication-enabled no
repl-disable-tcp-nodelay no
replica-priority 100
acllog-max-len 128
lazyfree-lazy-eviction yes
lazyfree-lazy-expire yes
lazyfree-lazy-server-del yes
replica-lazy-flush yes
lazyfree-lazy-user-del yes
lazyfree-lazy-user-flush yes
oom-score-adj no
oom-score-adj-values 0 200 800
disable-thp yes
appendonly no
appendfilename "appendonly.aof"
appenddirname "appendonlydir"
appendfsync everysec
no-appendfsync-on-rewrite no
auto-aof-rewrite-percentage 100
auto-aof-rewrite-min-size 64mb
aof-load-truncated yes
aof-use-rdb-preamble yes
aof-timestamp-enabled no
commandlog-execution-slower-than 10000
commandlog-slow-execution-max-len 128
commandlog-request-larger-than 1048576
commandlog-large-request-max-len 128
commandlog-reply-larger-than 1048576
commandlog-large-reply-max-len 128
latency-monitor-threshold 0
notify-keyspace-events ""
hash-max-listpack-entries 512
hash-max-listpack-value 64
list-max-listpack-size -2
list-compress-depth 0
set-max-intset-entries 512
set-max-listpack-entries 128
set-max-listpack-value 64
zset-max-listpack-entries 128
zset-max-listpack-value 64
hll-sparse-max-bytes 3000
stream-node-max-bytes 4096
stream-node-max-entries 100
activerehashing yes
client-output-buffer-limit normal 0 0 0
client-output-buffer-limit replica 256mb 64mb 60
client-output-buffer-limit pubsub 32mb 8mb 60
hz 10
aof-rewrite-incremental-fsync yes
rdb-save-incremental-fsync yes
jemalloc-bg-thread yes
user default off
user awcator on >1234 ~* &* +@all
```

## <span style="color:#2563eb">Connect and authenticate</span>

```bash
valkey-cli --user awcator --askpass
```

<span style="color:#64748b">Enter the user's password when prompted.</span>

## <span style="color:#2563eb">Verify ACLs</span>

At the Valkey prompt, run:

```text
127.0.0.1:6379> ACL LIST
1) "user awcator on #03ac674216f3e15c761ee1a5e255f067953623c8b388b4459e13f978d7c846f4 ~* &* +@all"
2) "user default off resetchannels -@all"
```

## <span style="color:#2563eb">Test basic commands</span>

```text
127.0.0.1:6379> SET x 6
OK
127.0.0.1:6379> GET x
"6"
```

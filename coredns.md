coredns 
```
sudo /usr/bin/coredns -conf=/etc/coredns/Corefile

 $ catall /etc/coredns/Corefile 
. {
    errors
    health {
      lameduck 5s
    }
    hosts {
      192.168.29.113 google.com
      fallthrough
    }
    ready
    prometheus :9153
    forward . 1.1.1.1
    log
    cache 30
    loop
    reload
    loadbalance
}

```

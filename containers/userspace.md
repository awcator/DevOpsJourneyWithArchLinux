# userspace programs, UID mapping/emulating
```
sysctl kernel.unprivileged_userns_clone
#should be 1
$ id -u
1000
$ cat /etc/subuid
1000:100000:65536
#what this meeans is for the user id 1000 (localuser=you) , create sub user ids of size 65536 and map that to real UID from 100000
# which means
# namespaced uid=0, implies=realUID=1000=you
# namespaced uid=1. implies=realUID=100000
# namespaced uid=2. implies=realUID=100002
# why 65536? its Posix Standard, all posix systems/conainter expects linux machines to create upto 65536 UIDS,
# best example every posix systems nobody user has UID of 65534
$id nobody
# uid=65534(nobody) gid=65534(nobody) groups=65534(nobody)

echo "subid:	files"  >> /etc/nsswitch.conf
$ unshare --user --map-auto --map-root-user
# id -u
0
# cat /proc/self/uid_map

         0       1000          1

         1     100000      65535
# touch file; chown 1:1 file
# ls -ln --time-style=+ file
-rw-r--r-- 1 1 1 0  file
# exit
$ ls -ln --time-style=+ file
-rw-r--r-- 1 100000 100000 0  file
```
read https://man.archlinux.org/man/unshare.1.en

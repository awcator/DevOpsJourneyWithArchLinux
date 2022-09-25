 Quick Busybox pod
```
kubectl run busybox --image=busybox --restart=Never -it -- /bin/sh
#varient 1
kubectl run busybox3 --image=busybox --restart=Never -it -- /bin/sh -c "sleep 5;echo boo"
```

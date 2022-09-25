# Quick Busybox pod
```diff
kubectl run busybox --image=busybox --restart=Never -it -- /bin/sh
#varient 1
kubectl run busybox3 --image=busybox --restart=Never -- /bin/sh -c "sleep 5;echo boo"
```

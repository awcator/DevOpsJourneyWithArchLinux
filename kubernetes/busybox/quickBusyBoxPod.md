# Quick Busybox pod
```diff
kubectl run busybox --image=busybox --restart=Never -it -- /bin/sh
#varient 1
kubectl run busybox3 --image=busybox --restart=Never -- /bin/sh -c "sleep 5;echo boo"
```
## Convert previous pod craeteion into yaml format
```diff
kubectl run busybox3 --image=busybox --restart=Never --dry-run=client -o yaml -- /bin/sh -c "sleep 5;echo boo"
!yaml output
apiVersion: v1
kind: Pod
metadata:
  creationTimestamp: null
  labels:
    run: busybox3
  name: busybox3
spec:
  containers:
  - args:
    - /bin/sh
    - -c
    - sleep 5;echo boo
    image: busybox
    name: busybox3
    resources: {}
  dnsPolicy: ClusterFirst
  restartPolicy: Never
status: {}

```

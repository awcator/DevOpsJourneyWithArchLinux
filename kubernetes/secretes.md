## Creating simple secretes
```diff
apiVersion: v1
kind: Secret
metadata:
  name: app-secret
data:
  user: bXl1c2VyCg==
  password: bXlzdXBlcnBhc3N3b3JkCg==
  
!OR
kubectl create secret generic prod-db-secret --from-literal=username=produser --from-literal=password=Y4nys7f11

!OR 
# Create secrets from file -Certificates
kubectl create secret generic objectstore-cert --from-file=/tmp/mydomain.crt

## Attaching secrete to a pod
```diff
apiVersion: v1
kind: Pod
metadata:
  name: secret-test-pod
spec:
  containers:
    - name: busybox-to-display-secrets
      image: busybox
      command: ["sh", "-c", "export LOGIN=$(cat /etc/secret-volume/user);export PWD=$(cat /etc/secret-volume/password);while true; do echo hello $LOGIN your password is $PWD; sleep 10; done"]
      volumeMounts:
          # name must match the volume name below
          - name: secret-volume
            mountPath: /etc/secret-volume
  volumes:
    - name: secret-volume
      secret:
        secretName: app-secret
  restartPolicy: Never
  
!OR

```

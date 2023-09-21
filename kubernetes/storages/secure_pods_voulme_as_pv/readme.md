After installing make the storage class the default

kubectl patch storageclass local-path -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}' <br>
where gold is my storageclass
https://kubernetes.io/docs/tasks/administer-cluster/change-default-storage-class/

```diff
kubectl apply -f local_path_storage_class.yaml
kubectl apply -f pvc.yml
kubectl patch storageclass local-path -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
kubectl apply -f deploy
```

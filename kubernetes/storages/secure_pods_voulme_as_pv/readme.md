After installing make the storage class the default

kubectl patch storageclass gold -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}' <br>
where gold is my storageclass
https://kubernetes.io/docs/tasks/administer-cluster/change-default-storage-class/

## Create service account
```
apiVersion: v1
kind: ServiceAccount
metadata:
  name: awcator-secretes-reader

! To verify
kubectl get sa
```
## Create a role
```diff
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  # "namespace" omitted since ClusterRoles are not namespaced
  name: secret-reader
rules:
- apiGroups: [""]
  #
  # at the HTTP level, the name of the resource for accessing Secret
  # objects is "secrets"
  resources: ["secrets"]
  verbs: ["get", "watch", "list"]

!MORE INFO 
- apiGroups:
        - ""
        - apps
        - autoscaling
        - batch
        - extensions
        - policy
        - rbac.authorization.k8s.io
    resources:
      - pods
      - componentstatuses
      - configmaps
      - daemonsets
      - deployments
      - events
      - endpoints
      - horizontalpodautoscalers
      - ingress
      - jobs
      - limitranges
      - namespaces
      - nodes
      - pods
      - persistentvolumes
      - persistentvolumeclaims
      - resourcequotas
      - replicasets
      - replicationcontrollers
      - serviceaccounts
      - services
      verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
      
      !to verify
      kubectl get roles
      kubectl get clusterroles 
```
## Create a Rolebinding [ Attaching Role to ServiceAccount]
```
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: awcator-secrets-rolebinding
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: secret-reader
subjects:
- kind: ServiceAccount
  name: awcator-secretes-reader
```
## Create a pod and attach (busybox)

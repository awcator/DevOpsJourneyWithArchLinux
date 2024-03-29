
cd /tmp/
\rm -rf *
git clone https://github.com/aws/amazon-eks-pod-identity-webhook/
cd amazon-eks-pod-identity-webhook/
POD_IDENTITY_SERVICE_NAME=pod-identity-webhook
POD_IDENTITY_SECRET_NAME=pod-identity-webhook
POD_IDENTITY_SERVICE_NAMESPACE=kube-system
\rm -rf certs
mkdir -p certs
openssl req -x509 -newkey rsa:2048 -keyout certs/tls.key -out certs/tls.crt -days 3095 -nodes -subj "/CN=$POD_IDENTITY_SERVICE_NAME.$POD_IDENTITY_SERVICE_NAMESPACE.svc" -addext "subjectAltName = DNS:$POD_IDENTITY_SERVICE_NAME.$POD_IDENTITY_SERVICE_NAMESPACE.svc,DNS:$POD_IDENTITY_SERVICE_NAME,DNS:$POD_IDENTITY_SERVICE_NAME.$POD_IDENTITY_SERVICE_NAMESPACE,DNS:$POD_IDENTITY_SERVICE_NAME.$POD_IDENTITY_SERVICE_NAMESPACE.svc.cluster.local" 
kubectl delete secret $POD_IDENTITY_SECRET_NAME -n $POD_IDENTITY_SERVICE_NAMESPACE
kubectl create secret generic $POD_IDENTITY_SECRET_NAME --from-file=./certs/tls.crt --from-file=./certs/tls.key --namespace=$POD_IDENTITY_SERVICE_NAMESPACE

# Generate the keypair
PRIV_KEY="sa-signer.key"
PUB_KEY="sa-signer.key.pub"
PKCS_KEY="sa-signer-pkcs8.pub"
# Generate a key pair
ssh-keygen -t rsa -b 2048 -f $PRIV_KEY -m pem
# convert the SSH pubkey to PKCS8
ssh-keygen -e -m PKCS8 -f $PUB_KEY > $PKCS_KEY

# Create S3 bucket with a random name. Feel free to set your own name here
export S3_BUCKET=${S3_BUCKET:-oidc-test-$(cat /dev/random | LC_ALL=C tr -dc "[:alpha:]" | tr '[:upper:]' '[:lower:]' | head -c 32)}
# Create the bucket if it doesn't exist
AWS_REGION=eu-central-1
_bucket_name=$(aws s3api list-buckets  --query "Buckets[?Name=='$S3_BUCKET'].Name | [0]" --out text)
if [ $_bucket_name == "None" ]; then
    if [ "$AWS_REGION" == "us-east-1" ]; then
        aws s3api create-bucket --bucket $S3_BUCKET
    else
        aws s3api create-bucket --bucket $S3_BUCKET --create-bucket-configuration LocationConstraint=$AWS_REGION
    fi
fi
echo "export S3_BUCKET=$S3_BUCKET"
export HOSTNAME=s3.$AWS_REGION.amazonaws.com
export ISSUER_HOSTPATH=$HOSTNAME/$S3_BUCKET

cat <<EOF > discovery.json
{
    "issuer": "https://$ISSUER_HOSTPATH",
    "jwks_uri": "https://$ISSUER_HOSTPATH/keys.json",
    "authorization_endpoint": "urn:kubernetes:programmatic_authorization",
    "response_types_supported": [
        "id_token"
    ],
    "subject_types_supported": [
        "public"
    ],
    "id_token_signing_alg_values_supported": [
        "RS256"
    ],
    "claims_supported": [
        "sub",
        "iss"
    ]
}
EOF

go run ./hack/self-hosted/main.go -key $PKCS_KEY  | jq '.keys += [.keys[0]] | .keys[1].kid = ""' > keys.json

# Disable all block public access settings
aws s3api put-public-access-block --bucket $S3_BUCKET --public-access-block-configuration "BlockPublicAcls=false,IgnorePublicAcls=false,BlockPublicPolicy=false,RestrictPublicBuckets=false"


# sign in to console and make the bucket public acces , give ACL permission
# https://s3.console.aws.amazon.com/s3/home?region=eu-central-1#

# add this policy
{
  "Id": "Policy1689219893539",
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "Stmt1689219892498",
      "Action": "s3:*",
      "Effect": "Allow",
      "Resource": "arn:aws:s3:::oidc-test-ojopblcldcmgrbughysamnnmeggoflcf",
      "Principal": "*"
    }
  ]
}

# arn:aws:s3:::oidc-test-ojopblcldcmgrbughysamnnmeggoflcf == your s3 bucket ARN


aws s3 cp --acl public-read ./discovery.json s3://$S3_BUCKET/.well-known/openid-configuration

aws s3 cp --acl public-read ./keys.json s3://$S3_BUCKET/keys.json

CA_THUMBPRINT=$(openssl s_client -connect s3.amazonaws.com:443 -servername s3.amazonaws.com -showcerts < /dev/null 2>/dev/null | openssl x509 -in /dev/stdin -sha1 -noout -fingerprint | cut -d '=' -f 2 | tr -d ':')

aws iam create-open-id-connect-provider --url https://$ISSUER_HOSTPATH --thumbprint-list $CA_THUMBPRINT  --client-id-list sts.amazonaws.com | jq
echo "The service-account-issuer as below:"
echo "https://$ISSUER_HOSTPATH"

# now exec into master nodes.
# lxc exec controller-1 -- bash
# this was my original apiserver config
# /usr/local/bin/kube-apiserver --advertise-address=172.16.0.3 --allow-privileged=true --apiserver-count=1 --audit-log-maxage=30 --audit-log-maxbackup=3 --audit-log-maxsize=100 --audit-log-path=/var/log/audit.log --authorization-mode=Node,RBAC --bind-address=0.0.0.0 --client-ca-file=/var/lib/kubernetes/ca.pem --enable-admission-plugins=NamespaceLifecycle,NodeRestriction,LimitRanger,ServiceAccount,DefaultStorageClass,ResourceQuota --enable-swagger-ui=true --etcd-cafile=/var/lib/kubernetes/ca.pem --etcd-certfile=/var/lib/kubernetes/kubernetes.pem --etcd-keyfile=/var/lib/kubernetes/kubernetes-key.pem --etcd-servers=https://172.16.0.3:2379 --event-ttl=1h --experimental-encryption-provider-config=/var/lib/kubernetes/encryption-config.yaml --kubelet-certificate-authority=/var/lib/kubernetes/ca.pem --kubelet-client-certificate=/var/lib/kubernetes/kubernetes.pem --kubelet-client-key=/var/lib/kubernetes/kubernetes-key.pem --runtime-config api/all=true --service-account-key-file=/var/lib/kubernetes/service-account.pem --service-cluster-ip-range=10.32.0.0/24 --service-node-port-range=30000-32767 --tls-cert-file=/var/lib/kubernetes/kubernetes.pem --tls-private-key-file=/var/lib/kubernetes/kubernetes-key.pem --service-account-key-file=/var/lib/kubernetes/service-account.pem --service-account-signing-key-file=/var/lib/kubernetes/service-account-key.pem --service-account-issuer=https://172.16.0.2:6443 --v=2

# added these extra
/usr/local/bin/kube-apiserver --advertise-address=172.16.0.3 --allow-privileged=true --apiserver-count=1 --audit-log-maxage=30 --audit-log-maxbackup=3 --audit-log-maxsize=100 --audit-log-path=/var/log/audit.log --authorization-mode=Node,RBAC --bind-address=0.0.0.0 --client-ca-file=/var/lib/kubernetes/ca.pem --enable-admission-plugins=NamespaceLifecycle,NodeRestriction,LimitRanger,ServiceAccount,DefaultStorageClass,ResourceQuota --enable-swagger-ui=true --etcd-cafile=/var/lib/kubernetes/ca.pem --etcd-certfile=/var/lib/kubernetes/kubernetes.pem --etcd-keyfile=/var/lib/kubernetes/kubernetes-key.pem --etcd-servers=https://172.16.0.3:2379 --event-ttl=1h --experimental-encryption-provider-config=/var/lib/kubernetes/encryption-config.yaml --kubelet-certificate-authority=/var/lib/kubernetes/ca.pem --kubelet-client-certificate=/var/lib/kubernetes/kubernetes.pem --kubelet-client-key=/var/lib/kubernetes/kubernetes-key.pem --runtime-config api/all=true --service-account-key-file=/var/lib/kubernetes/service-account.pem --service-cluster-ip-range=10.32.0.0/24 --service-node-port-range=30000-32767 --tls-cert-file=/var/lib/kubernetes/kubernetes.pem --tls-private-key-file=/var/lib/kubernetes/kubernetes-key.pem --service-account-key-file=/var/lib/kubernetes/service-account.pem --service-account-signing-key-file=/var/lib/kubernetes/service-account-key.pem --service-account-issuer=https://172.16.0.2:6443 --v=2 --service-account-key-file=/tmp/sa-signer-pkcs8.pub --service-account-signing-key-file=/tmp/sa-signer.key  --api-audiences=sts.amazonaws.com --service-account-issuer=https://s3.eu-central-1.amazonaws.com/oidc-test-ojopblcldcmgrbughysamnnmeggoflcf 

# lxc file push sa-signer-pkcs8.pub  controller-1/root
# lxc file push sa-signer.key  controller-1/root

# lxc exec controller-1 bash
# vi /etc/systemd/system/kube-apiserver.service
# systemctl daemon-reload
# systemctl restart kube-apiserver.service


#https://cert-manager.io/docs/installation/
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.12.0/cert-manager.yaml
k get pods -n cert-manager
#create pod identitity webhook
make cluster-up IMAGE=amazon/amazon-eks-pod-identity-webhook:latest 

k get pods


# kubernetes side SA
https://s3.eu-central-1.amazonaws.com/oidc-test-ojopblcldcmgrbughysamnnmeggoflcf 
ISSUER_URL=http://$ISSUER_HOSTPATH
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
PROVIDER_ARN="arn:aws:iam::$ACCOUNT_ID:oidc-provider/$ISSUER_HOSTPATH"
ROLE_NAME=s3-echoer2
AWS_DEFAULT_REGION=$(aws configure get region)
AWS_DEFAULT_REGION=${AWS_DEFAULT_REGION:-eu-central-1}
cat > irp-trust-policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "$PROVIDER_ARN"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "${ISSUER_HOSTPATH}:sub": "system:serviceaccount:default:${ROLE_NAME}"
        }
      }
    }
  ]
}
EOF
aws iam create-role --role-name $ROLE_NAME --assume-role-policy-document file://irp-trust-policy.json
aws iam update-assume-role-policy --role-name $ROLE_NAME --policy-document file://irp-trust-policy.json
S3_ROLE_ARN=$(aws iam get-role --role-name $ROLE_NAME --query Role.Arn --output text)
aws iam attach-role-policy --role-name $ROLE_NAME --policy-arn arn:aws:iam::aws:policy/AmazonS3FullAccess

# ./deploy-s3-echoer-job.sh https://s3.eu-central-1.amazonaws.com/oidc-test-ojopblcldcmgrbughysamnnmeggoflcf
kubectl create sa s3-echoer2
kubectl annotate sa s3-echoer2 eks.amazonaws.com/role-arn=$S3_ROLE_ARN

cat > testCreds.yaml << EOF
apiVersion: batch/v1
kind: Job
metadata:
  name: s3-echoer2
spec:
  template:
    spec:
      serviceAccountName: s3-echoer2
      containers:
      - name: main
        image: ubuntu:latest
        command:
        - "sh"
        - "-c"
        - "apt update &&  DEBIAN_FRONTEND=noninteractive apt install -y awscli && aws s3 ls"
        env:
        - name: AWS_DEFAULT_REGION
          value: "eu-central-1"
        - name: ENABLE_IRP
          value: "true"
      restartPolicy: Never
EOF

kubectl apply -f testCreds.yaml 
# manual verification
# then
# getinside pod and exec and take the token
# get the token base64 decode it and save it somewhere else in /tmp/token
    
credentials=$(aws sts assume-role-with-web-identity --role-arn "$AWS_ROLE_ARN" --role-session-name "das" --web-identity-token "file:///tmp/token")
access_key=$(echo "$credentials" | jq -r .Credentials.AccessKeyId)
secret_key=$(echo "$credentials" | jq -r .Credentials.SecretAccessKey)
session_token=$(echo "$credentials" | jq -r .Credentials.SessionToken)

# Set the AWS CLI configuration with the temporary credentials
aws configure set aws_access_key_id "$access_key"
aws configure set aws_secret_access_key "$secret_key"
aws configure set aws_session_token "$session_token" 

# Run your AWS CLI command
aws s3 ls


# Refernces
# https://github.com/aws/amazon-eks-pod-identity-webhook/blob/master/SELF_HOSTED_SETUP.md
# https://github.com/smalltown/aws-irsa-example/compare/master...Cytrian:aws-irsa-example:master

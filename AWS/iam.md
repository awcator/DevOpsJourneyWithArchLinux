Get current user details:
```
aws opsworks --region eu-central-1 describe-my-user-profile
```
Get permissions attacehed to the user: <br>
```
aws iam list-attached-user-policies --user-name <myName>
```
Get all permmissions attached to instance profile
```
aws iam get-instance-profile --instance-profile-name nodes.awcator.com
```
Get policies details for the running Ec2 instance:
```
TOKEN=`curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600"` && curl -H "X-aws-ec2-metadata-token: $TOKEN" -v http://169.254.169.254/latest/meta-data/iam/info
```

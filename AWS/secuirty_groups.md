**Delete all rules from the given secuirty group:**

```
groupId="your group-id"
json=`aws ec2 describe-security-groups --group-id $groupId --query "SecurityGroups[0].IpPermissions"`
aws ec2 revoke-security-group-ingress --cli-input-json "{\"GroupId\": \"$groupId\", \"IpPermissions\": $json}"
```

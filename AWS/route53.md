Deletion of Records from hostedZones:
```
HostedZoneID=<myhosted-zone-id>
json_data=$(aws route53 --output json list-resource-record-sets --hosted-zone-id $HostedZoneID --query 'ResourceRecordSets[?Name==`bastions.awcator.in.`]'|jq -r '.[]')
echo "Deleting the record"
aws route53 change-resource-record-sets --hosted-zone-id $HostedZoneID  --change-batch  "{\"Changes\":[{\"Action\":\"DELETE\",\"ResourceRecordSet\":$json_data}]}"
#json looks like this:
{"Changes":[{"Action":"DELETE","ResourceRecordSet":{"Name":"bastions.awcator.in.","Type":"A","TTL":300,"ResourceRecords":[{"Value":"100.64.17.250"}]}     }]}
```

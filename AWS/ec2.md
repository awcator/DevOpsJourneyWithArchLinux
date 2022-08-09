** Creating simple Windows Ec2 instance **
```
aws ec2 create-key-pair --key-name AwcatorKeyPair --query 'KeyMaterial' --output text > AwcatorKeyPair.pem
aws ec2 create-security-group --group-name my-sg --description "My security group" --vpc-id vpc-0e22f0f22622bd55a
sg=sg-0d25f90d97a39e436
aws ec2 authorize-security-group-ingress --group-id $sg --protocol tcp --port 3389 --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --group-id $sg --protocol tcp --port 22 --cidr 0.0.0.0/0

#create UserData file as follows to set the password
$cat userdata.txt
<powershell>
net user Administrator Welc0me@123
</powershell>

aws ec2 run-instances --image-id ami-0ffb52f759787ce37 --count 1 --instance-type t3.micro --key-name AwcatorKeyPair   --user-data file:///tmp/winodws/userdata.txt --region eu-central-1 --security-group-ids $sg --subnet-id subnet-033ad8caa30f904b8
#linux AMI
aws ec2 run-instances --image-id  ami-057fb6ca30447d5c7 --count 1 --instance-type t3.micro --key-name "kubernetes.awcator.com-88:58:48:d7:90:30:33:52:58:94:c7:68:12:55:ba:4a"  --user-data userdata.txt --region eu-central-1 --security-group-ids $sg --subnet-id subnet-033ad8caa30f904b8

#if password is no set? password can be retrived using private key as follows: 
aws ec2 get-password-data --instance-id  i-0324ffd2cf11bf363 --priv-launch-key AwcatorKeyPair.pem 
```

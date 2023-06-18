# Setup LUKS on /dev/sda7
```
sudo pacman -S cryptsetup
# erase the disk
sudo dd if=/dev/zero of=/dev/sda7 bs=1M status=progress
sudo umount /dev/sda7
# read the first 16MiB of data to see what kind of partion is that
sudo dd if=/dev/sda7
```
![image](https://github.com/awcator/DevOpsJourneyWithArchLinux/assets/54628909/a50818f8-5847-47f1-88c4-05056c6cd8d4)
```
# overwrite the partion type with LUKS type
sudo cryptsetup luksFormat /dev/sda7
# remeber the password
# verify the partion type
sudo dd if=/dev/sda7|head
# open the encryped partion
sudo cryptsetup open /dev/sda7 myencryptedpartition
# /dev/mapper/myencryptedpartition located at
# create a file system on it
sudo mkfs.ext4 /dev/mapper/myencryptedpartition
# create some mountpoint to mount cnryped partion
sudo mkdir /mnt/myencryptedpartition
sudo mount /dev/mapper/myencryptedpartition /mnt/myencryptedpartition
```
# close LUKS
```
sudo umount /mnt/myencryptedpartition
sudo cryptsetup close myencryptedpartition 
```
# Luks without headers in partition
![image](https://github.com/awcator/DevOpsJourneyWithArchLinux/assets/54628909/07bc799a-ffac-4bbb-8b86-f62aa338cf4e)
LUKS enrypt and decrypts the file contents using the masterKey, offcrouse masterKey is dervied key from the passPhrase using some encryption algo.
It is still safer to exclude that header info from the disk, so to encrypt and to decrypt you now need both header and passphtrase.
read : https://linuxconfig.org/how-to-use-luks-with-a-detached-header
```
# view LUKS headers info, eye friendly way
sudo cryptsetup luksDump /dev/sdb
sudo cryptsetup luksHeaderBackup /dev/sda7 --header-backup-file ~/luksHB.img

# rewrite disk with zeros
cd /tmp/
sudo dd if=/dev/zero of=/dev/sda7 bs=1M status=progress
sudo cryptsetup luksFormat --header mybk /dev/sda7
sudo dd if=/dev/sda7|head # should show empty as there is no content , and headers are outisde
sudo cryptsetup open --header /tmp/mybk /dev/sda7 myencryptedpartition
sudo mkfs.ext4 /dev/mapper/myencryptedpartition
sudo dd if=/dev/sda7|head # now contains ext4 realted info
sudo mount /dev/mapper/myencryptedpartition /mnt/myencryptedpartition

```
It is possible still  we can attach back headers to partion using
```
sudo cryptsetup luksHeaderRestore /dev/sda7 --header-backup-file /path/to/myheaderbackup.img

```

# Nuke the partition
```
# sometimes things go wrong, insted of writing entrie disk with zeros, for quick, just erase first 16MiB, usally this contains  filesystem detaisl,partition details
dd if=/dev/zero of=/dev/sda7 bs=4096 count=4096
```

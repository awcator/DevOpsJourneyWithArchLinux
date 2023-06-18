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

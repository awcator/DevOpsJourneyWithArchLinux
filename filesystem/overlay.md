# Overlay filesystem
An overlay filesystem can monitor what files got affected by the process. 
it takes the READonly directory as lowerDIR and any new changes will be written into upperDir.
primarily used in docker.
#### load overlay into the kernel: 
```
sudo modprobe overlay
```
#### demonstration of overlay:
```diff
mkdir lowerdir upperdir merged
echo "This is a lower file" > lowerdir/file.txt
sudo mount -t overlay overlay -o lowerdir=lowerdir,upperdir=upperdir,workdir=merged merged

# mount command can be used to verify
mount

#working of overlay
echo "This is an upper file" > merged/file.txt
# actual file is writtened in upperdir/
# lowerdirs/file.txt remains as it is

# unmount
sudo umount merged
```

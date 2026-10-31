#!/usr/bin/env bash

SSD1='/dev/disk/by-id/ata-MTFDDAK512TBN-1AR1ZABHA_UFZMT01J1AGPW4'
SSD2='/dev/disk/by-id/ata-MTFDDAK512TBN-1AR1ZABHA_UFZMT01J1AGQPH'
HDD1='/dev/disk/by-id/ata-ST4000DM004-2CV104_ZFN3P7XE'
HDD2='/dev/disk/by-id/ata-ST4000DM004-2U9104_ZTT3RLNM'
HDD3='/dev/disk/by-id/ata-ST4000DM004-2U9104_ZTT3S0T7'
HDD4='/dev/disk/by-id/ata-ST4000DM004-2U9104_ZTT3S1Z3'
MNT='/mnt'
SWAP_GB=32

wait_for_device() {
  local device=$1
  echo "Waiting for device: $device ..."
  while [[ ! -e $device ]]; do
    sleep 1
  done
  echo "Device $device is ready."
}

nix-env -iA nixos.gptfdisk

swapoff --all
udevadm settle

wait_for_device $SSD1
wait_for_device $SSD2

wipefs -a $SSD1
wipefs -a $SSD2

sgdisk --zap-all $SSD1
sgdisk --zap-all $SSD2

sgdisk -n1:1M:+1G         -t1:EF00 -c1:BOOT1 $SSD1
sgdisk -n2:0:+"$SWAP_GB"G -t2:8200 -c2:SWAP1 $SSD1
sgdisk -n3:0:0            -t3:BF00 -c3:ROOT1 $SSD1
partprobe -s $SSD1
udevadm settle
wait_for_device ${SSD1}-part3

sgdisk -n1:1M:+1G         -t1:EF00 -c1:BOOT2 $SSD2
sgdisk -n2:0:+"$SWAP_GB"G -t2:8200 -c2:SWAP2 $SSD2
sgdisk -n3:0:0            -t3:BF00 -c3:ROOT2 $SSD2
partprobe -s $SSD2
udevadm settle
wait_for_device ${SSD2}-part3

zpool create -f -o ashift=12 -o autotrim=on -R "$MNT" -O acltype=posixacl -O canmount=off -O dnodesize=auto -O normalization=formD -O relatime=on -O xattr=sa -O mountpoint=none rpool mirror ${SSD1}-part3 ${SSD2}-part3

zfs create -o canmount=noauto -o mountpoint=legacy rpool/root
mount -o X-mount.mkdir -t zfs rpool/root "$MNT"

zfs create -o mountpoint=legacy -o quota=100G rpool/home
zfs create -o mountpoint=legacy               rpool/nix
zfs create -o mountpoint=legacy               rpool/tmp
zfs create -o mountpoint=legacy -o quota=100G rpool/var

mount -o X-mount.mkdir -t zfs rpool/home "$MNT"/home
mount -o X-mount.mkdir -t zfs rpool/nix  "$MNT"/nix
mount -o X-mount.mkdir -t zfs rpool/tmp  "$MNT"/tmp
mount -o X-mount.mkdir -t zfs rpool/var  "$MNT"/var

mkfs.vfat -F 32 -n BOOT1 "$SSD1"-part1
mkfs.vfat -F 32 -n BOOT2 "$SSD2"-part1
mkswap -L SWAP1 "$SSD1"-part2
mkswap -L SWAP2 "$SSD2"-part2

mount -t vfat -o fmask=0077,dmask=0077,iocharset=iso8859-1,X-mount.mkdir -L BOOT1 "$MNT"/boot

swapon -L SWAP1
swapon -L SWAP2

wait_for_device $HDD1
wait_for_device $HDD2
wait_for_device $HDD3
wait_for_device $HDD4

wipefs -a $HDD1
wipefs -a $HDD2
wipefs -a $HDD3
wipefs -a $HDD4

sgdisk --zap-all $HDD1
sgdisk --zap-all $HDD2
sgdisk --zap-all $HDD3
sgdisk --zap-all $HDD4

sgdisk -n1:0:0 -t1:BF00 -c1:DATA1 $HDD1
sgdisk -n1:0:0 -t1:BF00 -c1:DATA2 $HDD2
sgdisk -n1:0:0 -t1:BF00 -c1:DATA3 $HDD3
sgdisk -n1:0:0 -t1:BF00 -c1:DATA4 $HDD4
udevadm settle

wait_for_device ${HDD1}-part1
wait_for_device ${HDD2}-part1
wait_for_device ${HDD3}-part1
wait_for_device ${HDD4}-part1

mkdir -p "$MNT"/data

zpool create -f -o ashift=12 -o autotrim=on -O acltype=posixacl -O xattr=sa -O dnodesize=auto -O compression=lz4 -O normalization=formD -O relatime=on -O mountpoint=none -R "$MNT" dpool raidz ${HDD1}-part1 ${HDD2}-part1 ${HDD3}-part1 ${HDD4}-part1

zfs create -o canmount=noauto -o mountpoint=legacy dpool/data
mount -o X-mount.mkdir -t zfs dpool/data "$MNT"/data

zfs create -o mountpoint=legacy -o quota=500G dpool/data/attic
zfs create -o mountpoint=legacy -o quota=200G dpool/data/audiobooks
zfs create -o mountpoint=legacy               dpool/data/backup
zfs create -o mountpoint=legacy               dpool/data/charbogen
zfs create -o mountpoint=legacy               dpool/data/forgejo
zfs create -o mountpoint=legacy -o quota=1T   dpool/data/immich
zfs create -o mountpoint=legacy -o quota=3T   dpool/data/jellyfin
zfs create -o mountpoint=legacy -o quota=500G dpool/data/jirafeau
zfs create -o mountpoint=legacy               dpool/data/mail
zfs create -o mountpoint=legacy -o quota=500G dpool/data/matrix-synapse
zfs create -o mountpoint=legacy               dpool/data/maubot
zfs create -o mountpoint=legacy -o quota=3T   dpool/data/nextcloud

mount -o X-mount.mkdir -t zfs dpool/data/attic          "$MNT"/data/attic
mount -o X-mount.mkdir -t zfs dpool/data/audiobooks     "$MNT"/data/audiobooks
mount -o X-mount.mkdir -t zfs dpool/data/backup         "$MNT"/data/backup
mount -o X-mount.mkdir -t zfs dpool/data/charbogen      "$MNT"/data/charbogen
mount -o X-mount.mkdir -t zfs dpool/data/forgejo        "$MNT"/data/forgejo
mount -o X-mount.mkdir -t zfs dpool/data/immich         "$MNT"/data/immich
mount -o X-mount.mkdir -t zfs dpool/data/jellyfin       "$MNT"/data/jellyfin
mount -o X-mount.mkdir -t zfs dpool/data/jirafeau       "$MNT"/data/jirafeau
mount -o X-mount.mkdir -t zfs dpool/data/mail           "$MNT"/data/mail
mount -o X-mount.mkdir -t zfs dpool/data/matrix-synapse "$MNT"/data/matrix-synapse
mount -o X-mount.mkdir -t zfs dpool/data/maubot         "$MNT"/data/maubot
mount -o X-mount.mkdir -t zfs dpool/data/nextcloud      "$MNT"/data/nextcloud

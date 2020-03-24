#!/bin/bash

# based on https://wiki.libvirt.org/page/Live-disk-backup-with-active-blockcommit

# on debian buster, set security_driver to "none" in /etc/libvirt/qemu.conf

# ./kvm-backup.sh /root/backup/ test 2 1>/dev/null 2>&1

BACKUP_DOMAIN=$2
BACKUP_DATE=`date +%Y%m%d%H%M%S`
BACKUP_PATH=${1%/}/$2/$BACKUP_DATE
BACKUP_MAX_COUNT=$3
DISK_TARGET=`virsh domblklist $BACKUP_DOMAIN --details | grep disk | awk '{print $3}'`
DISK_IMAGE=`virsh domblklist $BACKUP_DOMAIN --details | grep disk | awk '{print $4}'`
DISK_DISKSPEC=
DISK_IMAGE_SNAPSHOT=

ls -r1 -d ${1%/}/$2/* | grep -E ^${1%/}/$2/[0-9]{14}$ | tail +$BACKUP_MAX_COUNT | xargs rm -rf

mkdir -p $BACKUP_PATH

if [ `virsh domstate $BACKUP_DOMAIN` = "running" ]; then
    for x in $DISK_TARGET; do DISK_DISKSPEC="$DISK_DISKSPEC --diskspec $x,snapshot=external"; done
    virsh snapshot-create-as --domain $BACKUP_DOMAIN $BACKUP_DATE $DISK_DISKSPEC --no-metadata --disk-only --atomic
    DISK_IMAGE_SNAPSHOT=`virsh domblklist $BACKUP_DOMAIN --details | grep disk | awk '{print $4}'`
fi

for x in $DISK_IMAGE; do cp $x $BACKUP_PATH/`basename $x`; done

if [ `virsh domstate $BACKUP_DOMAIN` = "running" ]; then
    for x in $DISK_TARGET; do virsh blockcommit $BACKUP_DOMAIN $x --active --verbose --pivot; done
    for x in $DISK_IMAGE_SNAPSHOT; do rm -rf $x; done
fi

virsh dumpxml $BACKUP_DOMAIN > $BACKUP_PATH/$BACKUP_DOMAIN.xml

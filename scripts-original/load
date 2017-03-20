#!/usr/bin/env bash

set -e

HOURS=$1
DIR=$(dirname $0)
KEY=$DIR/id_rsa

if [ -z $HOURS ]; then
  HOURS=1
fi

/usr/bin/ssh-add -D
/usr/bin/ssh-add -t ${HOURS}H $KEY
/usr/sbin/diskutil umount force $DIR

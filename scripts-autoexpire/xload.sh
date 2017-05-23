#!/usr/bin/env bash

HOURS="$1";
ABSDIR="$(cd "$(dirname "$0")";pwd)";
KEY="${SSH_KEY_FILE:-$ABSDIR/id_rsa}";
KEEP="$2";

if [[ "$HOURS" == *"help"* ]] || [[ "$HOURS" == *"?"* ]]; then
  cat <<END
Usage: $0 [<hours_to_keep_key>] [keep]

  Temporarily installs the SSH key from the disk drive then optionally
  unmounts the drive.

Parameters:

  hours_to_keep_key     Integer number of hours to keep key installed
                        (defaults to loading key until 6:20pm local time)
  keep                  If specified, will not try to unmount the volume
                        (unmounting is only attempted if the path begins
                        with /Volumes/)

END
  exit;
fi;

if [[ "$HOURS" == *"k"* ]]; then
  KEEP="$HOURS";
  HOURS="";
fi;

if [[ -z "$HOURS" ]]; then
  MIN_LIFE_S=600;
  END_OF_DAY="$(date -v18H -v20M -v0S "+%s")";
  NOW="$(date "+%s")";
  (( SECONDS = "$END_OF_DAY" - "$NOW" ));
  if (( "$SECONDS" < "$MIN_LIFE_S" )); then
    SECONDS="$MIN_LIFE_S";
  fi;
else
  (( SECONDS = "$HOURS" * 3600 ));
fi;

/usr/bin/ssh-add -D;
/usr/bin/ssh-add -t "${SECONDS}" "$KEY";

if [[ "$KEEP" != *"k"* ]] && [[ "$(echo "$ABSDIR" | cut -d'/' -f-2)" == "/Volumes" ]]; then
  /usr/sbin/diskutil umount force "$(echo "$ABSDIR" | cut -d'/' -f-3)";
fi;

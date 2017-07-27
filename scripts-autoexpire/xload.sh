#!/usr/bin/env bash

# Copyright (C) 2017-Present Pivotal Software, Inc. All rights reserved.
# This program and the accompanying materials are made available under
# the terms of the under the Apache License, Version 2.0 (the "License”);
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# http://www.apache.org/licenses/LICENSE-2.0
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

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

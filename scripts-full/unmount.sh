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

ABSDIR="$(cd "$(dirname "$0")";pwd)";

if [[ "$(echo "$ABSDIR" | cut -d'/' -f-2)" == "/Volumes" ]]; then
	VOLUME="$(echo "$ABSDIR" | cut -d'/' -f-3)";
	VOLUME_NAME="$(echo "$VOLUME" | cut -d'/' -f3)";
	DISK="$(diskutil list external physical | grep " $VOLUME_NAME " | tr -s ' ' | cut -f7 -d' ')";

	/usr/sbin/diskutil unmount force "$VOLUME";

	# Unmount whole disk if partitioned
	if /usr/sbin/diskutil list "$DISK" >/dev/null 2>&1; then
		/usr/sbin/diskutil unmountDisk "$DISK";
	fi;
else
	echo "Not in /Volumes/; Not ejecting.";
fi;

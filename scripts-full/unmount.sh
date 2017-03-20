#!/usr/bin/env bash

ABSDIR="$(cd "$(dirname "$0")";pwd)";

if [[ "$(echo "$ABSDIR" | cut -d'/' -f-2)" == "/Volumes" ]]; then
	/usr/sbin/diskutil umount force "$(echo "$ABSDIR" | cut -d'/' -f-3)";
else
	echo "Not in /Volumes/; Not ejecting.";
fi;

#!/usr/bin/env bash

ABSDIR="$(cd "$(dirname "$0")";pwd)";

if [[ "$1" == *"help"* ]] || [[ "$1" == *"?"* ]]; then
  cat <<END
Usage: $0 [<initials> [<email>]]

  Adds the given details to the git_authors file.

Parameters:

  initials              The initials for the user to add
  email                 The email address for the user to add

END
	exit 0;
fi;

if [[ -n "$1" ]]; then
	USER_INITIALS="$1";
fi;

if [[ -n "$2" ]]; then
	USER_EMAIL="$2";
fi;

if [[ -z "$USER_EMAIL" ]]; then
	echo -n "Enter email address: ";
	read USER_EMAIL;
fi;

AUTHORFILE="$HOME/.git_authors";

if ! [[ -f "$AUTHORFILE" ]] || ! grep 'authors:' < "$AUTHORFILE" > /dev/null; then
	echo "authors:" >> "$AUTHORFILE";
fi;

if grep "$USER_EMAIL" < "$AUTHORFILE" > /dev/null; then
	echo "Already in git duet authors list";
	exit 0;
fi;

while true; do
	if [[ -z "$USER_INITIALS" ]]; then
		echo -n "Enter initials for $USER_EMAIL (blank to skip): ";
		read USER_INITIALS;
	fi;
	if [[ -z "$USER_INITIALS" ]]; then
		echo "Skipping git-duet config" >&2;
		exit 1;
	fi;

	if grep ' $USER_INITIALS ' < "$AUTHORFILE" > /dev/null; then
		echo "WARNING: initials '$USER_INITIALS' are already taken" >&2;
		USER_INITIALS="";
	else
		sed -e '/authors:/ a\
'"\ \ $USER_INITIALS: $USER_EMAIL" "$AUTHORFILE" > "$AUTHORFILE-2";
		mv "$AUTHORFILE-2" "$AUTHORFILE";
		echo "Added to git_authors file";
		exit 0;
	fi;
done;

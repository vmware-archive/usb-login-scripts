#!/usr/bin/env bash

ABSDIR="$(cd "$(dirname "$0")";pwd)";

if [[ "$1" == *"help"* ]] || [[ "$1" == *"?"* ]]; then
  cat <<END
Usage: $0 [<initials> [<name> [<email>]]]

  Adds the given details to the git-authors file.

Parameters:

  initials              The initials for the user to add
  name                  The name for the user to add
  email                 The email address for the user to add

END
	exit 0;
fi;

if [[ -n "$1" ]]; then
	USER_INITIALS="$1";
fi;

if [[ -n "$2" ]]; then
	USER_NAME="$2";
fi;

if [[ -n "$3" ]]; then
	USER_EMAIL="$3";
fi;

if [[ -z "$USER_EMAIL" ]]; then
	if [[ "$NON_INTERACTIVE" == "true" ]]; then
		exit 1;
	fi;
	echo -n "Enter email address: ";
	read USER_EMAIL;
fi;

AUTHORFILE="$HOME/.git-authors";

if ! [[ -f "$AUTHORFILE" ]]; then
	touch "$AUTHORFILE";
fi;

if grep "$USER_EMAIL" < "$AUTHORFILE" > /dev/null || grep "; ${USER_EMAIL%@*}" < "$AUTHORFILE" > /dev/null; then
	echo "Already in git duet authors list";
	exit 0;
fi;

NAMES_SECTION="authors:";
if ! grep "$NAMES_SECTION" < "$AUTHORFILE" > /dev/null; then
	if grep 'pairs:' < "$AUTHORFILE" > /dev/null; then
		NAMES_SECTION="pairs:";
	else
		echo "$NAMES_SECTION" >> "$AUTHORFILE";
	fi;
fi;

EMAILS_SECTION="email_addresses:";
if ! grep "$EMAILS_SECTION" < "$AUTHORFILE" > /dev/null; then
	echo "$EMAILS_SECTION" >> "$AUTHORFILE";
fi;

if [[ -z "$USER_NAME" ]]; then
	if [[ "$NON_INTERACTIVE" == "true" ]]; then
		exit 1;
	fi;
	echo -n "Enter name: ";
	read USER_NAME;
fi;

while true; do
	if [[ -z "$USER_INITIALS" ]] && [[ "$NON_INTERACTIVE" != "true" ]]; then
		echo -n "Enter initials for $USER_EMAIL (blank to skip): ";
		read USER_INITIALS;
	fi;
	if [[ -z "$USER_INITIALS" ]]; then
		echo "Skipping git-duet config" >&2;
		exit 1;
	fi;

	if grep " $USER_INITIALS:" < "$AUTHORFILE" > /dev/null; then
		echo "WARNING: initials '$USER_INITIALS' are already taken" >&2;
		USER_INITIALS="";
	else
		sed -e "/$NAMES_SECTION/ a"'\
'"\ \ $USER_INITIALS: $USER_NAME" -e "/$EMAILS_SECTION/ "'a\
'"\ \ $USER_INITIALS: $USER_EMAIL" "$AUTHORFILE" > "$AUTHORFILE-2";
		mv "$AUTHORFILE-2" "$AUTHORFILE";
		echo "Added to git-authors file";
		exit 0;
	fi;
done;

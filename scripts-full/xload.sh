#!/usr/bin/env bash

ABSDIR="$(cd "$(dirname "$0")";pwd)";

USER_EMAIL="${USER_EMAIL:-$DEFAULT_USER_EMAIL}";
USER_INITIALS="${USER_INITIALS:-$DEFAULT_USER_INITIALS}";

if [[ -z "$USER_EMAIL" ]]; then
	echo -n "Enter your email address: ";
	read USER_EMAIL;
else
	echo "Login for $USER_EMAIL";
fi;

ALLARGS=" $* ";

# Add to git authors
if ! [[ "$ALLARGS" == *" --noduet "* ]] && ! [[ "$ALLARGS" =~ \ -[a-z]*d ]]; then
	if ! USER_INITIALS="$USER_INITIALS" USER_EMAIL="$USER_EMAIL" "$ABSDIR/gitduet.sh"; then
		echo "Failed to configure git duet author";
		# not critical; continue
	fi;
fi;

# Load SSH key
if ! [[ "$ALLARGS" == *" --nokey "* ]] && ! [[ "$ALLARGS" =~ \ -[a-z]*k ]]; then
	if [[ -z "$KEY_PASSWORD" ]]; then
		echo -n "Enter password for SSH key: ";
		read -s KEY_PASSWORD;
		echo;
	fi;
	if [[ -z "$KEY_PASSWORD" ]]; then
		echo "Skipping SSH key load";
	else
		if ! USER_EMAIL="$USER_EMAIL" KEY_PASSWORD="$KEY_PASSWORD" "$ABSDIR/keys.sh"; then
			echo "Failed to load SSH key";
			exit 1;
		fi;
	fi;
fi;

# Log in to Chrome
if ! [[ "$ALLARGS" == *" --nologin "* ]] && ! [[ "$ALLARGS" =~ \ -[a-z]*l ]]; then
	if [[ -z "$USER_PASSWORD" ]]; then
		echo -n "Enter password for Okta: ";
		read -s USER_PASSWORD;
		echo;
	fi;

	if [[ -z "$USER_PASSWORD" ]]; then
		# Assume same password if not given
		USER_PASSWORD="$KEY_PASSWORD";
	fi;

	if [[ -z "$USER_PASSWORD" ]]; then
		echo "Skipping Chrome login";
	else
		if ! USER_EMAIL="$USER_EMAIL" USER_PASSWORD="$USER_PASSWORD" osascript -l JavaScript < "$ABSDIR/login.js"; then
			echo "Failed to sign in to Chrome";
			exit 1;
		fi;
	fi;
fi;

# Unmount
if ! [[ "$ALLARGS" == *" --noeject "* ]] && ! [[ "$ALLARGS" =~ \ -[a-z]*e ]]; then
	"$ABSDIR/unmount.sh";
fi;

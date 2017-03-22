#!/usr/bin/env bash

ABSDIR="$(cd "$(dirname "$0")";pwd)";

USER_NAME="${USER_NAME:-$DEFAULT_USER_NAME}";
USER_EMAIL="${USER_EMAIL:-$DEFAULT_USER_EMAIL}";
USER_INITIALS="${USER_INITIALS:-$DEFAULT_USER_INITIALS}";

if [[ -z "$USER_EMAIL" ]]; then
	if [[ -n "$USER_NAME" ]]; then
		echo "Hi, $USER_NAME";
	fi;
	echo -n "Enter your email address: ";
	read USER_EMAIL;
else
	echo "Login for $USER_NAME [$USER_EMAIL]";
fi;

ALLARGS=" $* ";

if ! [[ "$ALLARGS" =~ \ -[a-zA-Z]*[a-z] ]]; then
	# Nothing has been focussed; focus all
	ALLARGS=" $ALLARGS -dkle ";
fi;

# Add to git authors
if [[ "$ALLARGS" =~ \ -[a-zA-Z]*d ]] && ! [[ "$ALLARGS" == *" --noduet "* ]] && ! [[ "$ALLARGS" =~ \ -[a-zA-Z]*D ]]; then
	if ! USER_INITIALS="$USER_INITIALS" USER_EMAIL="$USER_EMAIL" "$ABSDIR/gitduet.sh"; then
		echo "Failed to configure git duet author";
		# not critical; continue
	fi;
fi;

# Load SSH key
if [[ "$ALLARGS" =~ \ -[a-zA-Z]*k ]] && ! [[ "$ALLARGS" == *" --nokey "* ]] && ! [[ "$ALLARGS" =~ \ -[a-zA-Z]*K ]]; then
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
if [[ "$ALLARGS" =~ \ -[a-zA-Z]*l ]] && ! [[ "$ALLARGS" == *" --nologin "* ]] && ! [[ "$ALLARGS" =~ \ -[a-zA-Z]*L ]]; then
	if [[ -z "$USER_PASSWORD" ]]; then
		echo -n "Enter password for Okta (or - to skip): ";
		read -s USER_PASSWORD;
		echo;
	fi;

	if [[ -z "$USER_PASSWORD" ]]; then
		# Assume same password if not given
		USER_PASSWORD="$KEY_PASSWORD";
	fi;

	if [[ -z "$USER_PASSWORD" ]] || [[ "$USER_PASSWORD" == "-" ]]; then
		echo "Skipping Chrome login";
	else
		if ! USER_EMAIL="$USER_EMAIL" USER_PASSWORD="$USER_PASSWORD" osascript -l JavaScript < "$ABSDIR/login.js"; then
			echo "Failed to sign in to Chrome";
			exit 1;
		fi;
	fi;
fi;

# Update
if [[ "$ALLARGS" == *" --update "* ]] || [[ "$ALLARGS" =~ \ -[a-zA-Z]*u ]]; then
	echo "Updating";
	if ! git -C "$ABSDIR/.." pull; then
		echo "Update failed.";
		# not critical; continue
	fi;
fi;

# Unmount
if [[ "$ALLARGS" =~ \ -[a-zA-Z]*e ]] && ! [[ "$ALLARGS" == *" --noeject "* ]] && ! [[ "$ALLARGS" =~ \ -[a-zA-Z]*E ]]; then
	"$ABSDIR/unmount.sh";
fi;

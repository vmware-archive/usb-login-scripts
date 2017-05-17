#!/usr/bin/env bash

ABSDIR="$(cd "$(dirname "$0")";pwd)";

USER_NAME="${USER_NAME:-$DEFAULT_USER_NAME}";
USER_EMAIL="${USER_EMAIL:-$DEFAULT_USER_EMAIL}";
USER_INITIALS="${USER_INITIALS:-$DEFAULT_USER_INITIALS}";
MFA_MODE="${MFA_MODE:-$DEFAULT_MFA_MODE}";

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
	# Nothing has been focused; focus all
	ALLARGS=" $ALLARGS -dkle ";
fi;

function check_enabled() {
	# Features are enabled if their flag has been specified (e.g. -l)
	# AND their disabling flag has NOT been specified (e.g. --nologin / -L)

	FLAG="$1";
	LOWER_LETTER="$2";
	UPPER_LETTER="$(echo "$LOWER_LETTER" | tr '[:lower:]' '[:upper:]')";

	[[ "$ALLARGS" =~ \ -[a-zA-Z]*$LOWER_LETTER ]] && \
	! [[ "$ALLARGS" == *" --no$FLAG "* ]] && \
	! [[ "$ALLARGS" =~ \ -[a-zA-Z]*$UPPER_LETTER ]]
};

# Add to git authors
RETRY_GITDUET="false";
if check_enabled "duet" "d"; then
	# First pass is non-interactive to avoid accidental password exposure
	# (but still happens before login flow to optimise for the common use case)
	if ! USER_INITIALS="$USER_INITIALS" USER_NAME="$USER_NAME" USER_EMAIL="$USER_EMAIL" NON_INTERACTIVE="true" "$ABSDIR/gitduet.sh"; then
		echo "Conflict when setting git duet author; will try interactively at end";
		RETRY_GITDUET="true";
	fi;
fi;

# Load SSH key
if check_enabled "key" "k"; then
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
if check_enabled "login" "l"; then
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
		if ! USER_EMAIL="$USER_EMAIL" USER_PASSWORD="$USER_PASSWORD" MFA_MODE="$MFA_MODE" osascript -l JavaScript < "$ABSDIR/login.js"; then
			echo "Failed to sign in to Chrome";
			exit 1;
		fi;
	fi;
fi;

if [[ "$RETRY_GITDUET" == "true" ]]; then
	echo "Retrying git duet author interactively...";
	if ! USER_INITIALS="$USER_INITIALS" USER_NAME="$USER_NAME" USER_EMAIL="$USER_EMAIL" "$ABSDIR/gitduet.sh"; then
		echo "Failed to configure git duet author";
	fi;
fi;

# Update
if check_enabled "update" "u"; then
	echo "Updating";
	if ! git -C "$ABSDIR/.." pull; then
		echo "Update failed.";
		# not critical; continue
	fi;
fi;

# Unmount
if check_enabled "eject" "e"; then
	"$ABSDIR/unmount.sh";
fi;

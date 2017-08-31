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

if [[ "$ALLARGS" == *"?"* ]] || [[ "$ALLARGS" == *" --help "* ]]; then
	cat <<EOF;

Start-of-day scripts for our nomadic lifestyle.

Actions can be enabled using lowercase flags, or disabled using upper-case
flags. The order of flags does not matter. Available flags:

  -d/-D         Enable/disable writing initials in ~/.git-authors (git-duet
                config)
  -k/-K         Enable/disable loading ssh key
  -l/-L         Enable/disable logging in to browser (can also be skipped by
                entering "-" for password)
  -e/-E         Enable/disable ejecting the drive once finished
  -u (--update) Perform git pull after loading ssh key to update scripts
  ? (--help)    Show this help message (blocks all other actions)

The default is -dke. This is overridden by providing any lowercase flags, or
augmented by providing uppercase flags. For example:

  -E
  prevent the eject stage, performing only duet and keys.

  -e
  ONLY eject the drive.

  -ke
  Load keys and eject the drive.

  -DE
  prevent duet and eject stages, performing keys.

  -dke
  The default, perform duet, keys and eject stages.

  -dkle
  The default, plus automatic logging in to Chrome.

  -dkleDKLE
  Do nothing (uppercase flags take priority).

  --update
  -dkeu
  Perform the default stages and update the scripts when keys have loaded.

  -u
  ONLY update the scripts.

EOF
	exit 0;
fi;

if ! [[ "$ALLARGS" =~ \ -[a-zA-Z]*[a-z] ]]; then
	# Nothing has been focused; focus defaults
	ALLARGS=" $ALLARGS -dke ";
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

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

DRIVEDIR="$(cd "$(dirname "$0")/..";pwd)";

echo "This will install in to $DRIVEDIR.";
echo "If this is not correct, exit with Ctrl+C";
echo;

echo -n "Enter your name (for git duet) - typically first and last name: ";
read USER_NAME;
echo;

echo -n "Enter your initials (for git duet): ";
read USER_INITIALS;
echo;

echo -n "Enter your email address: ";
read USER_EMAIL;
echo;

if ! [[ -f "$DRIVEDIR/id_rsa" ]]; then
	echo -n "No SSH key found at $DRIVEDIR/id_rsa; would you like to create one? [y/n] ";
	read PROMPT;
	echo;
	if [[ "$PROMPT" == "y"* ]]; then
		if ! ssh-keygen -f "$DRIVEDIR/id_rsa" -C "$USER_NAME"; then
			echo "Failed to generate key. Aborting." >&2;
			exit 1;
		fi;
	fi;
fi;

echo "Which version of the scripts would you like to use? (see README.md for details)";
echo -n "[[f]ull / [a]utoexpire / [o]riginal] ";
read PROMPT;
echo;
if [[ "$PROMPT" == "f"* ]]; then
	SCRIPT="scripts-full/xload.sh";
elif [[ "$PROMPT" == "a"* ]]; then
	SCRIPT="scripts-autoexpire/xload.sh";
elif [[ "$PROMPT" == "o"* ]]; then
	SCRIPT="scripts-original/load";
else
	echo "Option not recognised. Aborting." >&2;
	exit 1;
fi;

LOADFILE="$DRIVEDIR/load";

if [[ -f "$LOADFILE" ]]; then
	echo "Warning: $LOADFILE already exists.";
	echo -n "Would you like to replace this file? [y/n] ";
	read PROMPT;
	echo;
	if [[ "$PROMPT" != "y"* ]]; then
		echo "Aborting." >&2;
		exit 1;
	fi;
fi;

# Lowercase user initials to match typical git-duet usage
USER_INITIALS="$(echo "$USER_INITIALS" | tr '[:upper:]' '[:lower:]')";

# Minimal attempt to escape special characters to avoid broken load script
USER_NAME="$(echo "$USER_NAME" | sed "s/'/'\\\\''/g")";
USER_EMAIL="$(echo "$USER_EMAIL" | sed "s/'/'\\\\''/g")";
USER_INITIALS="$(echo "$USER_INITIALS" | sed "s/'/'\\\\''/g")";

cat >"$LOADFILE" <<EOF;
ABSBASEDIR="\$(cd "\$(dirname "\$0")";pwd)";

DEFAULT_USER_NAME='$USER_NAME' \\
DEFAULT_USER_EMAIL='$USER_EMAIL' \\
DEFAULT_USER_INITIALS='$USER_INITIALS' \\
SSH_KEY_FILE="\$ABSBASEDIR/id_rsa" \\
"\$ABSBASEDIR/usb-login-scripts/$SCRIPT" "\$@";
EOF

chmod 0700 "$LOADFILE";

echo "Done.";

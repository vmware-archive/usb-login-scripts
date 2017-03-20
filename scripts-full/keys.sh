#!/usr/bin/env bash

ABSDIR="$(cd "$(dirname "$0")";pwd)";

if [[ "$1" == *"help"* ]] || [[ "$1" == *"?"* ]]; then
	cat <<END
Usage: $0 [<hours_to_keep_key>]

  Temporarily installs the SSH key from the disk drive.

Parameters:

  hours_to_keep_key     Integer number of hours to keep key installed
                        (defaults to loading until 6:20pm local time, or 10 minutes)

END
	exit 0;
fi;

if [[ -n "$1" ]]; then
	HOURS="$1";
fi;

SSH_KEY_FILE="${SSH_KEY_FILE:-$ABSDIR/id_rsa}";

if ! [[ -f "$SSH_KEY_FILE" ]]; then
	echo "SSH key not found! $SSH_KEY_FILE" >&2;
	exit 1;
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

if [[ -z "$KEY_PASSWORD" ]]; then
	# Use interactive mode
	/usr/bin/ssh-add -t "$SECONDS" "$SSH_KEY_FILE";
	exit $?;
fi;

# Use expect to send password via tty
if SECONDS="$SECONDS" SSH_KEY_FILE="$SSH_KEY_FILE" KEY_PASSWORD="$KEY_PASSWORD" expect <<END >/dev/null 2>&1; then
spawn ssh-add -t "$SECONDS" "$SSH_KEY_FILE";
expect "Enter passphrase for *:"
send "$KEY_PASSWORD\n";
expect {
	"Bad*:" {
		send "\n";
		exit 1;
	}
	"Identity added*" {
		exit 0;
	}
}
END
	echo "SSH key loaded, will expire in $SECONDS seconds";
	exit 0;
else
	echo "Incorrect SSH key password!" >&2;
	exit 1;
fi;

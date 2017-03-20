# usb-login-scripts

These scripts extend the idea of loading SSH keys from a USB stick described
[here](http://tammersaleh.com/posts/building-an-encrypted-usb-drive-for-your-ssh-keys-in-os-x/).

## Features

* Load a password-protected SSH key, which will automatically expire at 6:20 local time
  (or after 1 hour, whichever is longer)
* Add your email and initials to the .git_authors file on the machine
* Log in to Google Chrome and Okta (requires manual intervention for 2FA prompts)
* Automatically unmount the drive when complete

## Installation

1. Follow the steps for setting up a flash drive and creating an SSH key described here:
   http://tammersaleh.com/posts/building-an-encrypted-usb-drive-for-your-ssh-keys-in-os-x/
1. Instead of the script provided in that article, copy all the scripts under
   `/scripts-full/` in this repository on to the drive (if you prefer a different feature-
   set, copy from one of the other `scripts-*` directories instead)
1. Ensure the correct permissions are set (all `.sh` scripts should be 0700 and the `.js`
   should be 0600. Your private key should be 0600)
1. Rename `me-example.sh` to `me.sh` and change to match your details. For example:

```bash
#!/usr/bin/env bash

DEFAULT_USER_EMAIL="jbloggs@pivotal.io";
DEFAULT_USER_INITIALS="jb";
```

## scripts-full

### Use

1. Insert your USB key and enter your password to unlock it (if you chose to encrypt
the entire filesystem)
1. In a terminal run `/Volumes/my-usb-stick-name/xload.sh`
1. You will be added to `.git_authors` immediately (to prevent this, add `--noduet` or
   `-d` to the command)
1. You will be prompted for your SSH key password; enter it and the key will be loaded
   until the end of the day (to prevent this, add `--nokey` or `-k` to the command)
1. You will be prompted for your Okta password; enter it and the script will begin
   creating a new profile in Google Chrome (to prevent this, add `--nologin` or `-l` to
   the command)
   * You may be prompted to enable assistive access for the Terminal. The OS will guide
     you through how to do this. If this happens, you may need to kill and re-run the
     script, but you will not need to do it again.
   * If you do not enter a password, it will assume the same password as your SSH key
   * Most of the login process is automated, but you will still need to respond to the
     two-factor-authentication (2FA) prompts manually. There are also some dialogs which
     appear after logging in which you will need to manually dismiss.
1. The drive will automatically eject when the script is finished (to prevent this, add
   `--noeject` or `-e` to the command)

As with typical UNIX commands, you can chain short-form arguments. For example,
`xload -kl` will disable key loading and logging in to Chrome.

If anything goes wrong, simply kill with Ctrl+C.

At the end of the day, don't forget to remove the created profile from Chrome (automating
this is desirable, but challenging).

### Details

Orchestration is handled by `xload.sh`, but scripts can also be executed on their own.

#### Git duet author file

Searches the `~/.git_authors` file for the user's email address, and if not found,
attempts to create a new entry under `authors:`. If the user's initials are already in
use, will prompt for alternative initials.

Code is in `gitduet.sh`.

#### Key loading

Keys are loaded with `ssh-add`, and `expect` is used to enter the password
programmatically.

Code is in `keys.sh`.

#### Chrome automation

Logging in to Chrome is handled using `osascript` (OS X's command line interface for
AppleScript). The code itself is Javascript, meaning it can only work with more recent
versions of the OS.

Where possible, events are sent directly to the process through the standard API. Where
this is not possible (due to there being no API to interact with popups or authentication
pages), keyboard entry is simulated. When typing in passwords, this would pose a security
risk (if the keyboard focus changed while entering the password, it would be revealed on-
screen), so a more complex route is used (described below). Additionally, all passwords
are slightly obfuscated when being passed around as a final fail-safe against accidental
exposure (e.g. error messages).

The stages it follows are:

* Use the system menu to add a profile to Chrome (this is the only step which requires
  assistive access)
* Press the SIGN IN button in the new window
* Enter the email address in the popup window using the keyboard
* Enter the email address in Google's login page using the keyboard
* Enter the email address in Okta's login page using the keyboard
* Send code directly to the Okta login page which is capable of entering the password
* Open the developer console and enter code using the keyboard to invoke the previously
  entered code (required due to permissions restrictions in Chrome)
* Wait for the human to answer the 2FA prompt
* Wait for the human to dismiss the 2 popups which appear
* Navigate to Okta
* Send code directly to log in to Okta
* Wait for the human to answer the 2FA prompt

Code is in `login.js`, executed by `osascript`.

#### Unmounting

Unmounting is only attempted if the script's path contains "/Volumes/", to prevent
accidentally unmounting a built-in drive.

Code is in `unmount.sh`.

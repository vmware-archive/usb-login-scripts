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

Follow the steps for setting up a flash drive described here:
http://tammersaleh.com/posts/building-an-encrypted-usb-drive-for-your-ssh-keys-in-os-x/
(quoted below)

> Plug your drive into your computer and open Disk Utility. Select the disk (not the
> volume) on the left and navigate to the "Erase" tab. You'll want to name the volume
> something simple (such as "keys") to make it easier to access on the command line.
>
> Depending on the format of your USB key's partition table, then the partition table
> is MBR, which doesn't support encryption, and you won't see encrypted partitions as
> options in the "Format" dropdown. In that case, you'll have to do a two-step dance,
> formatting the drive twice:
>
> 1. Once as OS X Extended (Journaled) using the GUID Partition Map, then..
> 2. Again, using Mac OS Extended (Case-sensitive, Journaled, Encrypted).
>
> If you see the encrypted options in the dropdown, then just jump straight to #2
> above.
>
> Now, you'll be prompted for your decryption password whenever you insert the drive.
> Be sure not to save the password into the OS X Keychain.

Instead of following the rest of that article, run the following commands and enter
your details when prompted.

```bash
cd /Volumes/usb-volume-name-here
git clone git@github.com:pivotal/usb-login-scripts.git
./usb-login-scripts/install.sh
```

This will copy the repository on to your USB drive and create a `load` file in the
root. It will also optionally create your public/private key pair in the root of
your drive. You should upload the public key to github.

Later you can update if needed by running a standard `git pull` from the
`usb-login-scripts` directory.

## scripts-original

This is the original script from Tammer's blog. It will load your SSH key for a given
number of hours, then eject the drive.

### Use

1. Insert your USB key and enter your password to unlock it (if you chose to encrypt
the entire filesystem)
1. In a terminal run `/Volumes/my-usb-stick-name/load <hours>`
1. You will be prompted for your SSH key password; enter it and the key will be loaded
   for the given number of hours
1. The drive will automatically eject when the script is finished

## scripts-autoexpire

This is a small modification of the original script which will calculate an expiry
time to be shortly after the end of the working day (6:20 local time).

### Use

1. Insert your USB key and enter your password to unlock it (if you chose to encrypt
the entire filesystem)
1. In a terminal run `/Volumes/my-usb-stick-name/load`
1. You will be prompted for your SSH key password; enter it and the key will be loaded
   until the end of the day
1. The drive will automatically eject when the script is finished (to prevent this,
   add `keep` to the command)

## scripts-full

This is a further advance on the scripts which will automatically add you to the
machine's `.git_authors` file, and attempt to log you in to Chrome with minimal
interaction.

### Use

1. Insert your USB key and enter your password to unlock it (if you chose to encrypt
the entire filesystem)
1. In a terminal run `/Volumes/my-usb-stick-name/load`
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
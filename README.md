# usb-login-scripts

These scripts extend the idea of loading SSH keys from a USB stick described
[here](http://tammersaleh.com/posts/building-an-encrypted-usb-drive-for-your-ssh-keys-in-os-x/).

## Features

* Load a password-protected SSH key, which will automatically expire at 6:20 local time,
  or after 1 hour (whichever is longer)
* Add your email and initials to the .git-authors file on the machine if not already
  present
* Log in to Google Chrome and Okta (requires manual intervention for 2FA prompts)
    + Can be skipped at runtime
* Automatically pull script updates from github
    + Off by default; needs flag
* Automatically unmount the drive when complete

## Installation

### Disk formatting

These steps are not necessary if your drive has already been formatted,
e.g. because you previously used Tammer's blog's steps.

1.  Insert your USB and run the following command to get the disk identifier:
    ```bash 
    diskutil list
    ```
1. Run the following commands to reformat the drive with password-protection,
   inserting your variables.

    ```bash 
    diskutil eraseVolume jhfsx <new-usb-name> /Volumes/<old-usb-name>/
    diskutil partitionDisk /dev/<disk-identifier> GPT JHFS+ <new-usb-name> 0b
    diskutil cs convert /Volumes/<new-usb-name>/ -passphrase
    ```

### Script installation and key creation

- If you already have a keypair on your drive, the installation below will respect it
- If you already have an executable file named `load`, the script will overwrite it
  (after prompting)
- If you already a differently named executable file or other content, the script will
  not touch it

Run the following commands and enter your details when prompted:

```bash
cd /Volumes/usb-volume-name-here
git clone git@github.com:pivotal/usb-login-scripts.git
./usb-login-scripts/install.sh
```

This will copy the repository onto your USB drive and create a `load` file in the
root. It will also _optionally_ create a public/private key pair in the root of
your drive. If so, you should next upload the public key to github.

Later, you can update the load script if needed by running `git pull` from the
`usb-login-scripts` directory (or if you are using the "full" version, by specifying
the `--update` flag).

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
machine's `.git-authors` file, and attempt to log you in to Chrome with minimal
interaction.

### Use

1. Insert your USB key and enter your password to unlock it (if you chose to encrypt
   the entire filesystem)
1. In a terminal run `/Volumes/my-usb-stick-name/load`
1. You will be added to `.git-authors` immediately (to prevent this, add `--noduet` or
   `-D` to the command)
1. You will be prompted for your SSH key password; enter it and the key will be loaded
   until the end of the day (to prevent this, add `--nokey` or `-K` to the command)
1. You will be prompted for your Okta password; enter it and the script will begin
   creating a new profile in Google Chrome (to prevent this, add `--nologin` or `-L` to
   the command)
   * You may be prompted to enable assistive access for the Terminal. The OS will guide
     you through how to do this. If this happens, you may need to kill and re-run the
     script, but you will not need to do it again.
   * If you do not enter a password, it will assume the same password as your SSH key
   * Most of the login process is automated, but you will still need to respond to the
     two-factor-authentication (2FA) prompts manually. There are also some dialogs which
     appear after logging in which you will need to manually dismiss.
1. If you specify `--update` or `-u`, a `git pull` will be attempted to update the
   scripts.
1. The drive will automatically eject when the script is finished (to prevent this, add
   `--noeject` or `-E` to the command)

As with typical UNIX commands, you can chain short-form arguments. For example,
`load -KL` will disable key loading and logging in to Chrome.

Note that all stages except update will run by default. You can disable stages using
capital letters, or focus stages using lowercase letters (e.g. `load -k` will *only* load
the SSH key, or `load -ke` will load the SSH key and eject).

If anything goes wrong, simply kill with Ctrl+C.

At the end of the day, don't forget to remove the created profile from Chrome (automating
this is desirable, but challenging).

### Details

Orchestration is handled by `xload.sh`, but scripts can also be executed on their own.

#### Git duet author file

Searches the `~/.git-authors` file for the user's email address, and if not found,
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

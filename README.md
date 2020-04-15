# usb-login-scripts

These scripts extend the idea of loading SSH keys from a USB stick described
[here](http://tammersaleh.com/posts/building-an-encrypted-usb-drive-for-your-ssh-keys-in-os-x/).

## Features

* Load a password-protected SSH key, which will automatically expire at 6:20 local time,
  or after 1 hour (whichever is longer)
* Add your email and initials to the .git-authors file on the machine if not already
  present
* Automatically pull script updates from github (off by default; needs `--update` flag)
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
git clone https://github.com/pivotal/usb-login-scripts.git
./usb-login-scripts/install.sh
```

(if you would like to use the script from Tammer's blog, which does not add you to
the git duet file or calculate an automatic expiry time for the keys, you can run
`./usb-login-scripts/install.sh --classic` instead)

This will copy the repository onto your USB drive and create a `load` file in the
root. It will also _optionally_ create a public/private key pair in the root of
your drive. If so, you should next upload the public key to github.

Later, you can update the load script if needed by running `git pull` from the
`usb-login-scripts` directory (or if you are using the "full" version, by specifying
the `--update` flag).

## Use

1. Insert your USB key and enter your password to unlock it (if you chose to encrypt
   the entire filesystem)
1. In a terminal run `/Volumes/my-usb-stick-name/load`
1. You will be added to `.git-authors` immediately (to prevent this, add `--noduet` or
   `-D` to the command)
1. You will be prompted for your SSH key password; enter it and the key will be loaded
   until the end of the day (to prevent this, add `--nokey` or `-K` to the command)
1. If you specify `--update` or `-u`, a `git pull` will be attempted to update the
   scripts.
1. The drive will automatically eject when the script is finished (to prevent this, add
   `--noeject`, `-E`, or `keep` to the command)

As with typical UNIX commands, you can chain short-form arguments. For example,
`load -KE` will disable key loading and ejecting the drive.

Note that all stages will run by default. You can disable stages using capital letters,
or focus stages using lowercase letters (e.g. `load -k` will *only* load the SSH key,
or `load -ke` will load the SSH key and eject).

If anything goes wrong, simply kill with Ctrl+C.

## Details

Orchestration is handled by `xload.sh`, but scripts can also be executed on their own.

### Git duet author file

Searches the `~/.git-authors` file for the user's email address, and if not found,
attempts to create a new entry under `authors:`. If the user's initials are already in
use, will prompt for alternative initials.

Code is in `gitduet.sh`.

### Key loading

Keys are loaded with `ssh-add`, and `expect` is used to enter the password
programmatically.

Code is in `keys.sh`.

### Unmounting

Unmounting is only attempted if the script's path contains "/Volumes/", to prevent
accidentally unmounting a built-in drive.

Code is in `unmount.sh`.

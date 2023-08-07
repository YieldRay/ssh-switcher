# ssh-switcher

Bash utility to save and load your `~/.ssh/id_rsa.pub` and `~/.ssh/id_rsa` file

Supports linux & windows (with git bash)

App data will be saved to `~/.config/ssh-switcher/`

## Usage

```sh
Usage: ssh-switcher.sh [-h] [-v] <subcommand>

Switch your ~/.ssh/id_rsa.pub and ~/.ssh/id_rsa file with ease

Commands:
    save   <name>    Save ssh key files
    load   <name>    Load saved files
    remove <name>    Remove saved files
    list             List saved files with name
    whoami           Show current name

Available options:
-h, --help      Print this help and exit
-v, --verbose   Print script debug info
```

## Installation Reference

Just for reference, since you might want to install to another path

### linux

Download `ssh-switcher.sh` and move it to `~/.config/ssh-switcher/script/ssh-switcher`  
Modify your `PATH` environment variable, done!

### windows

Download `ssh-switcher.sh` and `ssh-switcher.cmd` and move them to `%USERPROFILE%\.config\ssh-switcher\script\`  
Run `systempropertiesadvanced.exe` to modify your `PATH` environment variable, done!

> You need have [`git for windows`](https://gitforwindows.org/) pre-installed, which ships an `bash.exe` executable  
> If you installed `git for windows` with a custom path, edit `ssh-switcher.cmd` file

# ssh-switcher

Bash utility script to save and load your `~/.ssh/id_*` files

Supports linux & windows (with git bash)

App data will be saved to `~/.config/ssh-switcher/`

## Usage

```sh
Usage: ssh-switcher.sh [-h] [-v] <subcommand>

Switch your ~/.ssh/id_rsa.pub and ~/.ssh/id_rsa file with ease

Commands:
    save      <name> [<email>]     Save ssh key files
    load      <name> [--no-git]    Load saved files
    remove/rm <name>               Remove saved files
    list/ls                        List saved files with name
    whoami                         Show current name

Available options:
-h, --help      Print this help and exit
-v, --verbose   Print script debug info

Recommendations:
name should be `git config --global user.name`
email should be `git config --global user.email`
```

## Installation Reference

Just for reference, since you might want to install to another path

```sh
# example
mkdir -p ~/.config/ssh-switcher/script
curl -fLk https://raw.githubusercontent.com/YieldRay/ssh-switcher/main/ssh-switcher.sh > ~/.config/ssh-switcher/script/ssh-switcher
export PATH="$PATH:$HOME/.config/ssh-switcher/script/"
```

### linux

Download `ssh-switcher.sh` and move it to `~/.config/ssh-switcher/script/ssh-switcher`  
Modify your `PATH` environment variable, done!

### windows

Download `ssh-switcher.sh` and `ssh-switcher.cmd` and move them to `%USERPROFILE%\.config\ssh-switcher\script\`  
Run `systempropertiesadvanced.exe` to modify your `PATH` environment variable, done!

> You need have [`git for windows`](https://gitforwindows.org/) pre-installed, which ships an `bash.exe` executable  
> If you installed `git for windows` with a custom path, remember to edit the `ssh-switcher.cmd` file

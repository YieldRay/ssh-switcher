#!/usr/bin/env bash

set -Eeuo pipefail
trap cleanup SIGINT SIGTERM ERR EXIT

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd -P)

usage() {
    cat <<EOF
Usage: $(
        basename "${BASH_SOURCE[0]}"
    ) [-h] [-v] <subcommand>

Switch your ~/.ssh/id_* files with ease

Commands:
    save   <name>    Save ssh key files
    load   <name>    Load saved files
    remove <name>    Remove saved files
    list             List saved files with name
    whoami           Show current name

Available options:
-h, --help      Print this help and exit
-v, --verbose   Print script debug info
EOF
    exit
}

cleanup() {
    trap - SIGINT SIGTERM ERR EXIT
    # script cleanup here
}

setup_colors() {
    if [[ -t 2 ]] && [[ -z "${NO_COLOR-}" ]] && [[ "${TERM-}" != "dumb" ]]; then
        NOFORMAT='\033[0m' RED='\033[0;31m' GREEN='\033[0;32m' ORANGE='\033[0;33m' BLUE='\033[0;34m' PURPLE='\033[0;35m' CYAN='\033[0;36m' YELLOW='\033[1;33m'
    else
        NOFORMAT='' RED='' GREEN='' ORANGE='' BLUE='' PURPLE='' CYAN='' YELLOW=''
    fi
}

msg() {
    echo >&2 -e "${1-}"
}

die() {
    local msg=$1
    local code=${2-1} # default exit status 1
    msg "$msg"
    exit "$code"
}

parse_params() {
    while :; do
        case "${1-}" in
        -h | --help) usage ;;
        -v | --verbose) set -x ;;
        --no-color) NO_COLOR=1 ;;
        -?*) die "Unknown option: $1" ;;
        *) break ;;
        esac
        shift
    done

    args=("$@")

    # check required params and arguments
    if [[ ${#args[@]} -eq 0 ]]; then
        usage
    fi

    return 0
}

parse_params "$@"
setup_colors

############################
#                          #
#                          #
#          Start           #
#                          #
#                          #
############################

DATA_DIR="${XDG_CONFIG_HOME-$HOME/.config}/ssh-switcher"
DATA_PROFILE_DIR="$DATA_DIR/profiles"
SSH_DIR="$HOME/.ssh"

subcommand_save() {
    # verify args
    if [[ -z "${1-}" ]]; then
        msg "${RED}Should provide a name${NOFORMAT}"
        echo
        usage
    fi
    # ensure ssh dir exists
    if [ ! -d "$SSH_DIR" ]; then
        msg "${RED}$SSH_DIR is not a directory${NOFORMAT}"
        exit 1
    fi
    # save action
    DATA_PROFILE_NAME_DIR="$DATA_PROFILE_DIR/$1"
    mkdir -p "$DATA_PROFILE_NAME_DIR"
    cp -rv "$SSH_DIR"/id_* "$DATA_PROFILE_NAME_DIR"/ # only save ~/.ssh/id_*
    # if $2 is empty, print
    if [[ -z "${2-}" ]]; then
        msg "${GREEN}Successfully saved \`$SSH_DIR/id_*\` to \`$DATA_PROFILE_NAME_DIR\`${NOFORMAT}"
    fi
}

subcommand_load() {
    # verify args
    if [[ -z "${1-}" ]]; then
        msg "${RED}Should provide a name${NOFORMAT}"
        echo
        usage
    fi
    # ensure saved file exists
    DATA_PROFILE_NAME_DIR="$DATA_PROFILE_DIR/$1"
    if [ ! -d "$DATA_PROFILE_NAME_DIR" ]; then
        msg "${RED}Profile does not exists${NOFORMAT}"
        exit 1
    fi
    # backup first (check if profile with current name exists)
    current_name=""
    if [ -f "$DATA_DIR/__current__" ]; then
        current_name=$(cat "$DATA_DIR/__current__")
    fi
    if [ -z "$current_name" ] || [ ! -d "$DATA_PROFILE_DIR/$current_name" ]; then
        backup_name="__backup_${RANDOM-random}__"
        subcommand_save "$backup_name" no_print
        msg "${BLUE}Profile has been backup as \`$backup_name\`${NOFORMAT}"
    fi
    # exec copy
    cp -rv "$DATA_PROFILE_NAME_DIR"/* "$SSH_DIR"/
    # update current name
    echo -n "$1" >"$DATA_DIR/__current__"
    msg "${GREEN}Successfully loaded \`$1\`${NOFORMAT}"
}

subcommand_remove() {
    # verify args
    if [[ -z "${1-}" ]]; then
        msg "${RED}Should provide a name${NOFORMAT}"
        echo
        usage
    fi
    # make sure dir exists
    DATA_PROFILE_NAME_DIR="$DATA_PROFILE_DIR/$1"
    if [[ ! -d "$DATA_PROFILE_NAME_DIR" ]]; then
        msg "${RED}Nothing to remove${NOFORMAT}"
        exit 1
    fi
    # prompt confirm
    msg "${BLUE}Confirm to remove \`$1\`? (y/n): ${NOFORMAT}"
    read -r confirmation
    while [ "$confirmation" != "y" ] && [ "$confirmation" != "n" ]; do
        msg "${BLUE}Enter y or n: ${NOFORMAT}"
        read -r confirmation
    done
    # exec
    if [ "$confirmation" = "y" ]; then
        rm -rfv "$DATA_PROFILE_NAME_DIR" # remove entire dir
        msg "${GREEN}Successfully removed \`$DATA_PROFILE_NAME_DIR\`${NOFORMAT}"
    else
        msg "${RED}Aborted${NOFORMAT}"
        exit 1
    fi
}

subcommand_list() {
    if [[ -d "$DATA_PROFILE_DIR" ]]; then
        printf "${BLUE}%20s %30s %15s${NOFORMAT}\n" "Name" "Title" "Type"
        printf "%20s %30s %15s\n" "----" "-----" "----"

        for dir in "$DATA_PROFILE_DIR"/*; do
            if [ ! -d "$dir" ]; then continue; fi

            find "$dir" -name "id_*.pub" -type f | while read -r file; do
                if [[ "$(basename "$file")" =~ id_(.+)\.pub ]]; then
                    type=${BASH_REMATCH[1]}           # profile type
                    name=$(basename "$dir")           # profile name
                    title=$(cut -d ' ' -f 3 <"$file") # profile title
                    printf "%20s %30s %15s\n" "$name" "$title" "$type"
                    break # only print the first ssh pub key
                fi
            done
        done
    else
        msg "${BLUE}Nothing to show${NOFORMAT}"
    fi
}

subcommand_whoami() {
    name="<none>"
    if [ -f "$DATA_DIR/__current__" ]; then
        name=$(cat "$DATA_DIR/__current__")
    fi
    msg "${name}"
}

case ${args[0]} in
"save") subcommand_save "${args[@]:1}" ;;
"load") subcommand_load "${args[@]:1}" ;;
"remove") subcommand_remove "${args[@]:1}" ;;
"list") subcommand_list ;;
"whoami") subcommand_whoami ;;
*)
    msg "${RED}Unknown command${NOFORMAT}"
    echo
    usage
    ;;
esac

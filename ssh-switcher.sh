#!/usr/bin/env bash

set -Eeuo pipefail
trap cleanup SIGINT SIGTERM ERR EXIT

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd -P)

usage() {
    cat <<EOF
Usage: $(
        basename "${BASH_SOURCE[0]}"
    ) [-h] [-v] <subcommand>

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
FILE_RSA="$HOME/.ssh/id_rsa"
FILE_RSA_PUB="$HOME/.ssh/id_rsa.pub"

subcommand_save() {
    # verify args
    if [[ -z "${1-}" ]]; then
        msg "${RED}Should provide a name${NOFORMAT}"
        echo
        usage
    fi
    # ensure ssh key file exists
    if [ ! -e "$FILE_RSA" ] && [ ! -e "$FILE_RSA_PUB" ]; then
        msg "${RED}File \`$FILE_RSA\` and \`$FILE_RSA_PUB\` does not exists${NOFORMAT}"
        exit 1
    fi
    # save action
    DATA_PROFILE_NAME_DIR="$DATA_PROFILE_DIR/$1"
    mkdir -p "$DATA_PROFILE_NAME_DIR"
    cp "$FILE_RSA_PUB" "$DATA_PROFILE_NAME_DIR"
    cp "$FILE_RSA" "$DATA_PROFILE_NAME_DIR"
    # if $2 is empty, print
    if [[ -z "${2-}" ]]; then
        msg "${GREEN}Successfully save \`~/.ssh/id_rsa.pub\` and \`~/.ssh/id_rsa\` to \`$DATA_PROFILE_NAME_DIR\`${NOFORMAT}"
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
    if [ ! -e "$DATA_PROFILE_NAME_DIR/id_rsa.pub" ] && [ ! -e "$DATA_PROFILE_NAME_DIR/id_rsa" ]; then
        msg "${RED}File \`$DATA_PROFILE_NAME_DIR/id_rsa.pub\` and \`$DATA_PROFILE_NAME_DIR/id_rsa\` does not exists${NOFORMAT}"
        exit 1
    fi
    # backup first (check if profile with current name exists)
    current_name=""
    if [ -f "$DATA_DIR/__current__" ]; then
        current_name=$(cat "$DATA_DIR/__current__")
    fi
    if [ -z "$current_name" ] || [ ! -f "$DATA_PROFILE_DIR/$current_name/id_rsa.pub" ] || [ ! -f "$DATA_PROFILE_DIR/$current_name/id_rsa" ]; then
        backup_name="__backup_${RANDOM-random}__"
        subcommand_save "$backup_name" no_print
        msg "${BLUE}Profile has been backup as \`$backup_name\`${NOFORMAT}"
    fi
    # exec copy
    cp "$DATA_PROFILE_NAME_DIR/id_rsa.pub" "$FILE_RSA_PUB"
    cp "$DATA_PROFILE_NAME_DIR/id_rsa" "$FILE_RSA"
    # store current name
    echo -n "$1" >"$DATA_DIR/__current__"
    msg "${GREEN}Successfully load \`$1\`${NOFORMAT}"
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
        rm -rf "$DATA_PROFILE_NAME_DIR"
        msg "${GREEN}Successfully remove \`$DATA_PROFILE_NAME_DIR\`${NOFORMAT}"
    else
        msg "${RED}Exit${NOFORMAT}"
        exit 1
    fi
}

subcommand_list() {
    if [[ -d "$DATA_PROFILE_DIR" ]]; then
        printf "\033[0;34m%20s %30s\033[0m\n" "Name" "Title"
        printf "%20s %30s\n" "----" "-----"
        for dir in "$DATA_PROFILE_DIR"/*; do
            file="$dir/id_rsa.pub"
            if [ -d "$dir" ] && [ -f "$file" ]; then
                name=$(basename "$dir")
                title=$(cut -d ' ' -f 3 <"$file")
                printf "%20s %30s\n" "$name" "$title"
            fi
        done
    else
        msg "${BLUE}Nothing to show${NOFORMAT}"
    fi
}

subcommand_whoami() {
    name="<none>"
    if [ -f "$DATA_DIR/__current__" ]; then name=$(cat "$DATA_DIR/__current__"); fi
    title=$(cut -d ' ' -f 3 <"$FILE_RSA_PUB")
    msg "${name} ${ORANGE}${title}${NOFORMAT}"
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

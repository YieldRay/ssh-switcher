#!/usr/bin/env bash

set -Eeuo pipefail
trap cleanup SIGINT SIGTERM ERR EXIT

# shellcheck disable=SC2034
script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd -P)

usage() {
    cat <<EOF
Usage: $(
        basename "${BASH_SOURCE[0]}"
    ) [-h] [-v] <subcommand>

Switch your ~/.ssh/id_rsa.pub and ~/.ssh/id_rsa file with ease

Commands:
    save      <name> [<email>]     Save ssh key files
    load      <name> [-git | -a]   Load saved files
    remove/rm <name>               Remove saved files
    list/ls                        List saved files with name
    whoami                         Show current name

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
        # shellcheck disable=SC2034
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

email_regex='^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'

# $1 - user:string
# $2 - email?:string
# $3 - no_print:boolean
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

    # save email to __email__, if valid
    if [[ "$2" =~ $email_regex ]]; then
        echo -n "$2" >"${DATA_PROFILE_NAME_DIR}/__email__"
    fi

    # if $3 is empty, also print
    if [[ -z "${3-}" ]]; then
        msg "${GREEN}Successfully saved \`$SSH_DIR/id_*\` to \`$DATA_PROFILE_NAME_DIR\`${NOFORMAT}"
    fi
}

# $1:name
load_git_config() {
    # get the email
    email=""

    DATA_PROFILE_NAME_DIR="$DATA_PROFILE_DIR/$1"
    if [[ -f "$DATA_PROFILE_NAME_DIR/__email__" ]]; then
        email=$(cat "$DATA_PROFILE_NAME_DIR/__email__")
    fi

    # set git global config
    git config --global user.name "$1"
    if [[ "$email" =~ $email_regex ]]; then
        git config --global user.email "$email"
    fi

}

print_git_config() {
    if command -v git &>/dev/null; then
        echo
        msg "${ORANGE}user.name${NOFORMAT}  ${PURPLE}=${NOFORMAT} $(git config --global user.name)"
        msg "${ORANGE}user.email${NOFORMAT} ${PURPLE}=${NOFORMAT} $(git config --global user.email)"
    fi
}

subcommand_load() {
    # flag: --git
    if [[ -n "${1-}" && -n "${2-}" && "$2" == "-git" ]]; then
        load_git_config "$1"
        msg "${GREEN}Successfully loaded git config for \`$1\`${NOFORMAT}"
        print_git_config
        exit
    fi

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
    # backup first (when profile with current name does not exist)
    current_name=""
    if [ -f "$DATA_DIR/__current__" ]; then
        current_name=$(cat "$DATA_DIR/__current__")
    fi
    if [ -z "$current_name" ] || [ ! -d "$DATA_PROFILE_DIR/$current_name" ]; then
        backup_name="__backup_${RANDOM-random}__"
        subcommand_save "$backup_name" "" no_print
        msg "${BLUE}Profile has been backup as \`$backup_name\`${NOFORMAT}"
    fi
    # exec copy
    # [simple] cp -rv "$DATA_PROFILE_NAME_DIR"/* "$SSH_DIR"/
    find "$DATA_PROFILE_NAME_DIR"/* -type f ! -name '__email__*' -exec cp {} "$SSH_DIR"/ \;
    # update current name
    echo -n "$1" >"$DATA_DIR/__current__"
    msg "${GREEN}Successfully loaded \`$1\`${NOFORMAT}"

    # flag: -a
    if [[ -n "${1-}" && -n "${2-}" && "$2" == "-a" ]]; then
        load_git_config "$1"
    fi

    print_git_config
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
        printf "${BLUE}%16s %25s %6s %25s${NOFORMAT}\n" "Name" "Title" "Type" "Email"
        printf "%16s %25s %6s %25s\n" "----" "-----" "----" "-----"

        for dir in "$DATA_PROFILE_DIR"/*; do
            if [ ! -d "$dir" ]; then continue; fi

            # try to get email from __email__ file
            email=""
            if [ -f "${dir}/__email__" ]; then
                email=$(cat "${dir}/__email__")
            fi

            find "$dir" -name "id_*.pub" -type f | while read -r file; do
                if [[ "$(basename "$file")" =~ id_(.+)\.pub ]]; then
                    type=${BASH_REMATCH[1]}           # profile type
                    name=$(basename "$dir")           # profile name
                    title=$(cut -d ' ' -f 3 <"$file") # profile title
                    printf "%16s %25s %6s %25s\n" "$name" "$title" "$type" "$email"
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
        current=$(cat "$DATA_DIR/__current__")
        name=$(echo "$current" | cut -d' ' -f1)
    fi
    msg "${CYAN}${name}${NOFORMAT}"

    print_git_config
}

case ${args[0]} in
"save") subcommand_save "${args[@]:1}" ;;
"load") subcommand_load "${args[@]:1}" ;;
"remove") subcommand_remove "${args[@]:1}" ;;
"rm") subcommand_remove "${args[@]:1}" ;;
"list") subcommand_list ;;
"ls") subcommand_list ;;
"whoami") subcommand_whoami ;;
*)
    msg "${RED}Unknown command${NOFORMAT}"
    echo
    usage
    ;;
esac

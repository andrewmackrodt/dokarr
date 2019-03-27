#!/bin/bash
IFS=$'\n'

# default options
DRY_RUN=0
RECURSIVE=0

# arguments that aren't options
args=()

usage() {
    echo -e "Usage: ${BASH_SOURCE[0]} [options] <path>\n"
    echo -e \
            $'\n' "-n, --dry-run" $'\t' "skips symlink creation" \
            $'\n' "-r, --recursive" $'\t' "apply recursively" \
            $'\n' "-h, --help" $'\t' "prints this help test" \
        | column -s$'\t' -t >&2
    echo "" >&2
    exit "${1:-0}"
}

# detect options
while [[ "${#@}" -gt 0 ]]; do
    if [[ "$1" =~ ^[^-] ]]; then
        args=( "$@" );
        break
    fi
    case $1 in
        -n | --dry-run )
            DRY_RUN=1; ;;
        -r | --recursive )
            RECURSIVE=1; ;;
        -h | --help )
            usage; ;;
        -- )
            break; ;;
        * )
            echo "ERR invalid option $1" >&2; exit 1
    esac
    shift
done

if [[ "${#args[@]}" -ne "1" ]] || [[ ! -d "${args[0]}" ]]; then
    echo -e "ERR exactly one argument is expected" >&2
    echo -e "ERR directory does not exist" >&2
    usage 1
fi

#if [[ ! "$(uname -r)" =~ -Microsoft$ ]]; then
#    echo -e "ERR script must run in WSL shell" >&2
#    exit 1
#fi

rootdir=${args[0]}

recurse_dir () {
    local scandir=$1
    local dirs
    local files

    if [[ ! -d "$scandir" ]]; then
        return
    fi

    scandir=$( cd "$scandir" && pwd )
    cd "$scandir"

    # detect symlinks in scandir
    echo "  - $scandir" >&2
    read -rd '' -a files <<<"$(find . -mindepth 1 -maxdepth 1 -type f -size -1068c)"
    echo "      file_count: ${#files[@]}" >&2
    symlinks=()
    if [[ ${#files[@]} != 0 ]]; then
        symlinks=(
            $(detect_cifs_symlinks "${files[@]}")
            $(detect_linux_symlinks "${files[@]}")
        )
    fi
    echo "      link_count: ${#symlinks[@]}" >&2
    if [[ ${#symlinks[@]} != 0 ]]; then
        echo "      links:" >&2
        replace_symlinks "${symlinks[@]}"
    else
        echo "      links: []" >&2
    fi

    if [[ $RECURSIVE == 0 ]]; then
        return
    fi

    # recurse directories
    read -rd '' -a dirs <<<"$(find . -mindepth 1 -maxdepth 1 -type d)"
    for d in "${dirs[@]}"; do
        echo "$scandir/${d:2}"
        recurse_dir "$scandir/${d:2}"
    done
}

detect_cifs_symlinks () {
    local files=( "$@" )
    local symlinks

    # include current directory to force a filename in
    # the output when the size of the files array is 1
    head -n4 . "${files[@]}" 2>/dev/null \
        | tr $'\n' ':' \
        | sed -E 's/:?==> /\n/g' \
        | sed 's/ <==:/:/g' \
        | sed -nE 's/^([^:]+):XSym:[0-9]+:[0-9a-f]{32}:(.+) *:$/\1:\2/p'
}

detect_linux_symlinks () {
    local files=( "$@" )
    local symlinks

    # include current directory to force a filename in
    # the output when the size of the files array is 1
    head -n1 . "${files[@]}" 2>/dev/null \
        | tr -cd '\11\12\15\40-\176' \
        | tr $'\n' ':' \
        | sed -E 's/:?==> /\n/g' \
        | sed 's/ <==:/:/g' \
        | sed -nE 's/^([^:]+):IntxLNK(.+)/\1:\2/p'
}

replace_symlinks () {
    local args=( "$@" )
    local file
    local link

    for i in "${args[@]}"; do
        link="${i%%:*}"
        i="${i#*:}"
        target="${i%%:*}"
        echo "        - link: $link"
        echo "          target: $target"

        if [[ $DRY_RUN == 0 ]]; then
            ln -fns "$target" "$link"
        fi
    done
}

echo "Scanning for symlinks:" >&2

recurse_dir "$rootdir"

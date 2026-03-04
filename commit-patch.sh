#!/usr/bin/bash
set -o nounset
set -o errtrace
set -o pipefail
function CATCH_ERROR { # {{{
    local __LEC=$? __i __j
    set +x
    echo "Traceback (most recent call last):" >&2
    for ((__i = ${#FUNCNAME[@]} - 1; __i >= 0; --__i)); do
        printf '  File %q line %s in %q\n' >&2 \
            "${BASH_SOURCE[__i]}" \
            "${BASH_LINENO[__i]}" \
            "${FUNCNAME[__i]}"
        if ((BASH_LINENO[__i])) && [ -f "${BASH_SOURCE[__i]}" ]; then
            for ((__j = 0; __j < BASH_LINENO[__i]; ++__j)); do
                read -r REPLY
            done < "${BASH_SOURCE[__i]}"
            printf '    %s\n' "$REPLY" >&2
        fi
    done
    echo "Error: [ExitCode: ${__LEC}]" >&2
    exit "${__LEC}"
}
trap CATCH_ERROR ERR # }}}

if [[ ${1-} = -h ]]; then
    printf 'Usage: %q [PATCH]\n' "${0##*/}"
    exit
fi

file=$(mktemp pull-patch.XXXXXXXXXX)
trap 'rm "$file"' exit
cat -- "$@" > "$file"

author=$(grep -Po 'Author:\s*\K\S.*' "$file" || exit)
date=$(grep -Po 'Date:\s*\K\S.*' "$file" || exit)
body=$(awk '/^    /{sub("^    ", "");print}/^diff/{exit}' "$file" || exit)

git commit -am "patch: $body" --author="$author" --date="$date"

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
    printf 'Usage: %q <hash>\n' "${0##*/}"
    exit
fi

hash awk sed git mktemp rm vim grep jq

# git -C rust-analyzer log --oneline ./lib/smol_str | vim -

test -d ./rust-analyzer # needs origin repo
test $# = 1

file=$(mktemp pull-patch.XXXXXXXXXX)
trap 'rm "$file"' exit

subst=(
    -e 's/\bsync::Arc\b/rc::Rc/g'
    -e 's/\bArc\b/Rc/g'
    -e 's/\bsmol_str\b/&c/g'
)

git rebase HEAD^ # check clean

git -C rust-analyzer show "$1" ./lib/smol_str > "$file"

commit=$(head "$file" -n1)
author=$(head "$file" | grep -Po 'Author:\s*\K\S.*' || exit)
date=$(head "$file" | grep -Po 'Date:\s*\K\S.*' || exit)
body=$(awk '/^    /{sub("^    ", "");print}/^diff/{exit}' "$file" || exit)

body=$(jq --arg c "$commit" -rsR 'sub("\r?\n\r?\n|$"; "\n\n"+$c+"\n\n")|rtrim' <<< "$body")

printf -- '-- body --\n%s\n-- end --\n' "$body"

sed -i "${subst[@]}" "$file"

until git apply -p3 --recount --reject < "$file"; do
    git restore .
    read -rp 'edit?'
    vim "$file"
done

case $commit in commit*);;*) false; esac

git commit -am "patch: $body" --author="$author" --date="$date"
